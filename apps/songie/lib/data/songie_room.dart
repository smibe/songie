/// A live Songie room used to coordinate a group singing session.
class SongieRoom {
  const SongieRoom({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.ownerName,
    required this.status,
    required this.participantUids,
    required this.currentSongId,
    required this.currentSongTitle,
    required this.currentSongArtist,
    required this.selectedByUid,
    required this.selectedByName,
  });

  factory SongieRoom.fromFirestore({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final participantValues = data['participantUids'];
    return SongieRoom(
      id: id,
      name: data['name'] is String ? data['name'] as String : 'Songie room',
      ownerUid: data['ownerUid'] is String ? data['ownerUid'] as String : '',
      ownerName: data['ownerName'] is String ? data['ownerName'] as String : '',
      status: data['status'] is String ? data['status'] as String : 'closed',
      participantUids: participantValues is List
          ? participantValues.whereType<String>().toList(growable: false)
          : const [],
      currentSongId: data['currentSongId'] is String
          ? data['currentSongId'] as String
          : null,
      currentSongTitle: data['currentSongTitle'] is String
          ? data['currentSongTitle'] as String
          : null,
      currentSongArtist: data['currentSongArtist'] is String
          ? data['currentSongArtist'] as String
          : null,
      selectedByUid: data['selectedByUid'] is String
          ? data['selectedByUid'] as String
          : null,
      selectedByName: data['selectedByName'] is String
          ? data['selectedByName'] as String
          : null,
    );
  }

  final String id;
  final String name;
  final String ownerUid;
  final String ownerName;
  final String status;
  final List<String> participantUids;
  final String? currentSongId;
  final String? currentSongTitle;
  final String? currentSongArtist;
  final String? selectedByUid;
  final String? selectedByName;

  bool get isActive => status == 'active';

  bool isOwner(String uid) => ownerUid == uid;
}

/// A participant's own room membership and acknowledgement state.
class SongieRoomParticipant {
  const SongieRoomParticipant({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    required this.openedSongId,
  });

  factory SongieRoomParticipant.fromFirestore({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    return SongieRoomParticipant(
      uid: uid,
      displayName: data['displayName'] is String
          ? data['displayName'] as String
          : '',
      email: data['email'] is String ? data['email'] as String : '',
      role: data['role'] is String ? data['role'] as String : 'member',
      openedSongId: data['openedSongId'] is String
          ? data['openedSongId'] as String
          : null,
    );
  }

  final String uid;
  final String displayName;
  final String email;
  final String role;
  final String? openedSongId;

  bool hasOpened(String? songId) =>
      songId != null && openedSongId == songId;
}
