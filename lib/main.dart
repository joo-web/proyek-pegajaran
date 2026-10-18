import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'app_controller.dart';
import 'services/download_manager.dart';
import 'services/library_store.dart';
import 'services/music_catalog.dart';
import 'services/music_player.dart';
import 'ui/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NadaBootstrap());
}

class NadaBootstrap extends StatefulWidget {
  const NadaBootstrap({super.key});
  @override
  State<NadaBootstrap> createState() => _NadaBootstrapState();
}

class _NadaBootstrapState extends State<NadaBootstrap> {
  late Future<AppController> _setup;

  @override
  void initState() {
    super.initState();
    _setup = _initialize();
  }

  Future<AppController> _initialize() async {
    final support = await getApplicationSupportDirectory();
    final library = await LibraryStore.open(Directory('${support.path}/nada'));
    final catalog = YoutubeCatalog();
    final player = await AudioService.init<MusicPlayer>(
      builder: () => MusicPlayer(catalog, library),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'id.nada.music.playback',
        androidNotificationChannelName: 'Pemutar Nada',
        androidNotificationIcon: 'drawable/ic_notification',
        androidNotificationOngoing: true,
      ),
    );
    await player.configureSession();
    return AppController(
      catalog: catalog,
      library: library,
      player: player,
      downloads: DownloadManager(catalog, library),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Nada Music',
    debugShowCheckedModeBanner: false,
    theme: nadaTheme,
    home: FutureBuilder<AppController>(
      future: _setup,
      builder: (context, snapshot) {
        if (snapshot.hasData) return NadaHome(controller: snapshot.requireData);
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: snapshot.hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.library_music_outlined, size: 56),
                          const SizedBox(height: 20),
                          const Text(
                            'Perpustakaan belum dapat dibuka.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Data lama tetap disimpan. Periksa ruang penyimpanan lalu coba lagi.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: () => setState(() {
                              _setup = _initialize();
                            }),
                            child: const Text('Coba lagi'),
                          ),
                        ],
                      )
                    : const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.graphic_eq_rounded,
                            size: 56,
                            color: accent,
                          ),
                          SizedBox(height: 20),
                          Text('Menyiapkan ruang musikmu…'),
                          SizedBox(height: 24),
                          CircularProgressIndicator(),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
