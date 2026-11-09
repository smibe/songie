import 'song.dart';

/// Source of the published, shared Songie song catalog.
abstract interface class SongRepository {
  /// Emits the currently published songs and subsequent catalog changes.
  Stream<List<SongieSong>> watchPublishedSongs();
}
