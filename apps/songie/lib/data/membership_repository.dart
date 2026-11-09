import 'package:cloud_firestore/cloud_firestore.dart';

import 'song_access.dart';

class FirestoreMembershipRepository {
  FirestoreMembershipRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<SongieMembership?> watchMembership(String uid) {
    return _firestore.collection('members').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return SongieMembership.fromFirestore(
        uid: snapshot.id,
        data: snapshot.data()!,
      );
    });
  }
}
