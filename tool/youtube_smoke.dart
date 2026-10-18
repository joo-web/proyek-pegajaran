import 'dart:io';
import 'package:nada_music/services/music_catalog.dart';

// Opt-in live check; unit tests use fixtures and never contact YouTube.
Future<void> main(List<String> arguments) async {
  HttpOverrides.global = _CloudHttpOverrides();
  final catalog = YoutubeCatalog();
  try {
    final results = await catalog.search('lofi music');
    if (results.isEmpty) {
      throw StateError('YouTube search returned no results.');
    }
    // Blender's Big Buck Bunny is used only to check an audio stream response.
    final audio = await catalog.resolve(
      arguments.isEmpty ? 'aqz-KE-bpKQ' : arguments.first,
    );
    final chunk = await catalog.read(audio).first;
    if (chunk.isEmpty) throw StateError('The audio response was empty.');
    stdout.writeln(
      'Live search: ${results.length} results. Audio response: ${chunk.length} bytes (${audio.extension}).',
    );
  } catch (error) {
    stderr.writeln(
      'Live YouTube check failed: ${error.runtimeType}. Check network access and extractor compatibility.',
    );
    exitCode = 1;
  } finally {
    catalog.close();
  }
}

class _CloudHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..findProxy = (uri) => HttpClient.findProxyFromEnvironment(uri);
}
