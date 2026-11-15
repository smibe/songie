import 'package:flutter_test/flutter_test.dart';
import 'package:songie/data/songie_room.dart';

void main() {
  group('SongieRoom', () {
    test('parses an active room with its current song', () {
      final room = SongieRoom.fromFirestore(
        id: 'ABCD2345',
        data: {
          'name': 'Campfire songs',
          'ownerUid': 'owner-1',
          'ownerName': 'Alex',
          'status': 'active',
          'participantUids': ['owner-1', 'friend-1'],
          'currentSongId': 'morning-light',
          'currentSongTitle': 'Morning Light',
          'currentSongArtist': 'Songie Demo',
          'selectedByUid': 'owner-1',
          'selectedByName': 'Alex',
        },
      );

      expect(room.id, 'ABCD2345');
      expect(room.name, 'Campfire songs');
      expect(room.isActive, isTrue);
      expect(room.isOwner('owner-1'), isTrue);
      expect(room.isOwner('friend-1'), isFalse);
      expect(room.participantUids, ['owner-1', 'friend-1']);
      expect(room.currentSongId, 'morning-light');
      expect(room.currentSongTitle, 'Morning Light');
    });

    test('treats unknown room status as closed', () {
      final room = SongieRoom.fromFirestore(
        id: 'ABCD2345',
        data: {
          'name': 'Old room',
          'status': 'unexpected',
        },
      );

      expect(room.isActive, isFalse);
      expect(room.participantUids, isEmpty);
    });
  });

  group('SongieRoomParticipant', () {
    test('tracks whether a participant opened the current song', () {
      final participant = SongieRoomParticipant.fromFirestore(
        uid: 'friend-1',
        data: {
          'displayName': 'Sam',
          'email': 'sam@example.com',
          'role': 'member',
          'openedSongId': 'morning-light',
        },
      );

      expect(participant.displayName, 'Sam');
      expect(participant.hasOpened('morning-light'), isTrue);
      expect(participant.hasOpened('quiet-river'), isFalse);
      expect(participant.hasOpened(null), isFalse);
    });
  });
}
