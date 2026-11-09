/// Effective access level used to choose a Firestore song query.
enum SongCatalogAccess {
  public,
  friend,
  admin,
}

/// Visibility stored with each song document.
enum SongVisibility {
  public,
  friends,
  private;

  static SongVisibility fromValue(Object? value) {
    return switch (value) {
      'public' => SongVisibility.public,
      'private' => SongVisibility.private,
      'friends' => SongVisibility.friends,
      // Songs created before visibility was introduced are limited to
      // the invited circle until they are explicitly reviewed.
      _ => SongVisibility.friends,
    };
  }

  String get firestoreValue => name;
}

enum SongieMemberRole {
  friend,
  admin;

  static SongieMemberRole? fromValue(Object? value) {
    return switch (value) {
      'friend' => SongieMemberRole.friend,
      'admin' => SongieMemberRole.admin,
      _ => null,
    };
  }
}

/// A server-managed membership entry for the current Firebase user.
class SongieMembership {
  const SongieMembership({
    required this.uid,
    required this.email,
    required this.role,
    required this.active,
  });

  factory SongieMembership.fromFirestore({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    return SongieMembership(
      uid: uid,
      email: data['email'] is String ? data['email'] as String : '',
      role: SongieMemberRole.fromValue(data['role']),
      active: data['active'] == true,
    );
  }

  final String uid;
  final String email;
  final SongieMemberRole? role;
  final bool active;

  SongCatalogAccess get catalogAccess {
    if (!active) return SongCatalogAccess.public;
    return switch (role) {
      SongieMemberRole.admin => SongCatalogAccess.admin,
      SongieMemberRole.friend => SongCatalogAccess.friend,
      null => SongCatalogAccess.public,
    };
  }
}
