import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nada_music/app_controller.dart';
import 'package:nada_music/services/download_manager.dart';
import 'package:nada_music/services/library_store.dart';
import 'package:nada_music/services/music_player.dart';
import 'package:nada_music/ui/app.dart';
import 'fake_audio_player.dart';
import 'fixtures.dart';

void main() {
  late Directory directory;
  late LibraryStore library;
  late MusicPlayer player;
  late DownloadManager downloads;
  late AppController controller;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nada-ui-test-');
    library = await LibraryStore.open(directory);
    final catalog = FakeCatalog();
    player = MusicPlayer(catalog, library, audioPlayer: FakeAudioPlayer());
    downloads = DownloadManager(catalog, library);
    controller = AppController(
      catalog: catalog,
      library: library,
      player: player,
      downloads: downloads,
    );
  });
  tearDown(() async {
    controller.dispose();
    downloads.dispose();
    await player.disposePlayer();
    library.dispose();
    await directory.delete(recursive: true);
  });

  testWidgets(
    'home navigation reaches the offline library and playlist creation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: nadaTheme,
          home: NadaHome(controller: controller),
        ),
      );
      expect(find.text('Temukan iramamu.'), findsOneWidget);
      await tester.tap(find.text('Unduhan'));
      await tester.pumpAndSettle();
      expect(find.text('Bawa musikmu ke mana saja'), findsOneWidget);
      await tester.tap(find.text('Playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buat playlist'));
      await tester.pumpAndSettle();
      expect(find.byType(PlaylistNameDialog), findsOneWidget);
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Nama playlist tidak boleh kosong.'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('playlist dialog returns a trimmed name and disposes safely', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: nadaTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) => const PlaylistNameDialog(),
                );
              },
              child: const Text('Buat playlist'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buat playlist'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '  Perjalanan sore  ');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(result, 'Perjalanan sore');
    expect(find.byType(PlaylistNameDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
