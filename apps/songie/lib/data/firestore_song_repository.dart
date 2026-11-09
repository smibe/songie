import 'package:cloud_firestore/cloud_firestore.dart';

import 'song.dart';
import 'song_repository.dart';

/// Firestore-backed implementation of the public shared song catalog.
class FirestoreSongRepository implements SongRepository {
  FirestoreSongRepository(this._firestore);

  static const collectionName = 'songs';

  final FirebaseFirestore _firestore;

  @override
  Stream<List<SongieSong>> watchPublishedSongs() {
    return _firestore
        .collection(collectionName)
        .where('published', isEqualTo: true)
        .orderBy('titleSearch')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((document) {
              return SongieSong.fromFirestore(
                id: document.id,
                data: document.data(),
              );
            }).toList(growable: false));
  }
}
