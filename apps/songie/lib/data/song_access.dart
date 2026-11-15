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
  none,
  friend,
  admin;

  static SongieMemberRole fromValue(Object? value) {
    return switch (value) {
      'friend' => SongieMemberRole.friend,
      'admin' => SongieMemberRole.admin,
      _ => SongieMemberRole.none,
    };
  }

  String get firestoreValue => name;

  String get label => switch (this) {
    SongieMemberRole.none => 'Keine',
    SongieMemberRole.friend => 'Freund',
    SongieMemberRole.admin => 'Admin',
  };
}

/// A user profile with role and active access controlled by administrators.
class SongieMembership {
  const SongieMembership({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.active,
  });

  factory SongieMembership.fromFirestore({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    final active = data['active'] == true;
    return SongieMembership(
      uid: uid,
      email: data['email'] is String ? data['email'] as String : '',
      displayName: data['displayName'] is String
          ? data['displayName'] as String
          : '',
      // An inactive member is effectively assigned no access, even if an
      // older CLI record still contains role "friend" or "admin".
      role: active
          ? SongieMemberRole.fromValue(data['role'])
          : SongieMemberRole.none,
      active: active,
    );
  }

  final String uid;
  final String email;
  final String displayName;
  final SongieMemberRole role;
  final bool active;

  SongCatalogAccess get catalogAccess {
    if (!active) return SongCatalogAccess.public;
    return switch (role) {
      SongieMemberRole.admin => SongCatalogAccess.admin,
      SongieMemberRole.friend => SongCatalogAccess.friend,
      SongieMemberRole.none => SongCatalogAccess.public,
    };
  }
}
