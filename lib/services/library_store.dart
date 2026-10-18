import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/track.dart';

class LibraryStore extends ChangeNotifier {
  LibraryStore._(this.directory, this._playlists, this._downloads);
  final Directory directory;
  List<MusicPlaylist> _playlists;
  Map<String, SavedDownload> _downloads;
  Future<void> _pending = Future<void>.value();
  int _sequence = 0;
  String? recoveryNotice;

  List<MusicPlaylist> get playlists => List.unmodifiable(_playlists);
  Map<String, SavedDownload> get downloads => Map.unmodifiable(_downloads);
  Directory get audioDirectory => Directory('${directory.path}/audio');
  File audioFile(String filename) => File('${audioDirectory.path}/$filename');
  File get _file => File('${directory.path}/library.json');

  static Future<LibraryStore> open(Directory directory) async {
    await directory.create(recursive: true);
    final store = LibraryStore._(directory, [], {});
    final backup = File('${store._file.path}.bak');
    if (await store._file.exists() || await backup.exists()) {
      try {
        store._load(await store._file.readAsString());
      } catch (_) {
        try {
          store._load(await backup.readAsString());
          store.recoveryNotice =
              'Perpustakaan dipulihkan dari cadangan terakhir.';
          // Preserve the damaged file before restoring the known-good backup.
          if (await store._file.exists()) {
            await store._file.rename(
              '${store._file.path}.damaged-${DateTime.now().microsecondsSinceEpoch}',
            );
          }
          await backup.copy(store._file.path);
        } catch (_) {
          throw const FileSystemException(
            'Perpustakaan gagal dibaca. Data lama tetap disimpan.',
          );
        }
      }
    }
    await store.audioDirectory.create(recursive: true);
    // A killed download never appears as a complete song on the next launch.
    await for (final entry in store.audioDirectory.list()) {
      if (entry is File && entry.path.endsWith('.part')) await entry.delete();
    }
    final missing = <String>[];
    for (final item in store._downloads.entries) {
      final file = store.audioFile(item.value.filename);
      if (!await file.exists() || await file.length() != item.value.bytes) {
        missing.add(item.key);
      }
    }
    if (missing.isNotEmpty) {
      await store._commit((playlists, downloads) {
        for (final id in missing) {
          downloads.remove(id);
        }
      });
      store.recoveryNotice =
          'Berkas unduhan yang hilang atau tidak lengkap perlu diunduh ulang.';
    }
    return store;
  }

  void _load(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['version'] != 1) {
      throw const FormatException('Versi perpustakaan tidak didukung.');
    }
    final playlists = (data['playlists'] as List<dynamic>)
        .map(
          (item) =>
              MusicPlaylist.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final downloads = (data['downloads'] as List<dynamic>)
        .map(
          (item) =>
              SavedDownload.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    _playlists = playlists;
    _downloads = {for (final item in downloads) item.track.id: item};
  }

  Future<void> _commit(
    void Function(List<MusicPlaylist>, Map<String, SavedDownload>) edit,
  ) {
    final result = _pending.then((_) async {
      final playlists = List<MusicPlaylist>.of(_playlists);
      final downloads = Map<String, SavedDownload>.of(_downloads);
      edit(playlists, downloads);
      final next = jsonEncode({
        'version': 1,
        'playlists': playlists.map((playlist) => playlist.toJson()).toList(),
        'downloads': downloads.values
            .map((download) => download.toJson())
            .toList(),
      });
      final temporary = File('${_file.path}.tmp');
      await temporary.writeAsString(next, flush: true);
      if (await _file.exists()) await _file.copy('${_file.path}.bak');
      await temporary.rename(_file.path);
      _playlists = playlists;
      _downloads = downloads;
      notifyListeners();
    });
    // A failed disk write must not poison all subsequent operations.
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<String> createPlaylist(String name) async {
    final normalized = _validateName(name);
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    await _commit((playlists, downloads) {
      playlists.add(MusicPlaylist(id: id, name: normalized, tracks: const []));
    });
    return id;
  }

  Future<void> renamePlaylist(String id, String name) {
    final normalized = _validateName(name);
    return _commit((playlists, downloads) {
      final index = playlists.indexWhere((playlist) => playlist.id == id);
      if (index < 0) throw StateError('Playlist tidak ditemukan.');
      playlists[index] = playlists[index].copyWith(name: normalized);
    });
  }

  Future<void> deletePlaylist(String id) => _commit((playlists, downloads) {
    playlists.removeWhere((playlist) => playlist.id == id);
  });

  Future<void> addToPlaylist(String id, Track track) => _commit((
    playlists,
    downloads,
  ) {
    final index = playlists.indexWhere((playlist) => playlist.id == id);
    if (index < 0) throw StateError('Playlist tidak ditemukan.');
    final playlist = playlists[index];
    if (!playlist.tracks.any((existing) => existing.id == track.id)) {
      playlists[index] = playlist.copyWith(tracks: [...playlist.tracks, track]);
    }
  });

  Future<void> removeFromPlaylist(String id, String trackId) =>
      _commit((playlists, downloads) {
        final index = playlists.indexWhere((playlist) => playlist.id == id);
        if (index < 0) throw StateError('Playlist tidak ditemukan.');
        playlists[index] = playlists[index].copyWith(
          tracks: playlists[index].tracks
              .where((track) => track.id != trackId)
              .toList(),
        );
      });

  Future<void> saveDownload(SavedDownload download) =>
      _commit((playlists, downloads) {
        downloads[download.track.id] = download;
      });

  Future<void> forgetDownload(String id) => _commit((playlists, downloads) {
    downloads.remove(id);
  });

  String _validateName(String value) {
    final name = value.trim();
    if (name.isEmpty || name.length > 80) {
      throw const FormatException('Nama playlist harus berisi 1–80 karakter.');
    }
    return name;
  }
}
