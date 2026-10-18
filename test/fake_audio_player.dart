import 'dart:async';
import 'package:just_audio/just_audio.dart';

// Native decoding is checked on-device; this fixture exercises our orchestration.
class FakeAudioPlayer implements AudioPlayer {
  final events = StreamController<PlaybackEvent>.broadcast();
  final states = StreamController<PlayerState>.broadcast();
  final positions = StreamController<Duration>.broadcast();
  final List<Uri> loaded = [];
  @override
  bool playing = false;
  @override
  ProcessingState processingState = ProcessingState.idle;
  @override
  Duration position = Duration.zero;
  @override
  Duration get bufferedPosition => position;
  @override
  Duration? get duration => const Duration(minutes: 3);
  @override
  double get speed => 1;
  @override
  Stream<PlaybackEvent> get playbackEventStream => events.stream;
  @override
  Stream<PlayerState> get playerStateStream => states.stream;
  @override
  Stream<Duration> get positionStream => positions.stream;

  void emit() => states.add(PlayerState(playing, processingState));
  @override
  Future<Duration?> setAudioSource(
    AudioSource audioSource, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    loaded.add((audioSource as UriAudioSource).uri);
    processingState = ProcessingState.ready;
    position = Duration.zero;
    emit();
    return duration;
  }

  @override
  Future<void> stop() async {
    playing = false;
    processingState = ProcessingState.idle;
    emit();
  }

  @override
  Future<void> play() async {
    playing = true;
    emit();
  }

  @override
  Future<void> pause() async {
    playing = false;
    emit();
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    this.position = position ?? Duration.zero;
    if (processingState == ProcessingState.completed) {
      processingState = ProcessingState.ready;
    }
    positions.add(this.position);
    emit();
  }

  @override
  Future<void> dispose() async {
    await events.close();
    await states.close();
    await positions.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
