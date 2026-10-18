import 'dart:async';
import 'package:nada_music/models/track.dart';
import 'package:nada_music/services/music_catalog.dart';

const firstTrack = Track(
  id: 'abcdefghijk',
  title: 'Lagu satu',
  artist: 'Artis satu',
  artwork: 'https://example.test/one.jpg',
  duration: Duration(minutes: 3),
);
const secondTrack = Track(
  id: '12345678901',
  title: 'Lagu dua',
  artist: 'Artis dua',
  artwork: 'https://example.test/two.jpg',
  duration: Duration(minutes: 4),
);

class FakeCatalog implements MusicCatalog {
  int resolutions = 0;
  int expectedBytes = 4;
  String extension = 'mp4';
  final List<int> requested = [];
  Stream<List<int>> Function()? streamFactory;

  @override
  Future<List<Track>> search(String query) async => [firstTrack, secondTrack];

  @override
  Future<ResolvedAudio> resolve(String videoId) async {
    requested.add(++resolutions);
    return ResolvedAudio(
      url: Uri.parse('https://example.test/audio'),
      extension: extension,
      bytes: expectedBytes,
    );
  }

  @override
  Stream<List<int>> read(ResolvedAudio audio) =>
      streamFactory?.call() ?? Stream.value([1, 2, 3, 4]);

  @override
  void close() {}
}

Future<void> waitUntil(bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Operation did not finish.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
