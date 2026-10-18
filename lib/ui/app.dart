import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import '../app_controller.dart';
import '../models/track.dart';
import '../services/download_manager.dart';

const accent = Color(0xFFC5F277);
const background = Color(0xFF10120F);
const panel = Color(0xFF1C201A);
const muted = Color(0xFFA4AC9E);

final nadaTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.dark,
  ).copyWith(primary: accent, surface: panel, onPrimary: background),
  appBarTheme: const AppBarTheme(
    backgroundColor: background,
    surfaceTintColor: Colors.transparent,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: panel,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
  ),
  snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: background,
    indicatorColor: Color(0xFF354327),
  ),
);

class NadaHome extends StatefulWidget {
  const NadaHome({required this.controller, super.key});
  final AppController controller;
  @override
  State<NadaHome> createState() => _NadaHomeState();
}

class _NadaHomeState extends State<NadaHome> {
  int _tab = 0;
  final _search = TextEditingController();
  late StreamSubscription<String> _notices;

  @override
  void initState() {
    super.initState();
    _notices = widget.controller.notices.stream.listen((message) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    });
    final notice = widget.controller.library.recoveryNotice;
    if (notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(notice)));
        }
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    unawaited(_notices.cancel());
    super.dispose();
  }

  void _doSearch(String query) {
    _search.text = query;
    FocusScope.of(context).unfocus();
    unawaited(widget.controller.search(query));
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      return Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.graphic_eq_rounded, color: accent, size: 30),
              const SizedBox(width: 8),
              const Text(
                'nada',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 30,
                  letterSpacing: -1.5,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(left: 10),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'MUSIC',
                  style: TextStyle(fontSize: 9, letterSpacing: 2, color: muted),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Tentang Nada',
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: () => showAboutDialog(
                context: context,
                applicationName: 'Nada Music',
                applicationVersion: '0.1.0',
                children: [
                  const Text(
                    'Cari musik dari YouTube, buat playlist, dan dengarkan unduhan di perangkat.\n\nUnduhan disimpan di ruang aplikasi. Menghapus data aplikasi juga menghapus playlist dan unduhan.\n\nIntegrasi YouTube tidak resmi dan ketersediaannya dapat berubah.',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: switch (_tab) {
                      0 => _explore(c),
                      1 => _downloads(c),
                      _ => _playlists(c),
                    },
                  ),
                ),
              ),
              if (c.player.current != null) MiniPlayer(controller: c),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (index) => setState(() {
            _tab = index;
          }),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Jelajahi',
            ),
            NavigationDestination(
              icon: Icon(Icons.downloading_outlined),
              selectedIcon: Icon(Icons.downloading),
              label: 'Unduhan',
            ),
            NavigationDestination(
              icon: Icon(Icons.library_music_outlined),
              selectedIcon: Icon(Icons.library_music),
              label: 'Playlist',
            ),
          ],
        ),
      );
    },
  );

  Widget _explore(AppController c) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
    children: [
      const Text(
        'Temukan iramamu.',
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Cari lagu, artis, atau tempel tautan YouTube.',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _search,
        textInputAction: TextInputAction.search,
        onSubmitted: _doSearch,
        decoration: InputDecoration(
          hintText: 'Lagu apa yang ingin kamu dengar?',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
            tooltip: 'Cari musik',
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: () => _doSearch(_search.text),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ['Indonesia', 'Lofi', 'Jazz', 'Akustik']
            .map(
              (query) => ActionChip(
                label: Text(query),
                onPressed: () => _doSearch(query),
                backgroundColor: panel,
                side: BorderSide.none,
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 28),
      if (c.query.isEmpty) ...[
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              colors: [Color(0xFF334429), Color(0xFF1A2317)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.headphones_rounded, color: accent, size: 42),
                  Spacer(),
                  Icon(Icons.multitrack_audio_rounded, color: accent, size: 70),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'Musikmu.\nDi mana pun.',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Simpan lagu kesukaanmu dan dengarkan kembali tanpa koneksi.',
                style: TextStyle(color: Color(0xFFCBD6C3)),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _doSearch('musik Indonesia'),
                icon: const Icon(Icons.north_east),
                label: const Text('Mulai jelajahi'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const _SectionTitle('Ruang untuk musikmu'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.download_done_rounded,
                label: 'Lagu offline',
                count: c.library.downloads.length,
                onTap: () => setState(() {
                  _tab = 1;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.queue_music_rounded,
                label: 'Playlist pribadi',
                count: c.library.playlists.length,
                onTap: () => setState(() {
                  _tab = 2;
                }),
              ),
            ),
          ],
        ),
      ] else if (c.searching) ...[
        const Padding(
          padding: EdgeInsets.all(50),
          child: Center(child: CircularProgressIndicator()),
        ),
        const Center(
          child: Text(
            'Mencari musik di YouTube…',
            style: TextStyle(color: muted),
          ),
        ),
      ] else if (c.searchError != null) ...[
        EmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'Belum terhubung',
          message: c.searchError!,
          action: OutlinedButton(
            onPressed: () => _doSearch(c.query),
            child: const Text('Coba lagi'),
          ),
        ),
      ] else if (c.results.isEmpty) ...[
        const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Belum ada hasil',
          message: 'Coba judul lagu atau nama artis yang berbeda.',
        ),
      ] else ...[
        _SectionTitle('Hasil pencarian', trailing: '${c.results.length} lagu'),
        const SizedBox(height: 4),
        const Text(
          'Sumber: YouTube',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        for (int i = 0; i < c.results.length; i++)
          TrackTile(
            controller: c,
            track: c.results[i],
            onPlay: () =>
                unawaited(c.player.playTracks(c.results, startIndex: i)),
          ),
      ],
    ],
  );

  Widget _downloads(AppController c) {
    final saved = c.library.downloads.values.toList().reversed.toList();
    final tasks = c.downloads.tasks.values.toList();
    final bytes = saved.fold<int>(
      0,
      (total, download) => total + download.bytes,
    );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Selalu bisa didengar.',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${saved.length} lagu tersimpan · ${(bytes / 1048576).toStringAsFixed(1)} MB',
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 8),
        const Text(
          'Unduhan tersedia di aplikasi, termasuk saat offline.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        if (tasks.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionTitle('Antrean unduhan'),
          const SizedBox(height: 12),
          for (final task in tasks)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (task.status == DownloadStatus.failed)
                          IconButton(
                            tooltip: 'Ulangi unduhan',
                            onPressed: () => c.downloads.enqueue(task.track),
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        IconButton(
                          tooltip: 'Batalkan unduhan',
                          onPressed: () => c.downloads.cancel(task.track.id),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    if (task.status == DownloadStatus.downloading) ...[
                      LinearProgressIndicator(value: task.progress),
                      const SizedBox(height: 8),
                      Text(
                        task.cancelled
                            ? 'Membatalkan…'
                            : task.progress == null
                            ? 'Menyiapkan audio…'
                            : '${(task.progress! * 100).round()}%',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ] else
                      Text(
                        task.error ?? 'Menunggu giliran',
                        style: TextStyle(
                          color: task.error == null
                              ? muted
                              : Colors.orangeAccent,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 24),
        if (saved.isNotEmpty) ...[
          Row(
            children: [
              const Expanded(child: _SectionTitle('Koleksi offline')),
              TextButton.icon(
                onPressed: () => unawaited(
                  c.player.playTracks(
                    saved.map((entry) => entry.track).toList(),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Putar semua'),
              ),
            ],
          ),
          for (int i = 0; i < saved.length; i++)
            TrackTile(
              controller: c,
              track: saved[i].track,
              onPlay: () => unawaited(
                c.player.playTracks(
                  saved.map((entry) => entry.track).toList(),
                  startIndex: i,
                ),
              ),
            ),
        ] else if (tasks.isEmpty)
          EmptyState(
            icon: Icons.download_for_offline_outlined,
            title: 'Bawa musikmu ke mana saja',
            message:
                'Cari lagu lalu pilih Unduh. Lagu yang selesai diunduh akan muncul di sini.',
            action: FilledButton(
              onPressed: () => setState(() {
                _tab = 0;
              }),
              child: const Text('Cari musik'),
            ),
          ),
      ],
    );
  }

  Widget _playlists(AppController c) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'Dibuat untuk suasanamu.',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -.8,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Kumpulkan lagu dalam playlist milikmu.',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 24),
      OutlinedButton.icon(
        onPressed: () => _newPlaylist(context, c),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buat playlist'),
      ),
      const SizedBox(height: 20),
      if (c.library.playlists.isEmpty)
        const EmptyState(
          icon: Icons.queue_music_rounded,
          title: 'Setiap suasana punya playlist',
          message:
              'Buat playlist pertamamu, lalu tambahkan lagu dari hasil pencarian.',
        ),
      for (final playlist in c.library.playlists)
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFF354327),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.queue_music_rounded,
                color: accent,
                size: 30,
              ),
            ),
            title: Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${playlist.tracks.length} lagu',
              style: const TextStyle(color: muted),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    PlaylistPage(controller: c, playlistId: playlist.id),
              ),
            ),
          ),
        ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});
  final String title;
  final String? trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
      ),
      if (trailing != null)
        Text(trailing!, style: const TextStyle(color: muted, fontSize: 12)),
    ],
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: panel,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent),
            const SizedBox(height: 18),
            Text(
              '$count',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 28),
            ),
            Text(label, style: const TextStyle(color: muted, fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 42),
    child: Column(
      children: [
        Icon(icon, color: accent, size: 56),
        const SizedBox(height: 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, height: 1.5),
        ),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ],
    ),
  );
}

