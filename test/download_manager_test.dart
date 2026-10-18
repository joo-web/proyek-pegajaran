import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nada_music/services/download_manager.dart';
import 'package:nada_music/services/library_store.dart';
import 'fixtures.dart';

void main() {
  late Directory directory;
  late LibraryStore store;
  late FakeCatalog catalog;
  late DownloadManager manager;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nada-download-test-');
    store = await LibraryStore.open(directory);
    catalog = FakeCatalog();
    manager = DownloadManager(catalog, store);
  });
  tearDown(() async {
    manager.dispose();
    await waitUntil(() => !manager.isWorking);
    store.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'download saves real bytes and the matching container extension',
    () async {
      catalog.extension = 'webm';
      manager.enqueue(firstTrack);
      await waitUntil(() => !manager.isWorking);
      expect(manager.tasks, isEmpty);
      final download = store.downloads[firstTrack.id]!;
      expect(download.filename, '${firstTrack.id}.webm');
      expect(await store.audioFile(download.filename).readAsBytes(), [
        1,
        2,
        3,
        4,
      ]);
      final reopened = await LibraryStore.open(directory);
      addTearDown(reopened.dispose);
      expect(reopened.downloads, contains(firstTrack.id));
    },
  );

  test(
    'truncated response is never registered as playable offline audio',
    () async {
      catalog.expectedBytes = 10;
      manager.enqueue(firstTrack);
      await waitUntil(() => !manager.isWorking);
      expect(store.downloads, isEmpty);
      expect(manager.tasks[firstTrack.id]?.status, DownloadStatus.failed);
      expect(await store.audioDirectory.list().length, 0);
    },
  );

  test(
    'stream failure is cleaned up and a fresh retry resolves another URL',
    () async {
      catalog.streamFactory = () async* {
        yield [1, 2];
        throw const SocketException('Connection lost');
      };
      manager.enqueue(firstTrack);
      await waitUntil(() => !manager.isWorking);
      expect(manager.tasks[firstTrack.id]?.status, DownloadStatus.failed);
      expect(await store.audioDirectory.list().length, 0);
      catalog.streamFactory = null;
      manager.enqueue(firstTrack);
      await waitUntil(() => !manager.isWorking);
      expect(catalog.resolutions, 2);
      expect(store.downloads, contains(firstTrack.id));
    },
  );

  test(
    'cancelling an active transfer removes partial bytes and metadata',
    () async {
      final gate = Completer<void>();
      final started = Completer<void>();
      catalog.streamFactory = () async* {
        yield [1, 2];
        started.complete();
        await gate.future;
        yield [3, 4];
      };
      manager.enqueue(firstTrack);
      await started.future;
      manager.cancel(firstTrack.id);
      gate.complete();
      await waitUntil(() => !manager.isWorking);
      expect(manager.tasks, isEmpty);
      expect(store.downloads, isEmpty);
      expect(await store.audioDirectory.list().length, 0);
    },
  );

  test(
    'queued cancellation and duplicates never start additional transfers',
    () async {
      final gate = Completer<void>();
      catalog.streamFactory = () async* {
        await gate.future;
        yield [1, 2, 3, 4];
      };
      manager.enqueue(firstTrack);
      manager.enqueue(firstTrack);
      manager.enqueue(secondTrack);
      manager.cancel(secondTrack.id);
      gate.complete();
      await waitUntil(() => !manager.isWorking);
      expect(catalog.resolutions, 1);
      expect(store.downloads.keys, [firstTrack.id]);
      manager.enqueue(firstTrack);
      expect(catalog.resolutions, 1);
    },
  );

  test('a failed transfer does not block the next song in the queue', () async {
    int calls = 0;
    catalog.streamFactory = () async* {
      if (++calls == 1) throw const SocketException('Unavailable');
      yield [1, 2, 3, 4];
    };
    manager.enqueue(firstTrack);
    manager.enqueue(secondTrack);
    await waitUntil(() => !manager.isWorking);
    expect(manager.tasks[firstTrack.id]?.status, DownloadStatus.failed);
    expect(store.downloads, contains(secondTrack.id));
  });

  test(
    'removing offline audio deletes both the file and persistent record',
    () async {
      manager.enqueue(firstTrack);
      await waitUntil(() => !manager.isWorking);
      await manager.remove(firstTrack.id);
      expect(store.downloads, isEmpty);
      expect(await store.audioDirectory.list().length, 0);
      final reopened = await LibraryStore.open(directory);
      addTearDown(reopened.dispose);
      expect(reopened.downloads, isEmpty);
    },
  );
}
