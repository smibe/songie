import 'package:cloud_firestore/cloud_firestore.dart';

import 'song_access.dart';

class FirestoreMembershipRepository {
  FirestoreMembershipRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _members =>
      _firestore.collection('members');

  Stream<SongieMembership?> watchMembership(String uid) {
    return _members.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return SongieMembership.fromFirestore(
        uid: snapshot.id,
        data: snapshot.data()!,
      );
    });
  }

  Stream<List<SongieMembership>> watchMembers() {
    return _members.snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (document) => SongieMembership.fromFirestore(
              uid: document.id,
              data: document.data(),
            ),
          )
          .toList(growable: false);
    });
  }

  /// Creates a no-access profile for a new account or updates the user's
  /// own name and email without changing the role assigned by an admin.
  Future<void> saveOwnProfile({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    final normalizedName = displayName.trim();
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedName.length < 2 || normalizedName.length > 80) {
      throw const FormatException('Please enter a name between 2 and 80 characters.');
    }
    if (normalizedEmail.isEmpty) {
      throw const FormatException('The signed-in account has no email address.');
    }

    final reference = _members.doc(uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final timestamp = FieldValue.serverTimestamp();
      if (!snapshot.exists) {
        transaction.set(reference, {
          'email': normalizedEmail,
          'displayName': normalizedName,
          'role': SongieMemberRole.none.firestoreValue,
          'active': false,
          'createdAt': timestamp,
          'updatedAt': timestamp,
        });
      } else {
        transaction.update(reference, {
          'email': normalizedEmail,
          'displayName': normalizedName,
          'updatedAt': timestamp,
        });
      }
    });
  }

  /// Admin-only role change. The effective active flag follows the role.
  Future<void> setRole({
    required String uid,
    required SongieMemberRole role,
  }) {
    return _members.doc(uid).update({
      'role': role.firestoreValue,
      'active': role != SongieMemberRole.none,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
