import 'package:flutter/material.dart';

import '../data/firestore_room_repository.dart';
import '../data/song_repository.dart';
import '../settings/songie_settings.dart';
import 'room_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({
    required this.roomRepository,
    required this.songRepository,
    required this.settings,
    required this.uid,
    required this.displayName,
    required this.email,
    this.initialJoinCode,
    super.key,
  });

  final FirestoreRoomRepository roomRepository;
  final SongRepository songRepository;
  final SongieSettings settings;
  final String uid;
  final String displayName;
  final String email;
  final String? initialJoinCode;

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  late final Stream _roomsStream;
  bool _busy = false;
  bool _initialCodeHandled = false;

  @override
  void initState() {
    super.initState();
    _roomsStream = widget.roomRepository.watchMyRooms(widget.uid);
    final code = widget.initialJoinCode?.trim();
    if (code != null && code.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _initialCodeHandled) return;
        _initialCodeHandled = true;
        _joinRoom(code);
      });
    }
  }

  Future<void> _createRoom() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create a room'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Room name',
            hintText: 'e.g. Campfire songs',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) =>
              Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      final code = await widget.roomRepository.createRoom(
        name: name,
        uid: widget.uid,
        displayName: widget.displayName,
        email: widget.email,
      );
      if (!mounted) return;
      await _openRoom(code);
    } catch (error) {
      _showError('Could not create room: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showJoinDialog() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join a room'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 8,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Invitation code',
            hintText: '8 characters',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || !mounted) return;
    await _joinRoom(code);
  }

  Future<void> _joinRoom(String code) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.roomRepository.joinRoom(
        roomCode: code,
        uid: widget.uid,
        displayName: widget.displayName,
        email: widget.email,
      );
      if (!mounted) return;
      await _openRoom(code.trim().toUpperCase());
    } catch (error) {
      _showError('Could not join room: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openRoom(String code) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RoomScreen(
          roomCode: code,
          roomRepository: widget.roomRepository,
          songRepository: widget.songRepository,
          settings: widget.settings,
          uid: widget.uid,
          displayName: widget.displayName,
          email: widget.email,
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Singing rooms')),
      body: StreamBuilder(
        stream: _roomsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load rooms: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rooms = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Sing together',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a room for your group or join one with an invitation code. The room owner chooses the next song; everyone opens it on their own device.',
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _createRoom,
                icon: const Icon(Icons.add),
                label: const Text('Create room'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _showJoinDialog,
                icon: const Icon(Icons.login),
                label: const Text('Join with code'),
              ),
              if (_busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 28),
              Text(
                'My rooms',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (rooms.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'You are not in an active room yet.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                for (final room in rooms)
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.groups_outlined),
                      ),
                      title: Text(room.name),
                      subtitle: Text(
                        '${room.participantUids.length} participants'
                        '${room.currentSongTitle == null ? '' : ' · ${room.currentSongTitle}'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openRoom(room.id),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
