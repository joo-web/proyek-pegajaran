import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/track.dart';
import 'library_store.dart';
import 'music_catalog.dart';

enum DownloadStatus { queued, downloading, failed }

class DownloadTask {
  DownloadTask(this.track);
  final Track track;
  DownloadStatus status = DownloadStatus.queued;
  double? progress;
  String? error;
  bool cancelled = false;
}

class DownloadManager extends ChangeNotifier {
  DownloadManager(this.catalog, this.store);
  final MusicCatalog catalog;
  final LibraryStore store;
  final Map<String, DownloadTask> _tasks = {};
  bool _working = false;
  bool _disposed = false;
  bool get isWorking => _working;
  Map<String, DownloadTask> get tasks => Map.unmodifiable(_tasks);

  void enqueue(Track track) {
    if (store.downloads.containsKey(track.id)) return;
    final existing = _tasks[track.id];
    if (existing != null && existing.status != DownloadStatus.failed) return;
    _tasks[track.id] = DownloadTask(track);
    _notify();
    unawaited(_pump());
  }

  void cancel(String id) {
    final task = _tasks[id];
    if (task == null) return;
    task.cancelled = true;
    if (task.status != DownloadStatus.downloading) _tasks.remove(id);
    _notify();
  }

  Future<void> _pump() async {
    if (_working || _disposed) return;
    _working = true;
    try {
      while (!_disposed) {
        final waiting = _tasks.values.where(
          (task) => task.status == DownloadStatus.queued,
        );
        if (waiting.isEmpty) break;
        final task = waiting.first;
        task.status = DownloadStatus.downloading;
        _notify();
        await _download(task);
      }
    } finally {
      _working = false;
    }
  }

  Future<void> _download(DownloadTask task) async {
    File? part;
    File? completed;
    IOSink? sink;
    bool registered = false;
    try {
      final audio = await catalog.resolve(task.track.id);
      if (task.cancelled || _disposed) throw const _Cancelled();
      if (!RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(task.track.id) ||
          !const ['mp4', 'webm'].contains(audio.extension)) {
        throw const FormatException('Format unduhan tidak didukung.');
      }
      final filename = '${task.track.id}.${audio.extension}';
      completed = store.audioFile(filename);
      part = store.audioFile('$filename.part');
      sink = part.openWrite();
      // Surface asynchronous filesystem errors via the awaited sink.done/close.
      unawaited(
        sink.done.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
      int received = 0;
      final updates = Stopwatch()..start();
      await for (final chunk in catalog.read(audio)) {
        if (task.cancelled || _disposed) throw const _Cancelled();
        sink.add(chunk);
        received += chunk.length;
        if (updates.elapsedMilliseconds > 150) {
          task.progress = audio.bytes > 0
              ? (received / audio.bytes).clamp(0, 1).toDouble()
              : null;
          _notify();
          updates.reset();
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (task.cancelled || _disposed) throw const _Cancelled();
      if (received == 0 || (audio.bytes > 0 && received != audio.bytes)) {
        throw const FileSystemException(
          'Unduhan belum lengkap. Silakan coba lagi.',
        );
      }
      await part.rename(completed.path);
      await store.saveDownload(
        SavedDownload(track: task.track, filename: filename, bytes: received),
      );
      registered = true;
      _tasks.remove(task.track.id);
    } on _Cancelled {
      _tasks.remove(task.track.id);
    } catch (_) {
      if (task.cancelled || _disposed) {
        _tasks.remove(task.track.id);
      } else {
        task.status = DownloadStatus.failed;
        task.error =
            'Unduhan gagal. Periksa koneksi dan ruang penyimpanan, lalu coba lagi.';
      }
    } finally {
      try {
        await sink?.close();
      } catch (_) {
        /* The failed task remains retryable. */
      }
      try {
        if (part != null && await part.exists()) await part.delete();
        if (!registered && completed != null && await completed.exists()) {
          await completed.delete();
        }
      } catch (_) {
        /* Startup reconciles incomplete files and metadata. */
      }
      _notify();
    }
  }

  Future<void> remove(String id) async {
    final download = store.downloads[id];
    if (download == null) return;
    final file = store.audioFile(download.filename);
    if (await file.exists()) await file.delete();
    await store.forgetDownload(id);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final task in _tasks.values) {
      task.cancelled = true;
    }
    super.dispose();
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}
