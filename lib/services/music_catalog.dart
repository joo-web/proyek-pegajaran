import 'dart:async';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track.dart';

abstract interface class MusicCatalog {
  Future<List<Track>> search(String query);
  Future<ResolvedAudio> resolve(String videoId);
  Stream<List<int>> read(ResolvedAudio audio);
  void close();
}

class ResolvedAudio {
  const ResolvedAudio({
    required this.url,
    required this.extension,
    required this.bytes,
    this.source,
  });
  final Uri url;
  final String extension;
  final int bytes;
  final AudioOnlyStreamInfo? source;
}

class YoutubeCatalog implements MusicCatalog {
  final YoutubeExplode _youtube = YoutubeExplode();

  Track _track(Video video) => Track(
    id: video.id.value,
    title: video.title,
    artist: video.author,
    artwork: video.thumbnails.highResUrl,
    duration: video.duration ?? Duration.zero,
  );

  @override
  Future<List<Track>> search(String query) async {
    final text = query.trim();
    if (text.isEmpty) return [];
    final id = VideoId.parseVideoId(text);
    if (id != null) {
      final video = await _youtube.videos
          .get(id)
          .timeout(const Duration(seconds: 25));
      if (video.isLive) {
        throw const CatalogException('Siaran langsung belum didukung.');
      }
      return [_track(video)];
    }
    final result = await _youtube.search
        .search('$text music')
        .timeout(const Duration(seconds: 25));
    return result
        .where((video) => !video.isLive && video.duration != null)
        .map(_track)
        .toList();
  }

  @override
  Future<ResolvedAudio> resolve(String videoId) async {
    // Resolve on every play/download: signed YouTube stream URLs expire.
    final manifest = await _youtube.videos.streamsClient
        .getManifest(videoId)
        .timeout(const Duration(seconds: 30));
    final supported = manifest.audioOnly
        .where(
          (stream) =>
              stream.container.name == 'mp4' || stream.container.name == 'webm',
        )
        .toList();
    if (supported.isEmpty) {
      throw const CatalogException('Audio tidak tersedia untuk lagu ini.');
    }
    // AAC/MP4 has broad Android support. Preserve the actual container on disk.
    final mp4 = supported
        .where((stream) => stream.container.name == 'mp4')
        .toList();
    final options = mp4.isNotEmpty ? mp4 : supported;
    options.sort(
      (a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond),
    );
    final selected = options.first;
    return ResolvedAudio(
      url: selected.url,
      extension: selected.container.name,
      bytes: selected.size.totalBytes,
      source: selected,
    );
  }

  @override
  Stream<List<int>> read(ResolvedAudio audio) => _youtube.videos.streamsClient
      .get(audio.source!)
      .timeout(const Duration(seconds: 30));

  @override
  void close() => _youtube.close();
}

class CatalogException implements Exception {
  const CatalogException(this.message);
  final String message;
  @override
  String toString() => message;
}
