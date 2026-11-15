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
  Future<void> createSong({
    required String title,
    required String artist,
    required String key,
    required String chordPro,
    required bool published,
    required SongVisibility visibility,
  }) async {
    final normalizedTitle = title.trim().toLowerCase().replaceAll(
      RegExp(r'\\s+'),
      ' ',
    );
    final documentId = normalizedTitle
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+
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

    return query.orderBy('titleSearch')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((document) {
              return SongieSong.fromFirestore(
                id: document.id,
                data: document.data(),
              );
            }).toList(growable: false));
  }
}
), '');

    if (documentId.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Song title cannot create a valid document ID.');
    }
    if (chordPro.trim().isEmpty) {
      throw ArgumentError.value(chordPro, 'chordPro', 'Song source cannot be empty.');
    }

    final now = FieldValue.serverTimestamp();
    await _firestore.collection(collectionName).doc(documentId).create({
      'title': title.trim(),
      'artist': artist.trim(),
      'key': key.trim(),
      'chordPro': chordPro,
      'titleSearch': normalizedTitle,
      'published': published,
      'visibility': visibility.firestoreValue,
      'schemaVersion': 1,
      'createdAt': now,
      'updatedAt': now,
    });
  }

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

    return query.orderBy('titleSearch')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((document) {
              return SongieSong.fromFirestore(
                id: document.id,
                data: document.data(),
              );
            }).toList(growable: false));
  }
}
