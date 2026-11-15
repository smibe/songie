import 'song.dart';
import 'song_access.dart';

/// Source of the published songs visible to the current access level.
abstract interface class SongRepository {
  /// Emits the songs the given access level is allowed to read.
  ///
  /// Firestore rules remain authoritative; this parameter only selects a
  /// query whose filters satisfy those rules.
  Stream<List<SongieSong>> watchPublishedSongs({
    required SongCatalogAccess access,
  });

  /// Creates a new song in the shared catalog. Firestore rules restrict this
  /// operation to active administrators.
  Future<void> createSong({
    required String title,
    required String artist,
    required String key,
    required String chordPro,
    required bool published,
    required SongVisibility visibility,
  });
}
