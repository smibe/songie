import 'package:flutter/material.dart';

import '../data/song.dart';
import '../data/song_repository.dart';
import '../settings/songie_settings.dart';
import 'settings_screen.dart';
import 'song_reader_content.dart';
import 'song_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.settings,
    required this.songRepository,
    super.key,
  });

  final SongieSettings settings;
  final SongRepository songRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Stream<List<SongieSong>> _songsStream;
  String? _selectedSongId;

  @override
  void initState() {
    super.initState();
    _subscribeToCatalog();
  }

  void _subscribeToCatalog() {
    _songsStream = widget.songRepository.watchPublishedSongs();
  }

  void _retryCatalog() {
    setState(_subscribeToCatalog);
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(settings: widget.settings),
      ),
    );
  }

  void _selectSong(SongieSong song, {required bool wideLayout}) {
    if (wideLayout) {
      setState(() => _selectedSongId = song.id);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SongScreen(song: song, settings: widget.settings),
      ),
    );
  }

  void _openPerformanceMode(SongieSong song) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PerformanceScreen(song: song, settings: widget.settings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Songie'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<SongieSong>>(
        stream: _songsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _CatalogErrorView(
              error: snapshot.error,
              onRetry: _retryCatalog,
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final songs = snapshot.data!;
          return LayoutBuilder(
            builder: (context, constraints) {
              final wideLayout = constraints.maxWidth >= 900;
              if (!wideLayout) {
                return SongLibraryPane(
                  songs: songs,
                  onSelected: (song) =>
                      _selectSong(song, wideLayout: false),
                );
              }

              final selectedSong = songs.cast<SongieSong?>().firstWhere(
                (song) => song?.id == _selectedSongId,
                orElse: () => songs.isEmpty ? null : songs.first,
              );

              return Row(
                children: [
                  SizedBox(
                    width: 340,
                    child: SongLibraryPane(
                      songs: songs,
                      selectedSongId: selectedSong?.id,
                      onSelected: (song) =>
                          _selectSong(song, wideLayout: true),
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: selectedSong == null
                        ? const Center(
                            child: Text('No published songs available'),
                          )
                        : Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  28, 12, 20, 12,
                                ),
                                child: Row(
                                  children: [
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () =>
                                          _openPerformanceMode(selectedSong),
                                      child: const Text('Full screen'),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: SongReaderContent(
                                  song: selectedSong,
                                  settings: widget.settings,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CatalogErrorView extends StatelessWidget {
  const _CatalogErrorView({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Could not load the song catalog.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Check your connection and Firestore security rules, then try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (error != null)
              SelectableText(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class SongLibraryPane extends StatefulWidget {
  const SongLibraryPane({
    required this.songs,
    required this.onSelected,
    this.selectedSongId,
    super.key,
  });

  final List<SongieSong> songs;
  final String? selectedSongId;
  final ValueChanged<SongieSong> onSelected;

  @override
  State<SongLibraryPane> createState() => _SongLibraryPaneState();
}

class _SongLibraryPaneState extends State<SongLibraryPane> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final songs = widget.songs.where((song) {
      return query.isEmpty ||
          '${song.title} ${song.artist}'.toLowerCase().contains(query);
    }).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Search songs',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.clear),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: songs.isEmpty
              ? Center(
                  child: Text(
                    widget.songs.isEmpty
                        ? 'No songs have been published yet.'
                        : 'No matching songs found.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  itemCount: songs.length,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    indent: 12,
                    endIndent: 12,
                  ),
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    final selected = song.id == widget.selectedSongId;
                    return ListTile(
                      selected: selected,
                      selectedTileColor: const Color(0xFFF0F0F0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      title: Text(
                        song.title,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: song.artist.isEmpty
                          ? null
                          : Text(song.artist),
                      onTap: () => widget.onSelected(song),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
