import 'dart:async';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import 'library_store.dart';
import 'music_catalog.dart';

class MusicPlayer extends BaseAudioHandler with SeekHandler {
  MusicPlayer(this.catalog, this.store, {AudioPlayer? audioPlayer})
    : _player = audioPlayer ?? AudioPlayer() {
    _subscriptions.add(
      _player.playbackEventStream.listen(
        (_) => _broadcast(),
        onError: (Object error, StackTrace stack) => _fail(),
      ),
    );
    _subscriptions.add(
      _player.playerStateStream.listen((state) {
        _broadcast();
        if (state.processingState == ProcessingState.completed &&
            state.playing &&
            !_loading) {
          unawaited(_onCompleted());
        }
      }),
    );
  }

  final MusicCatalog catalog;
  final LibraryStore store;
  final AudioPlayer _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<Track> _tracks = [];
  int _index = -1;
  int _revision = 0;
  bool _loading = false;
  bool _completing = false;
  bool _shuffle = false;
  AudioServiceRepeatMode _repeat = AudioServiceRepeatMode.none;
  String? _error;

  Track? get current =>
      _index >= 0 && _index < _tracks.length ? _tracks[_index] : null;
  List<Track> get tracks => List.unmodifiable(_tracks);
  int get currentIndex => _index;
  bool get shuffle => _shuffle;
  AudioServiceRepeatMode get repeat => _repeat;
  Stream<Duration> get positionStream => _player.positionStream;
  Duration get position => _player.position;

  Future<void> configureSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  MediaItem _item(Track track) => MediaItem(
    id: track.id,
    title: track.title,
    artist: track.artist,
    duration: track.duration,
    artUri: Uri.tryParse(track.artwork),
  );

  Future<void> playTracks(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty || startIndex < 0 || startIndex >= tracks.length) return;
    _tracks = List.of(tracks);
    queue.add(_tracks.map(_item).toList());
    await _load(startIndex);
  }

  Future<void> _load(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    final revision = ++_revision;
    _index = index;
    _loading = true;
    _error = null;
    mediaItem.add(_item(_tracks[index]));
    _broadcast();
    try {
      await _player.stop();
      if (revision != _revision) return;
      final track = _tracks[index];
      final saved = store.downloads[track.id];
      Uri source;
      if (saved != null && await store.audioFile(saved.filename).exists()) {
        source = store.audioFile(saved.filename).uri;
      } else {
        source = (await catalog.resolve(track.id)).url;
      }
      if (revision != _revision) return;
      await _player
          .setAudioSource(AudioSource.uri(source, tag: _item(track)))
          .timeout(const Duration(seconds: 30));
      if (revision != _revision) return;
      final duration = _player.duration;
      if (duration != null) {
        mediaItem.add(_item(track).copyWith(duration: duration));
      }
      _loading = false;
      _broadcast();
      unawaited(
        _player.play().catchError((Object error, StackTrace stack) {
          if (revision == _revision) _fail();
        }),
      );
    } catch (_) {
      if (revision == _revision) {
        _loading = false;
        _fail();
      }
    }
  }

  void _fail() {
    _error = 'Lagu tidak dapat diputar. Periksa koneksi atau coba lagu lain.';
    _loading = false;
    _broadcast();
  }

  void _broadcast() {
    final processing = _error != null
        ? AudioProcessingState.error
        : _loading
        ? AudioProcessingState.loading
        : switch (_player.processingState) {
            ProcessingState.idle => AudioProcessingState.idle,
            ProcessingState.loading => AudioProcessingState.loading,
            ProcessingState.buffering => AudioProcessingState.buffering,
            ProcessingState.ready => AudioProcessingState.ready,
            ProcessingState.completed => AudioProcessingState.completed,
          };
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          _player.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processing,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _index < 0 ? null : _index,
        repeatMode: _repeat,
        shuffleMode: _shuffle
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        errorCode: _error == null ? null : 1,
        errorMessage: _error,
      ),
    );
  }

  Future<void> _onCompleted() async {
    if (_completing) return;
    _completing = true;
    try {
      if (_repeat == AudioServiceRepeatMode.one) {
        await _player.seek(Duration.zero);
        unawaited(
          _player.play().catchError((Object _, StackTrace _) => _fail()),
        );
      } else if (_shuffle ||
          _index < _tracks.length - 1 ||
          _repeat == AudioServiceRepeatMode.all) {
        await skipToNext();
      } else {
        await _player.pause();
        _broadcast();
      }
    } finally {
      _completing = false;
    }
  }

  @override
  Future<void> play() async {
    if (current == null || _loading) return;
    if (_error != null || _player.processingState == ProcessingState.idle) {
      await _load(_index);
      return;
    }
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    unawaited(_player.play().catchError((Object _, StackTrace _) => _fail()));
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    ++_revision;
    _loading = false;
    _error = null;
    await _player.stop();
    _broadcast();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToQueueItem(int index) => _load(index);

  @override
  Future<void> skipToPrevious() async {
    if (_tracks.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else {
      await _load((_index - 1 + _tracks.length) % _tracks.length);
    }
  }

  @override
  Future<void> skipToNext() async {
    if (_tracks.isEmpty) return;
    int index = (_index + 1) % _tracks.length;
    if (_shuffle && _tracks.length > 1) {
      index =
          (_index + 1 + Random().nextInt(_tracks.length - 1)) % _tracks.length;
    }
    await _load(index);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeat = repeatMode;
    _broadcast();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _shuffle = shuffleMode != AudioServiceShuffleMode.none;
    _broadcast();
  }

  Future<void> disposePlayer() async {
    ++_revision;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
  }
}
