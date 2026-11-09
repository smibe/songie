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
}
