import 'dart:async';

import 'artist_metadata.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/features/music_videos/music_video_providers.dart';
import 'package:flick/features/konnekted/library/lokal_library_groups.dart';
import 'package:flick/features/konnekted/library/lokal_online_catalogue.dart';
import 'package:flick/services/apple_music/apple_music_metadata_service.dart';
import 'package:flick/models/song.dart';

enum LibraryJob {
  videos('Find music videos'),
  releases('Refresh album releases'),
  artists('Refresh artist info');

  const LibraryJob(this.label);
  final String label;
}

class LibraryJobStatus {
  const LibraryJobStatus({
    this.job,
    this.running = false,
    this.done = 0,
    this.total = 0,
    this.failed = 0,
    this.updated = 0,
    this.cancelled = false,
  });
  final LibraryJob? job;
  final bool running, cancelled;
  final int done, total, failed, updated;
  String get message =>
      '${job?.label ?? 'Library job'} · $done/$total${running
          ? ''
          : cancelled
          ? ' · Stopped'
          : ' · Finished'}${job == LibraryJob.artists ? ' · $updated portraits updated' : ''}${failed > 0 ? ' · $failed unavailable' : ''}';
}

/// Explicit, serial metadata jobs. They update the metadata service's disk
/// cache without rewriting local audio tags or starting work in the background.
class LibraryJobs extends Notifier<LibraryJobStatus> {
  bool _cancel = false;
  @override
  LibraryJobStatus build() {
    ref.onDispose(() => _cancel = true);
    ref.listen(musicVideoIndexProvider, (previous, next) {
      if (next.scanning || previous?.scanning == true) {
        state = LibraryJobStatus(
          job: LibraryJob.videos,
          running: next.scanning,
          done: next.done,
          total: next.total,
          cancelled: !next.scanning && next.done < next.total,
        );
      }
    });
    return const LibraryJobStatus();
  }

  void cancel() {
    _cancel = true;
    if (state.job == LibraryJob.videos) {
      ref.read(musicVideoIndexProvider.notifier).cancel();
    }
  }

  Future<void> start(LibraryJob job, List<Song> songs) async {
    if (state.running) return;
    if (job == LibraryJob.videos) {
      state = const LibraryJobStatus(job: LibraryJob.videos, running: true);
      try {
        await ref.read(musicVideoIndexProvider.notifier).scan(songs);
        if (ref.mounted && state.running) {
          state = LibraryJobStatus(
            job: job,
            done: state.done,
            total: state.total,
          );
        }
      } catch (_) {
        if (ref.mounted) {
          state = LibraryJobStatus(
            job: job,
            done: state.done,
            total: state.total,
            failed: 1,
          );
        }
      }
      return;
    }
    final artists = lokalArtists(songs);
    _cancel = false;
    var done = 0, failed = 0, updated = 0;
    void publish(bool running) {
      if (ref.mounted) {
        state = LibraryJobStatus(
          job: job,
          running: running,
          done: done,
          total: artists.length,
          failed: failed,
          updated: updated,
          cancelled: _cancel,
        );
      }
    }

    publish(true);
    try {
      for (final artist in artists) {
        if (_cancel || !ref.mounted) break;
        try {
          final api = AppleMusicMetadataService.instance;
          if (job == LibraryJob.releases) {
            final releases = await api.searchAlbums(
              artist.name,
              limit: 100,
              refresh: true,
            );
            if (releases.isEmpty) failed++;
          } else {
            final info = await api.getArtistData(artist.name, refresh: true);
            if (info == null ||
                !await ref
                    .read(artistMetadataProvider.notifier)
                    .storeRefreshedPortrait(artist.name, info.info?.imageUrl)) {
              failed++;
            } else {
              updated++;
            }
          }
          LokalOnlineCatalogue.instance.invalidateArtist(artist.name);
        } catch (_) {
          failed++;
        }
        done++;
        publish(true);
        if (failed >= 5 && failed == done) {
          break; // Stop after repeated unavailable results.
        }
        if (!_cancel) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
    } finally {
      publish(false);
    }
  }
}

final libraryJobsProvider = NotifierProvider<LibraryJobs, LibraryJobStatus>(
  LibraryJobs.new,
);
