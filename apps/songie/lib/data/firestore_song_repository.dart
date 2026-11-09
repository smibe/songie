import 'package:cloud_firestore/cloud_firestore.dart';

import 'song.dart';
import 'song_access.dart';
import 'song_repository.dart';

/// Firestore-backed implementation of the public shared song catalog.
class FirestoreSongRepository implements SongRepository {
  FirestoreSongRepository(this._firestore);

  static const collectionName = 'songs';

  final FirebaseFirestore _firestore;

  @override
  Stream<List<SongieSong>> watchPublishedSongs({
    required SongCatalogAccess access,
  }) {
    final visibleValues = switch (access) {
      SongCatalogAccess.public => const ['public'],
      SongCatalogAccess.friend => const ['public', 'friends'],
      SongCatalogAccess.admin => const ['public', 'friends', 'private'],
    };

    Query<Map<String, dynamic>> query = _firestore
        .collection(collectionName)
        .where('visibility', whereIn: visibleValues);

    if (access != SongCatalogAccess.admin) {
      query = query.where('published', isEqualTo: true);
    }

    return query
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
