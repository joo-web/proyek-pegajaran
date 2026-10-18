class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.artwork,
    required this.duration,
  });

  final String id;
  final String title;
  final String artist;
  final String artwork;
  final Duration duration;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'artwork': artwork,
    'durationMs': duration.inMilliseconds,
  };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
    id: json['id'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String,
    artwork: json['artwork'] as String,
    duration: Duration(milliseconds: json['durationMs'] as int),
  );
}

class MusicPlaylist {
  const MusicPlaylist({
    required this.id,
    required this.name,
    required this.tracks,
  });
  final String id;
  final String name;
  final List<Track> tracks;

  MusicPlaylist copyWith({String? name, List<Track>? tracks}) => MusicPlaylist(
    id: id,
    name: name ?? this.name,
    tracks: tracks ?? this.tracks,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tracks': tracks.map((track) => track.toJson()).toList(),
  };

  factory MusicPlaylist.fromJson(Map<String, dynamic> json) => MusicPlaylist(
    id: json['id'] as String,
    name: json['name'] as String,
    tracks: (json['tracks'] as List<dynamic>)
        .map((item) => Track.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
  );
}

class SavedDownload {
  const SavedDownload({
    required this.track,
    required this.filename,
    required this.bytes,
  });
  final Track track;
  final String filename;
  final int bytes;

  Map<String, dynamic> toJson() => {
    'track': track.toJson(),
    'filename': filename,
    'bytes': bytes,
  };

  factory SavedDownload.fromJson(Map<String, dynamic> json) {
    final filename = json['filename'] as String;
    if (!RegExp(r'^[a-zA-Z0-9_-]{11}\.(mp4|webm)$').hasMatch(filename)) {
      throw const FormatException('Nama berkas unduhan tidak valid.');
    }
    return SavedDownload(
      track: Track.fromJson(Map<String, dynamic>.from(json['track'] as Map)),
      filename: filename,
      bytes: json['bytes'] as int,
    );
  }
}

String formatDuration(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 1 << 31);
  final minutes = seconds ~/ 60;
  if (minutes >= 60) {
    return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
  return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
}
