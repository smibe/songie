import 'package:chordpro/chordpro.dart';

/// A song in the shared Songie catalog.
class SongieSong {
  const SongieSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.key,
    required this.source,
    required this.document,
  });

  factory SongieSong.fromChordPro({
    required String id,
    required String source,
  }) {
    final document = const ChordProParser().parse(source);
    return SongieSong(
      id: id,
      title: document.title ?? 'Untitled song',
      artist: document.artist ?? '',
      key: document.key ?? '',
      source: source,
      document: document,
    );
  }

  factory SongieSong.fromFirestore({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final source = data['chordPro'];
    if (source is! String || source.trim().isEmpty) {
      throw FormatException('Song $id has no valid chordPro source.');
    }

    final parsed = const ChordProParser().parse(source);
    final title = data['title'];
    final artist = data['artist'];
    final key = data['key'];

    return SongieSong(
      id: id,
      title: title is String && title.trim().isNotEmpty
          ? title.trim()
          : parsed.title ?? 'Untitled song',
      artist: artist is String ? artist : parsed.artist ?? '',
      key: key is String ? key : parsed.key ?? '',
      source: source,
      document: parsed,
    );
  }

  final String id;
  final String title;
  final String artist;
  final String key;

  /// Original ChordPro source; never rewrite it just to change display settings.
  final String source;

  /// Parsed representation consumed by the song reader.
  final ChordProSong document;
}