class Artwork extends StatelessWidget {
  const Artwork(this.track, {this.size = 52, this.radius = 10, super.key});
  final Track track;
  final double size;
  final double radius;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      width: size,
      height: size,
      child: Image.network(
        track.artwork,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: const Color(0xFF354327),
          child: Icon(
            Icons.music_note_rounded,
            color: accent,
            size: size * .45,
          ),
        ),
      ),
    ),
  );
}

class TrackTile extends StatelessWidget {
  const TrackTile({
    required this.controller,
    required this.track,
    required this.onPlay,
    this.playlistId,
    super.key,
  });
  final AppController controller;
  final Track track;
  final VoidCallback onPlay;
  final String? playlistId;

  @override
  Widget build(BuildContext context) {
    final saved = controller.library.downloads.containsKey(track.id);
    final current = controller.player.current?.id == track.id;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 5),
      leading: Artwork(track),
      title: Text(
        track.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: current ? accent : null,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Row(
        children: [
          if (saved)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.download_done_rounded, color: accent, size: 13),
            ),
          Expanded(
            child: Text(
              '${track.artist} · ${formatDuration(track.duration)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ),
        ],
      ),
      onTap: onPlay,
      trailing: PopupMenuButton<String>(
        tooltip: 'Opsi lagu',
        onSelected: (action) async {
          if (action == 'playlist') {
            await _addToPlaylist(context, controller, track);
          }
          if (action == 'download') controller.downloads.enqueue(track);
          if (action == 'delete' &&
              context.mounted &&
              await _confirm(
                context,
                'Hapus unduhan?',
                'Lagu tetap ada di playlist dan dapat diunduh ulang.',
              )) {
            await controller.removeDownload(track.id);
          }
          if (action == 'remove' && playlistId != null) {
            await controller.guard(
              () =>
                  controller.library.removeFromPlaylist(playlistId!, track.id),
              success: 'Lagu dikeluarkan dari playlist.',
            );
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'playlist',
            child: Text('Tambahkan ke playlist'),
          ),
          if (!saved)
            const PopupMenuItem(
              value: 'download',
              child: Text('Unduh untuk offline'),
            ),
          if (saved)
            const PopupMenuItem(value: 'delete', child: Text('Hapus unduhan')),
          if (playlistId != null)
            const PopupMenuItem(
              value: 'remove',
              child: Text('Keluarkan dari playlist'),
            ),
        ],
      ),
    );
  }
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    ) ??
    false;

