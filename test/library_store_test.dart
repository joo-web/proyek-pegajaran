import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nada_music/models/track.dart';
import 'package:nada_music/services/library_store.dart';
import 'fixtures.dart';

void main() {
  late Directory directory;
  late LibraryStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nada-library-test-');
    store = await LibraryStore.open(directory);
  });
  tearDown(() async {
    store.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'playlist, edits, and track metadata survive a fresh store instance',
    () async {
      final id = await store.createPlaylist('  Perjalanan  ');
      await store.addToPlaylist(id, firstTrack);
      await store.renamePlaylist(id, 'Sore');
      final reopened = await LibraryStore.open(directory);
      addTearDown(reopened.dispose);
      expect(reopened.playlists.single.name, 'Sore');
      expect(
        reopened.playlists.single.tracks.single.toJson(),
        firstTrack.toJson(),
      );
    },
  );

  test(
    'duplicate additions are idempotent and removal preserves other songs',
    () async {
      final id = await store.createPlaylist('Musik');
      await store.addToPlaylist(id, firstTrack);
      await store.addToPlaylist(id, firstTrack);
      await store.addToPlaylist(id, secondTrack);
      expect(store.playlists.single.tracks, hasLength(2));
      await store.removeFromPlaylist(id, firstTrack.id);
      expect(store.playlists.single.tracks.single.id, secondTrack.id);
      await store.deletePlaylist(id);
      final reopened = await LibraryStore.open(directory);
      addTearDown(reopened.dispose);
      expect(reopened.playlists, isEmpty);
    },
  );

  test('concurrent updates retain every playlist and song', () async {
    final ids = await Future.wait(
      List.generate(8, (i) => store.createPlaylist('Playlist $i')),
    );
    expect(ids.toSet(), hasLength(8));
    await Future.wait([
      store.addToPlaylist(ids.first, firstTrack),
      store.addToPlaylist(ids.first, secondTrack),
    ]);
    final reopened = await LibraryStore.open(directory);
    addTearDown(reopened.dispose);
    expect(reopened.playlists, hasLength(8));
    expect(reopened.playlists.first.tracks, hasLength(2));
  });

  test(
    'blank and overly long playlist names are rejected without writing data',
    () async {
      await expectLater(store.createPlaylist('   '), throwsFormatException);
      await expectLater(store.createPlaylist('x' * 81), throwsFormatException);
      expect(store.playlists, isEmpty);
    },
  );

  test(
    'corrupt main file is preserved and recovered from last good backup',
    () async {
      await store.createPlaylist('Cadangan');
      await store.createPlaylist('Terbaru');
      await File('${directory.path}/library.json').writeAsString('not-json');
      final reopened = await LibraryStore.open(directory);
      addTearDown(reopened.dispose);
      expect(reopened.playlists.single.name, 'Cadangan');
      expect(reopened.recoveryNotice, isNotNull);
      expect(
        await directory
            .list()
            .where((entry) => entry.path.contains('.damaged-'))
            .length,
        1,
      );
    },
  );

  test(
    'unrecoverable corruption fails without erasing original data',
    () async {
      final file = File('${directory.path}/library.json');
      await file.writeAsString('original broken data');
      await expectLater(
        LibraryStore.open(directory),
        throwsA(isA<FileSystemException>()),
      );
      expect(await file.readAsString(), 'original broken data');
    },
  );

  test(
    'restart drops incomplete download records and removes part files',
    () async {
      await store.audioFile('${firstTrack.id}.mp4').writeAsBytes([1]);
      await store.saveDownload(
        const SavedDownload(
          track: firstTrack,
          filename: 'abcdefghijk.mp4',
          bytes: 4,
        ),
      );
      await store.audioFile('${secondTrack.id}.mp4.part').writeAsBytes([9]);
      final reopened = await LibraryStore.open(directory);
      addTearDown(reopened.dispose);
      expect(reopened.downloads, isEmpty);
      expect(
        await reopened.audioFile('${secondTrack.id}.mp4.part').exists(),
        isFalse,
      );
    },
  );

  test(
    'completed audio remains available after restart and playlist deletion',
    () async {
      final id = await store.createPlaylist('Offline');
      await store.addToPlaylist(id, firstTrack);
      await store.audioFile('${firstTrack.id}.mp4').writeAsBytes([1, 2, 3, 4]);
      await store.saveDownload(
        const SavedDownload(
          track: firstTrack,
          filename: 'abcdefghijk.mp4',
          bytes: 4,
        ),
      );
      await store.deletePlaylist(id);
      final reopened = await LibraryStore.open(directory);
      addTearDown(reopened.dispose);
      expect(reopened.downloads[firstTrack.id]?.track.id, firstTrack.id);
      expect(await reopened.audioFile('${firstTrack.id}.mp4').readAsBytes(), [
        1,
        2,
        3,
        4,
      ]);
    },
  );

  test('download paths cannot escape the application audio directory', () {
    expect(
      () => SavedDownload.fromJson({
        'track': firstTrack.toJson(),
        'filename': '../private.mp4',
        'bytes': 4,
      }),
      throwsFormatException,
    );
  });
}
