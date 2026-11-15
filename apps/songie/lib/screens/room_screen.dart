import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/firestore_room_repository.dart';
import '../data/song.dart';
import '../data/song_access.dart';
import '../data/song_repository.dart';
import '../data/songie_room.dart';
import '../settings/songie_settings.dart';
import 'song_screen.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({
    required this.roomCode,
    required this.roomRepository,
    required this.songRepository,
    required this.settings,
    required this.uid,
    required this.displayName,
    required this.email,
    super.key,
  });

  final String roomCode;
  final FirestoreRoomRepository roomRepository;
  final SongRepository songRepository;
  final SongieSettings settings;
  final String uid;
  final String displayName;
  final String email;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final Stream<SongieRoom?> _roomStream;
  late final Stream<List<SongieRoomParticipant>> _participantsStream;
  late final Stream<List<SongieSong>> _songsStream;
  bool _busy = false;
  bool _hasSeenInitialRoomSnapshot = false;
  String? _lastSuggestionKey;

  @override
  void initState() {
    super.initState();
    _roomStream = widget.roomRepository.watchRoom(widget.roomCode);
    _participantsStream =
        widget.roomRepository.watchParticipants(widget.roomCode);
    // All room participants can read published public and friend-circle songs.
    // Admin-only/private songs must never be suggested to a mixed group.
    _songsStream = widget.songRepository.watchPublishedSongs(
      access: SongCatalogAccess.friend,
    );
  }

  String get _invitationUrl => Uri(
        scheme: 'https',
        host: 'songie-prod.web.app',
        queryParameters: {'room': widget.roomCode},
      ).toString();

  Future<void> _showInvitation(SongieRoom room) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite people'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: _invitationUrl,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
              semanticsLabel: 'Invitation QR code for ${room.name}',
            ),
            const SizedBox(height: 12),
            const Text('Scan the QR code or enter this room code:'),
            const SizedBox(height: 8),
            SelectableText(
              room.id,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Only signed-in Songie friends and admins can join.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: room.id));
              if (!mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('Room code copied.')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy code'),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _invitationUrl));
              if (!mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('Invitation link copied.')),
              );
            },
            icon: const Icon(Icons.link),
            label: const Text('Copy link'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectSong(SongieRoom room, List<SongieSong> songs) async {
    if (!room.isOwner(widget.uid) || _busy) return;

    final searchController = TextEditingController();
    var query = '';
    final selectedSong = await showDialog<SongieSong>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final viewport = MediaQuery.sizeOf(context);
          final dialogWidth = viewport.width * 0.78;
          final dialogHeight =
              (viewport.height * 0.55).clamp(240.0, 480.0).toDouble();
          final filteredSongs = songs.where((song) {
            final searchText =
                '${song.title} ${song.artist}'.toLowerCase();
            return searchText.contains(query.trim().toLowerCase());
          }).toList(growable: false);

          return AlertDialog(
            title: const Text('Choose a song'),
            content: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    onChanged: (value) =>
                        setDialogState(() => query = value),
                    decoration: const InputDecoration(
                      hintText: 'Search title or artist',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filteredSongs.isEmpty
                        ? const Center(child: Text('No songs found.'))
                        : ListView.separated(
                            itemCount: filteredSongs.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final song = filteredSongs[index];
                              return ListTile(
                                title: Text(song.title),
                                subtitle: song.artist.isEmpty
                                    ? null
                                    : Text(song.artist),
                                onTap: () =>
                                    Navigator.of(dialogContext).pop(song),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
    searchController.dispose();
    if (selectedSong == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.roomRepository.selectSong(
        room: room,
        song: selectedSong,
        uid: widget.uid,
        displayName: widget.displayName,
      );
    } catch (error) {
      _showError('Could not suggest song: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSuggestedSong(
    SongieRoom room,
    List<SongieSong> songs,
  ) async {
    final songId = room.currentSongId;
    if (songId == null) return;

    SongieSong? song;
    for (final candidate in songs) {
      if (candidate.id == songId) {
        song = candidate;
        break;
      }
    }
    if (song == null) {
      _showError(
        'This song is no longer available to all members of the room.',
      );
      return;
    }
    final selectedSong = song;

    setState(() => _busy = true);
    try {
      await widget.roomRepository.markSongOpened(
        roomCode: room.id,
        uid: widget.uid,
        songId: songId,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SongScreen(
            song: selectedSong,
            settings: widget.settings,
          ),
        ),
      );
    } catch (error) {
      _showError('Could not open song: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leaveRoom(SongieRoom room) async {
    if (room.isOwner(widget.uid)) {
      _showError('As room owner, close the room instead of leaving it.');
      return;
    }

    final confirmed = await _confirm(
      title: 'Leave room?',
      message: 'You will leave "${room.name}".',
      action: 'Leave',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.roomRepository.leaveRoom(room: room, uid: widget.uid);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      _showError('Could not leave room: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _closeRoom(SongieRoom room) async {
    final confirmed = await _confirm(
      title: 'Close room?',
      message:
          'This ends "${room.name}" for everyone. Participants will no longer be able to open the room.',
      action: 'Close room',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.roomRepository.closeRoom(room, widget.uid);
    } catch (error) {
      _showError('Could not close room: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String action,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _observeSuggestedSong(SongieRoom room) {
    final suggestionKey = room.currentSongId == null
        ? null
        : '${room.currentSongId}:${room.selectedAt?.microsecondsSinceEpoch ?? 0}';

    if (!_hasSeenInitialRoomSnapshot) {
      _hasSeenInitialRoomSnapshot = true;
      _lastSuggestionKey = suggestionKey;
      return;
    }

    if (suggestionKey == _lastSuggestionKey) return;
    _lastSuggestionKey = suggestionKey;

    if (suggestionKey == null || room.selectedByUid == widget.uid) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isRoomVisible = ModalRoute.of(context)?.isCurrent ?? true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'New song suggested: ${room.currentSongTitle ?? 'Open the room to see it.'}',
          ),
          action: isRoomVisible
              ? null
              : SnackBarAction(
                  label: 'Back to room',
                  onPressed: () => Navigator.of(context).pop(),
                ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SongieRoom?>(
      stream: _roomStream,
      builder: (context, roomSnapshot) {
        if (roomSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Room')),
            body: Center(child: Text('Could not load room: ${roomSnapshot.error}')),
          );
        }
        if (!roomSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Room')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final room = roomSnapshot.data;
        if (room != null) _observeSuggestedSong(room);
        if (room == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Room')),
            body: const Center(child: Text('This room no longer exists.')),
          );
        }

        if (!room.isActive) {
          return Scaffold(
            appBar: AppBar(title: Text(room.name)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.meeting_room_outlined, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'This room has been closed.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Back to rooms'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(room.name),
            actions: [
              IconButton(
                tooltip: 'Invite people',
                onPressed: () => _showInvitation(room),
                icon: const Icon(Icons.qr_code_2),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: StreamBuilder<List<SongieRoomParticipant>>(
            stream: _participantsStream,
            builder: (context, participantSnapshot) {
              if (participantSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Could not load participants: ${participantSnapshot.error}',
                  ),
                );
              }
              if (!participantSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final participants = participantSnapshot.data!;
              return StreamBuilder<List<SongieSong>>(
                stream: _songsStream,
                builder: (context, songSnapshot) {
                  if (songSnapshot.hasError) {
                    return Center(
                      child: Text('Could not load songs: ${songSnapshot.error}'),
                    );
                  }
                  if (!songSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final songs = songSnapshot.data!;
                  SongieSong? currentSong;
                  for (final song in songs) {
                    if (song.id == room.currentSongId) {
                      currentSong = song;
                      break;
                    }
                  }
                  final openedCount = participants
                      .where(
                        (participant) => participant.hasOpened(
                          room.currentSongId,
                          room.selectedAt,
                        ),
                      )
                      .length;

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.vpn_key_outlined),
                                  const SizedBox(width: 8),
                                  const Text('Room code'),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: () => _showInvitation(room),
                                    icon: const Icon(Icons.qr_code_2),
                                    label: const Text('Invite'),
                                  ),
                                ],
                              ),
                              SelectableText(
                                room.id,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      letterSpacing: 4,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Room owner: ${room.ownerName}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'Current song',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          if (room.isOwner(widget.uid))
                            TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _selectSong(room, songs),
                              icon: const Icon(Icons.library_music_outlined),
                              label: Text(
                                room.currentSongId == null
                                    ? 'Choose song'
                                    : 'Change song',
                              ),
                            ),
                        ],
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: currentSong == null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.music_note, size: 32),
                                    const SizedBox(height: 8),
                                    Text(
                                      room.currentSongId == null
                                          ? 'No song selected yet'
                                          : (room.currentSongTitle ??
                                              'Song unavailable'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      room.isOwner(widget.uid)
                                          ? 'Choose a song from the shared catalog for everyone in the room.'
                                          : 'The room owner has not selected a song yet.',
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentSong.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    if (currentSong.artist.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(currentSong.artist),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                      'Suggested by ${room.selectedByName ?? room.ownerName}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 12),
                                    FilledButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _openSuggestedSong(room, songs),
                                      icon: const Icon(Icons.open_in_new),
                                      label: const Text('Open song'),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '$openedCount of ${participants.length} '
                                      'participants opened this song',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Text(
                            'Participants',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${participants.length}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Column(
                          children: [
                            for (var index = 0;
                                index < participants.length;
                                index++) ...[
                              if (index > 0) const Divider(height: 1),
                              _ParticipantTile(
                                participant: participants[index],
                                currentSongId: room.currentSongId,
                                selectedAt: room.selectedAt,
                                isOwner: room.ownerUid ==
                                    participants[index].uid,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_busy) const LinearProgressIndicator(),
                      if (room.isOwner(widget.uid))
                        OutlinedButton.icon(
                          onPressed: _busy ? null : () => _closeRoom(room),
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('Close room for everyone'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error,
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: _busy ? null : () => _leaveRoom(room),
                          icon: const Icon(Icons.exit_to_app),
                          label: const Text('Leave room'),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.participant,
    required this.currentSongId,
    required this.selectedAt,
    required this.isOwner,
  });

  final SongieRoomParticipant participant;
  final String? currentSongId;
  final DateTime? selectedAt;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final opened = participant.hasOpened(currentSongId, selectedAt);
    final name = participant.displayName.trim().isEmpty
        ? participant.email
        : participant.displayName;

    return ListTile(
      leading: CircleAvatar(
        child: Text(
          name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
        ),
      ),
      title: Text(name),
      subtitle: isOwner ? const Text('Room owner') : null,
      trailing: currentSongId == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  opened ? Icons.check_circle : Icons.schedule,
                  size: 18,
                  color: opened ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(opened ? 'Ready' : 'Waiting'),
              ],
            ),
    );
  }
}