Future<String?> _playlistName(BuildContext context, {String? initial}) =>
    showDialog<String>(
      context: context,
      builder: (_) => PlaylistNameDialog(initial: initial),
    );

class PlaylistNameDialog extends StatefulWidget {
  const PlaylistNameDialog({this.initial, super.key});
  final String? initial;
  @override
  State<PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<PlaylistNameDialog> {
  late final TextEditingController input;
  final form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    input = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initial == null ? 'Buat playlist' : 'Ubah nama playlist',
    ),
    content: Form(
      key: form,
      child: TextFormField(
        controller: input,
        autofocus: true,
        maxLength: 80,
        decoration: const InputDecoration(
          hintText: 'Misalnya: Perjalanan sore',
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Nama playlist tidak boleh kosong.'
            : null,
        onFieldSubmitted: (_) {
          if (form.currentState!.validate()) {
            Navigator.pop(context, input.text.trim());
          }
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, input.text.trim());
          }
        },
        child: const Text('Simpan'),
      ),
    ],
  );
}

Future<String?> _newPlaylist(BuildContext context, AppController c) async {
  final name = await _playlistName(context);
  if (name == null) return null;
  String? id;
  await c.guard(() async {
    id = await c.library.createPlaylist(name);
  }, success: 'Playlist dibuat.');
  return id;
}

