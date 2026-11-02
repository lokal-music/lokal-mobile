import 'package:flick/core/utils/artist_credits.dart';

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:isar_community/isar.dart';
import 'package:flick/data/database.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/apple_music/apple_music_metadata_service.dart';

/// One worker warms new artists and persists their portraits. Rows subscribe
/// only to their own path, rather than rebuilding the library for every result.
class ArtistMetadata extends Notifier<Map<String, String>> {
  ArtistMetadata({List<String> Function(Song)? parseCredits})
    : _parseCredits = parseCredits ?? songArtistNames;

  final List<String> Function(Song) _parseCredits;
  final _seen = <String>{};
  final _queue = Queue<String>();
  final _seenCredits = <(String, String?)>{};
  // An explicit refresh must win over an older background warmup result.
  final _manualRefreshes = <String>{};
  final _forcedGeneration = <String, int>{};
  List<Song>? _pendingWarmup;
  Future<void>? _warming;
  bool _seeded = false;
  bool _working = false;
  static String key(String name) => name.trim().toLowerCase();
  @override
  Map<String, String> build() => const {};

  void warm(List<Song> songs) {
    _pendingWarmup = songs;
    _warming ??= _warmCredits().whenComplete(() => _warming = null);
  }

  @visibleForTesting
  Future<void> get warmupIdle => _warming ?? Future<void>.value();

  Future<void> _warmCredits() async {
    // A library listener runs on the UI isolate. Never parse thousands of
    // artist credits synchronously there, nor reparse unchanged credits on
    // every sample-rate/artwork write. Keep only the newest pending snapshot.
    await Future<void>.delayed(Duration.zero);
    while (_pendingWarmup != null && ref.mounted) {
      final songs = _pendingWarmup!;
      _pendingWarmup = null;
      for (var i = 0; i < songs.length; i++) {
        final song = songs[i];
        if (_seenCredits.add((song.artist, song.albumArtist))) {
          for (final name in _parseCredits(song)) {
            if (!_seen.add(key(name))) continue;
            if (_seeded) {
              _queue.addFirst(name);
            } else {
              _queue.addLast(name);
            }
          }
        }
        if ((i + 1) % 64 == 0) {
          await Future<void>.delayed(Duration.zero);
          if (!ref.mounted || _pendingWarmup != null) break;
        }
      }
      _seeded = true;
      if (ref.mounted) unawaited(_drain());
    }
  }

  Future<void> _drain() async {
    if (_working) return;
    _working = true;
    try {
      while (_queue.isNotEmpty && ref.mounted) {
        final name = _queue.removeFirst();
        try {
          await refresh(name);
        } catch (_) {
          /* Retry unavailable artists next session or manually. */
        }
        if (ref.mounted) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
      }
    } finally {
      _working = false;
    }
  }

  /// Background warmup reuses an existing valid portrait. Explicit user
  /// refreshes use [storeRefreshedPortrait] so a fresh URL response is never
  /// silently replaced with an old cached image.
  Future<void> refresh(String name, {bool force = false}) async {
    if (!Database.isInitialized) return;
    final artistKey = key(name);
    if (!force && _manualRefreshes.contains(artistKey)) return;
    final generation = _forcedGeneration[artistKey] ?? 0;
    final previous = await Database.artists
        .filter()
        .nameEqualTo(name, caseSensitive: false)
        .findFirst();
    final path = previous?.artPath;
    if (!force && path != null && await File(path).exists()) {
      if (ref.mounted && _isCurrent(artistKey, generation)) {
        state = {...state, artistKey: path};
      }
      return;
    }
    final api = AppleMusicMetadataService.instance;
    final artist = await api.resolveArtist(name, refresh: force);
    if (artist == null || !ref.mounted || !_isCurrent(artistKey, generation)) {
      return;
    }
    final info = await api.getArtistInfo(artist.artistId, refresh: force);
    if (!ref.mounted || !_isCurrent(artistKey, generation)) return;
    await _storePortrait(
      name,
      info?.imageUrl,
      force: force,
      generation: generation,
    );
  }

  /// Use the image already resolved by the manual metadata job. This avoids
  /// resolving and scraping the same artist twice, which could rate-limit
  /// large libraries. Returns true only after the new portrait is persisted.
  Future<bool> storeRefreshedPortrait(String name, String? imageUrl) async {
    final artistKey = key(name);
    if (!Database.isInitialized || artistKey.isEmpty) return false;
    final generation = (_forcedGeneration[artistKey] ?? 0) + 1;
    _forcedGeneration[artistKey] = generation;
    _manualRefreshes.add(artistKey);
    try {
      return await _storePortrait(
        name,
        imageUrl,
        force: true,
        generation: generation,
      );
    } finally {
      _manualRefreshes.remove(artistKey);
    }
  }

  bool _isCurrent(String artistKey, int generation) =>
      !_manualRefreshes.contains(artistKey) &&
      (_forcedGeneration[artistKey] ?? 0) == generation;

  Future<bool> _storePortrait(
    String name,
    String? imageUrl, {
    required bool force,
    required int generation,
  }) async {
    final image = imageUrl?.trim();
    if (!Database.isInitialized ||
        !ref.mounted ||
        image == null ||
        image.isEmpty) {
      return false;
    }
    final artistKey = key(name);
    // The normal image key can return a cached file even when metadata was
    // refreshed. A new key forces a real image fetch and produces a new file
    // path, which makes FileImage and every subscribed artist row reload.
    // Keep the previous DB path intact if the network request fails.
    final file = await DefaultCacheManager()
        .getImageFile(
          image,
          key: force
              ? refreshedArtistPortraitCacheKey(name, DateTime.now())
              : null,
          maxWidth: 600,
          maxHeight: 600,
        )
        .where((event) => event is FileInfo)
        .cast<FileInfo>()
        .last;
    if (!await file.file.exists() || !ref.mounted) return false;
    if (!force && !_isCurrent(artistKey, generation)) return false;
    if (force && (_forcedGeneration[artistKey] ?? 0) != generation) return false;

    final cachedPath = file.file.path;
    // Publish only after saving the replacement. Readers retain their old
    // portrait if the download or database transaction fails.
    var persisted = false;
    await Database.instance.writeTxn(() async {
      // A background lookup that started earlier must not commit after a
      // newer explicit refresh has taken ownership of this artist.
      if (!force && !_isCurrent(artistKey, generation)) return;
      if (force && (_forcedGeneration[artistKey] ?? 0) != generation) return;
      final row =
          await Database.artists
              .filter()
              .nameEqualTo(name, caseSensitive: false)
              .findFirst() ??
          (ArtistEntity()..name = name);
      if (!force && !_isCurrent(artistKey, generation)) return;
      if (force && (_forcedGeneration[artistKey] ?? 0) != generation) return;
      row.artPath = cachedPath;
      await Database.artists.put(row);
      persisted = true;
    });
    if (!persisted) return false;
    if (ref.mounted && (force || _isCurrent(artistKey, generation))) {
      state = {...state, artistKey: cachedPath};
    }
    return true;
  }
}

/// Unique cache identity for manual portrait refreshes. The URL alone would
/// reuse a stale image; using a new key also changes the local FileImage path.
@visibleForTesting
String refreshedArtistPortraitCacheKey(String name, DateTime at) =>
    'artist-portrait-refresh:${ArtistMetadata.key(name)}:${at.microsecondsSinceEpoch}';

final artistMetadataProvider =
    NotifierProvider<ArtistMetadata, Map<String, String>>(ArtistMetadata.new);
