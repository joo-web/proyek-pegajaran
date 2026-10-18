import 'dart:async';
import 'package:flutter/foundation.dart';
import 'models/track.dart';
import 'services/download_manager.dart';
import 'services/library_store.dart';
import 'services/music_catalog.dart';
import 'services/music_player.dart';

class AppController extends ChangeNotifier {
  AppController({
    required this.catalog,
    required this.library,
    required this.player,
    required this.downloads,
  }) {
    library.addListener(notifyListeners);
    downloads.addListener(notifyListeners);
    _playback = player.playbackState.listen((_) => notifyListeners());
  }
  final MusicCatalog catalog;
  final LibraryStore library;
  final MusicPlayer player;
  final DownloadManager downloads;
  late final StreamSubscription<dynamic> _playback;
  final notices = StreamController<String>.broadcast();
  int _searchRevision = 0;
  String query = '';
  List<Track> results = [];
  bool searching = false;
  String? searchError;

  Future<void> search(String value) async {
    final text = value.trim();
    final revision = ++_searchRevision;
    query = text;
    searchError = null;
    results = [];
    searching = text.isNotEmpty;
    notifyListeners();
    if (text.isEmpty) return;
    try {
      final found = await catalog.search(text);
      if (revision != _searchRevision) return;
      results = found;
    } catch (_) {
      if (revision != _searchRevision) return;
      searchError =
          'Pencarian gagal. Periksa koneksi, lalu coba lagi. YouTube mungkin sedang membatasi akses.';
    } finally {
      if (revision == _searchRevision) {
        searching = false;
        notifyListeners();
      }
    }
  }

  Future<void> guard(Future<void> Function() action, {String? success}) async {
    try {
      await action();
      if (success != null) notices.add(success);
    } catch (_) {
      notices.add(
        'Perubahan gagal disimpan. Periksa ruang penyimpanan, lalu coba lagi.',
      );
    }
  }

  Future<void> removeDownload(String id) => guard(() async {
    if (player.current?.id == id) await player.stop();
    await downloads.remove(id);
  }, success: 'Unduhan dihapus. Lagu tetap ada di playlist.');

  @override
  void dispose() {
    library.removeListener(notifyListeners);
    downloads.removeListener(notifyListeners);
    unawaited(_playback.cancel());
    unawaited(notices.close());
    super.dispose();
  }
}