Future<void> _addToPlaylist(
  BuildContext context,
  AppController c,
  Track track,
) async {
  final id = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 4, 24, 16),
            child: Text(
              'Tambahkan ke playlist',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_rounded, color: accent),
            title: const Text('Buat playlist baru'),
            onTap: () => Navigator.pop(sheet, '__new__'),
          ),
          for (final playlist in c.library.playlists)
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: Text(playlist.name),
              subtitle: Text('${playlist.tracks.length} lagu'),
              onTap: () => Navigator.pop(sheet, playlist.id),
            ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
  if (id == null || !context.mounted) return;
  final target = id == '__new__' ? await _newPlaylist(context, c) : id;
  if (target != null) {
    await c.guard(
      () => c.library.addToPlaylist(target, track),
      success: 'Lagu tersimpan di playlist.',
    );
  }
}

class PlaylistPage extends StatelessWidget {
  const PlaylistPage({
    required this.controller,
    required this.playlistId,
    super.key,
  });
  final AppController controller;
  final String playlistId;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final matches = controller.library.playlists.where(
        (playlist) => playlist.id == playlistId,
      );
      if (matches.isEmpty) {
        return Scaffold(
          appBar: AppBar(title: const Text('Playlist dihapus')),
          body: const Center(child: Text('Playlist ini sudah tidak tersedia.')),
        );
      }
      final playlist = matches.first;
      return Scaffold(
        appBar: AppBar(
          title: Text(playlist.name),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Opsi playlist',
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Ubah nama')),
                PopupMenuItem(value: 'delete', child: Text('Hapus playlist')),
              ],
              onSelected: (action) async {
                if (action == 'rename') {
                  final name = await _playlistName(
                    context,
                    initial: playlist.name,
                  );
                  if (name != null) {
                    await controller.guard(
                      () => controller.library.renamePlaylist(playlistId, name),
                    );
                  }
                } else if (await _confirm(
                  context,
                  'Hapus playlist?',
                  'Unduhan lagunya akan tetap tersimpan.',
                )) {
                  await controller.guard(
                    () => controller.library.deletePlaylist(playlistId),
                  );
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF475E35), panel],
                        ),
                      ),
                      child: const Icon(
                        Icons.queue_music_rounded,
                        color: accent,
                        size: 86,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      playlist.name,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${playlist.tracks.length} lagu · Playlist pribadi',
                      style: const TextStyle(color: muted),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: playlist.tracks.isEmpty
                                ? null
                                : () => unawaited(
                                    controller.player.playTracks(
                                      playlist.tracks,
                                    ),
                                  ),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Putar semua'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton.filledTonal(
                          tooltip: 'Unduh semua lagu',
                          onPressed: playlist.tracks.isEmpty
                              ? null
                              : () {
                                  for (final track in playlist.tracks) {
                                    controller.downloads.enqueue(track);
                                  }
                                  controller.notices.add(
                                    'Lagu ditambahkan ke antrean unduhan.',
                                  );
                                },
                          icon: const Icon(Icons.download_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (playlist.tracks.isEmpty)
                      const EmptyState(
                        icon: Icons.music_note_rounded,
                        title: 'Masih ada ruang untuk lagu',
                        message:
                            'Tambahkan lagu lewat menu pada hasil pencarian.',
                      ),
                    for (int i = 0; i < playlist.tracks.length; i++)
                      TrackTile(
                        controller: controller,
                        track: playlist.tracks[i],
                        playlistId: playlistId,
                        onPlay: () => unawaited(
                          controller.player.playTracks(
                            playlist.tracks,
                            startIndex: i,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (controller.player.current != null)
                MiniPlayer(controller: controller),
            ],
          ),
        ),
      );
    },
  );
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final track = controller.player.current!;
    final state = controller.player.playbackState.value;
    final loading =
        state.processingState == AudioProcessingState.loading ||
        state.processingState == AudioProcessingState.buffering;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF293223),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 10, right: 4),
        leading: Artwork(track, size: 44, radius: 9),
        title: Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          state.errorMessage == null
              ? track.artist
              : 'Gagal diputar · ketuk untuk mencoba lagi',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: muted, fontSize: 11),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PlayerPage(controller: controller),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                tooltip: state.playing ? 'Jeda' : 'Putar',
                onPressed: () => unawaited(
                  state.playing
                      ? controller.player.pause()
                      : controller.player.play(),
                ),
                icon: Icon(
                  state.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 32,
                ),
              ),
            IconButton(
              tooltip: 'Lagu berikutnya',
              onPressed: () => unawaited(controller.player.skipToNext()),
              icon: const Icon(Icons.skip_next_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class PlayerPage extends StatelessWidget {
  const PlayerPage({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final player = controller.player;
      final track = player.current;
      if (track == null) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(
            child: Text('Pilih lagu untuk mulai mendengarkan.'),
          ),
        );
      }
      final state = player.playbackState.value;
      final loading =
          state.processingState == AudioProcessingState.loading ||
          state.processingState == AudioProcessingState.buffering;
      final duration = player.mediaItem.value?.duration ?? track.duration;
      final saved = controller.library.downloads.containsKey(track.id);
      final task = controller.downloads.tasks[track.id];
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Tutup pemutar',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          title: const Text(
            'SEDANG DIPUTAR',
            style: TextStyle(fontSize: 11, letterSpacing: 2, color: muted),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'Tambahkan ke playlist',
              onPressed: () => _addToPlaylist(context, controller, track),
              icon: const Icon(Icons.playlist_add_rounded),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, size) => Artwork(
                            track,
                            size: size.maxWidth.clamp(0, 360).toDouble(),
                            radius: 28,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          track.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          track.artist,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: muted, fontSize: 15),
                        ),
                        if (state.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              state.errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                              ),
                            ),
                          ),
                        const SizedBox(height: 22),
                        StreamBuilder<Duration>(
                          stream: player.positionStream,
                          initialData: player.position,
                          builder: (context, snapshot) {
                            final end = duration.inMilliseconds.toDouble();
                            final position = snapshot.data ?? Duration.zero;
                            return Column(
                              children: [
                                Slider(
                                  value: end <= 0
                                      ? 0
                                      : position.inMilliseconds
                                            .toDouble()
                                            .clamp(0, end),
                                  max: end <= 0 ? 1 : end,
                                  onChanged: loading || end <= 0
                                      ? null
                                      : (value) => unawaited(
                                          player.seek(
                                            Duration(
                                              milliseconds: value.round(),
                                            ),
                                          ),
                                        ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      formatDuration(position),
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      formatDuration(duration),
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              tooltip: player.shuffle
                                  ? 'Nonaktifkan acak'
                                  : 'Acak lagu',
                              color: player.shuffle ? accent : muted,
                              onPressed: () => unawaited(
                                player.setShuffleMode(
                                  player.shuffle
                                      ? AudioServiceShuffleMode.none
                                      : AudioServiceShuffleMode.all,
                                ),
                              ),
                              icon: const Icon(Icons.shuffle_rounded),
                            ),
                            IconButton(
                              tooltip: 'Lagu sebelumnya',
                              onPressed: () =>
                                  unawaited(player.skipToPrevious()),
                              icon: const Icon(
                                Icons.skip_previous_rounded,
                                size: 38,
                              ),
                            ),
                            SizedBox(
                              width: 76,
                              height: 76,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: const CircleBorder(),
                                ),
                                onPressed: loading
                                    ? null
                                    : () => unawaited(
                                        state.playing
                                            ? player.pause()
                                            : player.play(),
                                      ),
                                child: loading
                                    ? const SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(),
                                      )
                                    : Icon(
                                        state.playing
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        size: 42,
                                      ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Lagu berikutnya',
                              onPressed: () => unawaited(player.skipToNext()),
                              icon: const Icon(
                                Icons.skip_next_rounded,
                                size: 38,
                              ),
                            ),
                            IconButton(
                              tooltip:
                                  'Pengulangan: ${player.repeat == AudioServiceRepeatMode.none
                                      ? 'mati'
                                      : player.repeat == AudioServiceRepeatMode.all
                                      ? 'semua'
                                      : 'satu lagu'}',
                              color:
                                  player.repeat == AudioServiceRepeatMode.none
                                  ? muted
                                  : accent,
                              onPressed: () => unawaited(
                                player.setRepeatMode(switch (player.repeat) {
                                  AudioServiceRepeatMode.none =>
                                    AudioServiceRepeatMode.all,
                                  AudioServiceRepeatMode.all =>
                                    AudioServiceRepeatMode.one,
                                  _ => AudioServiceRepeatMode.none,
                                }),
                              ),
                              icon: Icon(
                                player.repeat == AudioServiceRepeatMode.one
                                    ? Icons.repeat_one_rounded
                                    : Icons.repeat_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: saved
                                  ? null
                                  : task != null &&
                                        task.status != DownloadStatus.failed
                                  ? () => controller.downloads.cancel(track.id)
                                  : () => controller.downloads.enqueue(track),
                              icon: Icon(
                                saved
                                    ? Icons.download_done_rounded
                                    : task != null &&
                                          task.status != DownloadStatus.failed
                                    ? Icons.close_rounded
                                    : Icons.download_rounded,
                              ),
                              label: Text(
                                saved
                                    ? 'Tersedia offline'
                                    : task != null &&
                                          task.status != DownloadStatus.failed
                                    ? 'Batalkan unduhan'
                                    : 'Unduh lagu',
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              tooltip: 'Lihat antrean',
                              onPressed: () => _showQueue(context, controller),
                              icon: const Icon(Icons.queue_music_rounded),
                            ),
                          ],
                        ),
                        if (task?.status == DownloadStatus.downloading)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: LinearProgressIndicator(
                              value: task!.progress,
                            ),
                          ),
                        if (task?.status == DownloadStatus.failed)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              task!.error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _showQueue(BuildContext context, AppController c) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: AnimatedBuilder(
          animation: c,
          builder: (context, _) => Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Antrean putar',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: c.player.tracks.length,
                  itemBuilder: (context, index) {
                    final track = c.player.tracks[index];
                    return ListTile(
                      leading: Artwork(track, size: 44),
                      title: Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: index == c.player.currentIndex ? accent : null,
                        ),
                      ),
                      subtitle: Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: index == c.player.currentIndex
                          ? const Icon(Icons.graphic_eq_rounded, color: accent)
                          : null,
                      onTap: () => unawaited(c.player.skipToQueueItem(index)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
