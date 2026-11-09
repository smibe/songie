import 'package:flutter_test/flutter_test.dart';
import 'package:songie/data/song_access.dart';

void main() {
  group('SongVisibility', () {
    test('parses supported visibility values', () {
      expect(SongVisibility.fromValue('public'), SongVisibility.public);
      expect(SongVisibility.fromValue('friends'), SongVisibility.friends);
      expect(SongVisibility.fromValue('private'), SongVisibility.private);
    });

    test('treats legacy or invalid values as friend-only', () {
      expect(SongVisibility.fromValue(null), SongVisibility.friends);
      expect(SongVisibility.fromValue('unknown'), SongVisibility.friends);
    });
  });

  group('SongieMembership', () {
    test('active friend gets friend catalog access', () {
      final member = SongieMembership.fromFirestore(
        uid: 'friend-1',
        data: {
          'email': 'friend@example.com',
          'role': 'friend',
          'active': true,
        },
      );

      expect(member.catalogAccess, SongCatalogAccess.friend);
    });

    test('active admin gets admin catalog access', () {
      final member = SongieMembership.fromFirestore(
        uid: 'admin-1',
        data: {
          'email': 'admin@example.com',
          'role': 'admin',
          'active': true,
        },
      );

      expect(member.catalogAccess, SongCatalogAccess.admin);
    });

    test('inactive or unknown membership gets public access only', () {
      final inactive = SongieMembership.fromFirestore(
        uid: 'friend-1',
        data: {
          'role': 'friend',
          'active': false,
        },
      );
      final unknown = SongieMembership.fromFirestore(
        uid: 'user-1',
        data: {
          'role': 'unexpected',
          'active': true,
        },
      );

      expect(inactive.catalogAccess, SongCatalogAccess.public);
      expect(unknown.catalogAccess, SongCatalogAccess.public);
    });
  });
}
