import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auth/songie_auth_service.dart';
import '../data/firestore_room_repository.dart';
import '../data/membership_repository.dart';
import '../data/song.dart';
import '../data/song_access.dart';
import '../data/song_repository.dart';
import '../settings/songie_settings.dart';
import 'member_management_screen.dart';
import 'profile_setup_screen.dart';
import 'rooms_screen.dart';
import 'settings_screen.dart';
import 'sign_in_screen.dart';
import 'song_import_screen.dart';
import 'song_reader_content.dart';
import 'song_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.settings,
    required this.authService,
    required this.songRepository,
    required this.membershipRepository,
    required this.roomRepository,
    super.key,
  });

  final SongieSettings settings;
  final SongieAuthService authService;
  final SongRepository songRepository;
  final FirestoreMembershipRepository membershipRepository;
  final FirestoreRoomRepository roomRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Stream<List<SongieSong>> _songsStream;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<SongieMembership?>? _membershipSubscription;

  User? _user;
  SongieMembership? _membership;
  bool _membershipLoading = false;
  String? _membershipError;
  SongCatalogAccess _catalogAccess = SongCatalogAccess.public;
  String? _selectedSongId;
  String? _pendingRoomCode;
  bool _pendingRoomNavigationStarted = false;

  @override
  void initState() {
    super.initState();
    _pendingRoomCode = kIsWeb ? Uri.base.queryParameters['room'] : null;
    unawaited(_loadPendingRoomCode());
    _songsStream = widget.songRepository.watchPublishedSongs(
      access: SongCatalogAccess.public,
    );
    _authSubscription = widget.authService.authStateChanges.listen(
      _onAuthStateChanged,
    );
  }

  void _setCatalogAccess(SongCatalogAccess access) {
    if (_catalogAccess == access) return;
    _catalogAccess = access;
    _songsStream = widget.songRepository.watchPublishedSongs(access: access);
    _selectedSongId = null;
  }

  void _onAuthStateChanged(User? user) {
    unawaited(_membershipSubscription?.cancel());
    if (!mounted) return;

    setState(() {
      _user = user;
      _membership = null;
      _membershipLoading = user != null;
      _membershipError = null;
      _setCatalogAccess(SongCatalogAccess.public);
    });

    if (user == null) return;

    _membershipSubscription = widget.membershipRepository
        .watchMembership(user.uid)
        .listen(
      (membership) {
        if (!mounted) return;
        setState(() {
          _membership = membership;
          _membershipLoading = false;
          _membershipError = null;
          _setCatalogAccess(
            membership?.catalogAccess ?? SongCatalogAccess.public,
          );
        });
        _openPendingRoomIfReady(membership);
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _membershipError = error.toString();
          _membershipLoading = false;
          _setCatalogAccess(SongCatalogAccess.public);
        });
      },
    );
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    unawaited(_membershipSubscription?.cancel());
    super.dispose();
  }

  void _subscribeToCatalog() {
    _songsStream = widget.songRepository.watchPublishedSongs(
      access: _catalogAccess,
    );
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

  Future<void> _openSongImport() async {
    if (_membership?.catalogAccess != SongCatalogAccess.admin) return;

    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SongImportScreen(
          settings: widget.settings,
          songRepository: widget.songRepository,
        ),
      ),
    );

    if (imported == true && mounted) {
      setState(_subscribeToCatalog);
    }
  }

  void _openSignIn() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SignInScreen(authService: widget.authService),
      ),
    );
  }

  bool get _canJoinRooms =>
      _user != null &&
      _membership?.active == true &&
      (_membership?.role == SongieMemberRole.friend ||
          _membership?.role == SongieMemberRole.admin) &&
      _membership!.displayName.trim().isNotEmpty;

  Future<void> _loadPendingRoomCode() async {
    try {
      final savedCode = await widget.authService.loadPendingRoomCode();
      if (!mounted || savedCode == null || savedCode.trim().isEmpty) return;
      setState(() {
        _pendingRoomCode ??= savedCode;
      });
      _openPendingRoomIfReady(_membership);
    } catch (error) {
      debugPrint('Could not load saved room invitation: $error');
    }
  }

  void _openRooms({String? initialJoinCode}) {
    if (!_canJoinRooms || _user == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoomsScreen(
          roomRepository: widget.roomRepository,
          songRepository: widget.songRepository,
          settings: widget.settings,
          uid: _user!.uid,
          displayName: _membership!.displayName,
          email: _membership!.email,
          initialJoinCode: initialJoinCode,
          onInvitationJoined: widget.authService.clearPendingRoomCode,
        ),
      ),
    );
  }

  void _openPendingRoomIfReady(SongieMembership? membership) {
    final code = _pendingRoomCode;
    if (code == null ||
        code.trim().isEmpty ||
        _pendingRoomNavigationStarted ||
        membership == null ||
        !membership.active ||
        membership.role == SongieMemberRole.none ||
        membership.displayName.trim().isEmpty ||
        _user == null) {
      return;
    }

    _pendingRoomNavigationStarted = true;
    _pendingRoomCode = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openRooms(initialJoinCode: code);
    });
  }

  void _openMemberManagement() {
    if (_membership?.catalogAccess != SongCatalogAccess.admin ||
        _user == null) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemberManagementScreen(
          membershipRepository: widget.membershipRepository,
          currentUid: _user!.uid,
        ),
      ),
    );
  }

  bool get _needsProfileSetup =>
      _user != null &&
      !_membershipLoading &&
      _membershipError == null &&
      (_membership == null || _membership!.displayName.trim().isEmpty);

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

  Future<void> _handleAccountAction(String action) async {
    if (action == 'signOut') {
      await widget.authService.signOut();
    }
  }

  Widget _buildAccountAction() {
    if (_user == null) {
      if (!kIsWeb) return const SizedBox.shrink();
      return TextButton.icon(
        onPressed: _openSignIn,
        icon: const Icon(Icons.login),
        label: const Text('Sign in'),
      );
    }

    final accountLabel = _membershipLoading
        ? 'Checking access…'
        : switch (_membership?.catalogAccess) {
            SongCatalogAccess.admin => 'Administrator',
            SongCatalogAccess.friend => 'Friend',
            _ => 'No catalog access',
          };

    return PopupMenuButton<String>(
      tooltip: _user!.email ?? 'Account',
      onSelected: _handleAccountAction,
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_membership?.displayName.isNotEmpty == true)
                Text(
                  _membership!.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              Text(_user!.email ?? 'Signed in'),
              const SizedBox(height: 4),
              Text(
                accountLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'signOut',
          child: Text('Sign out'),
        ),
      ],
      icon: const Icon(Icons.account_circle_outlined),
    );
  }

  Widget? _buildRoomInviteNotice() {
    if (_pendingRoomCode == null ||
        _pendingRoomCode!.trim().isEmpty ||
        _user != null) {
      return null;
    }

    return Material(
      color: const Color(0xFFF1F1F1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.groups_outlined),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'You have a Songie room invitation. Sign in to join the room.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildMembershipNotice() {
    if (_user == null || _membershipLoading) return null;
    if (_membership?.active == true &&
        _membership?.role != SongieMemberRole.none) {
      return null;
    }

    final message = _membershipError == null
        ? (_pendingRoomCode != null
            ? 'You have a room invitation, but this account has no room access yet. Ask an administrator to assign Friend or Admin; the invitation will be kept.'
            : 'Your account has no Songie catalog access yet. An administrator can assign the role Friend or Admin.')
        : 'Could not check Songie membership: $_membershipError';

    return Material(
      color: const Color(0xFFF1F1F1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Songie'),
        actions: [
          _buildAccountAction(),
          if (_canJoinRooms)
            IconButton(
              tooltip: 'Singing rooms',
              onPressed: _openRooms,
              icon: const Icon(Icons.groups_outlined),
            ),
          if (_membership?.catalogAccess == SongCatalogAccess.admin)
            PopupMenuButton<String>(
              tooltip: 'Admin tools',
              onSelected: (action) {
                if (action == 'import') {
                  unawaited(_openSongImport());
                } else if (action == 'members') {
                  _openMemberManagement();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'import',
                  child: Row(
                    children: [
                      Icon(Icons.library_add_outlined),
                      SizedBox(width: 12),
                      Text('Import song'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'members',
                  child: Row(
                    children: [
                      Icon(Icons.manage_accounts_outlined),
                      SizedBox(width: 12),
                      Text('Manage users'),
                    ],
                  ),
                ),
              ],
              icon: const Icon(Icons.more_vert),
            ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _needsProfileSetup
          ? ProfileSetupScreen(
              uid: _user!.uid,
              email: _user!.email ?? '',
              initialName: _membership?.displayName ?? '',
              membershipRepository: widget.membershipRepository,
            )
          : Column(
              children: [
                if (_buildRoomInviteNotice() case final notice?) notice,
                if (_buildMembershipNotice() case final notice?) notice,
                Expanded(
                  child: StreamBuilder<List<SongieSong>>(
                    stream: _songsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _CatalogErrorView(
                          error: snapshot.error,
                          onRetry: _retryCatalog,
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
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

                          SongieSong? selectedSong;
                          for (final song in songs) {
                            if (song.id == _selectedSongId) {
                              selectedSong = song;
                              break;
                            }
                          }
                          selectedSong ??= songs.isEmpty ? null : songs.first;
                          final songForDisplay = selectedSong;

                          return Row(
                            children: [
                              SizedBox(
                                width: 340,
                                child: SongLibraryPane(
                                  songs: songs,
                                  selectedSongId: songForDisplay?.id,
                                  onSelected: (song) =>
                                      _selectSong(song, wideLayout: true),
                                ),
                              ),
                              const VerticalDivider(width: 1, thickness: 1),
                              Expanded(
                                child: songForDisplay == null
                                    ? const Center(
                                        child: Text('No songs available'),
                                      )
                                    : Column(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              28,
                                              12,
                                              20,
                                              12,
                                            ),
                                            child: Row(
                                              children: [
                                                const Spacer(),
                                                TextButton(
                                                  onPressed: () =>
                                                      _openPerformanceMode(
                                                        songForDisplay,
                                                      ),
                                                  child: const Text(
                                                    'Full screen',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Divider(height: 1),
                                          Expanded(
                                            child: SongReaderContent(
                                              song: songForDisplay,
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
                ),
              ],
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
