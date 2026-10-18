import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nada_music/models/track.dart';
import 'package:nada_music/services/library_store.dart';
import 'package:nada_music/services/music_player.dart';
import 'fake_audio_player.dart';
import 'fixtures.dart';

void main() {
  late Directory directory;
  late LibraryStore store;
  late FakeCatalog catalog;
  late FakeAudioPlayer native;
  late MusicPlayer player;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nada-player-test-');
    store = await LibraryStore.open(directory);
    catalog = FakeCatalog();
    native = FakeAudioPlayer();
    player = MusicPlayer(catalog, store, audioPlayer: native);
  });
  tearDown(() async {
    await player.disposePlayer();
    store.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'offline playback uses a file URI without contacting the catalog',
    () async {
      await store.audioFile('${firstTrack.id}.mp4').writeAsBytes([1, 2, 3, 4]);
      await store.saveDownload(
        const SavedDownload(
          track: firstTrack,
          filename: 'abcdefghijk.mp4',
          bytes: 4,
        ),
      );
      await player.playTracks([firstTrack]);
      expect(native.loaded.single.scheme, 'file');
      expect(catalog.resolutions, 0);
      expect(native.playing, isTrue);
    },
  );

  test(
    'missing offline file falls back to a freshly resolved online source',
    () async {
      await store.saveDownload(
        const SavedDownload(
          track: firstTrack,
          filename: 'abcdefghijk.mp4',
          bytes: 4,
        ),
      );
      await player.playTracks([firstTrack]);
      expect(native.loaded.single.scheme, 'https');
      expect(catalog.resolutions, 1);
    },
  );

  test(
    'queue navigation, pause, resume and seek affect the same player',
    () async {
      await player.playTracks([firstTrack, secondTrack]);
      await player.skipToNext();
      expect(player.current?.id, secondTrack.id);
      expect(player.queue.value, hasLength(2));
      await player.pause();
      expect(native.playing, isFalse);
      await player.play();
      expect(native.playing, isTrue);
      await player.seek(const Duration(seconds: 20));
      await player.skipToPrevious();
      expect(player.current?.id, secondTrack.id);
      expect(native.position, Duration.zero);
      await player.skipToPrevious();
      expect(player.current?.id, firstTrack.id);
    },
  );

  test('completion advances the queue then pauses at its end', () async {
    await player.playTracks([firstTrack, secondTrack]);
    native.processingState = ProcessingState.completed;
    native.emit();
    await waitUntil(
      () => player.current?.id == secondTrack.id && native.playing,
    );
    native.processingState = ProcessingState.completed;
    native.emit();
    await waitUntil(() => !native.playing);
    expect(player.current?.id, secondTrack.id);
  });

  test('repeat one replays locally without resolving another URL', () async {
    await player.playTracks([firstTrack]);
    await player.setRepeatMode(AudioServiceRepeatMode.one);
    native.position = const Duration(minutes: 3);
    native.processingState = ProcessingState.completed;
    native.emit();
    await waitUntil(() => native.position == Duration.zero);
    expect(catalog.resolutions, 1);
    expect(player.repeat, AudioServiceRepeatMode.one);
  });
}
