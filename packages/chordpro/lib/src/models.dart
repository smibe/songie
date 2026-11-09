/// The broad musical role of a ChordPro section.
enum SongSectionKind { verse, chorus, bridge, tab, other }

/// A parsed ChordPro document.
class ChordProSong {
  ChordProSong({
    required Map<String, String> metadata,
    required List<SongSection> sections,
    required List<String> warnings,
    required this.source,
  })  : metadata = Map.unmodifiable(metadata),
        sections = List.unmodifiable(sections),
        warnings = List.unmodifiable(warnings);

  /// Normalized metadata keys, for example `title`, `artist`, and `key`.
  final Map<String, String> metadata;

  /// Sections in document order.
  final List<SongSection> sections;

  /// Non-fatal issues encountered while parsing unsupported directives.
  final List<String> warnings;

  /// The original, unmodified ChordPro source.
  final String source;

  String? get title => metadata['title'];
  String? get artist => metadata['artist'];
  String? get key => metadata['key'];
}

/// A contiguous verse, chorus, bridge, tab, or other section.
class SongSection {
  SongSection({
    required this.kind,
    required this.lines,
    this.label,
  }) : lines = List.unmodifiable(lines);

  final SongSectionKind kind;
  final String? label;
  final List<SongLine> lines;
}

/// A line of lyrics (or a comment directive) with chord anchors.
class SongLine {
  SongLine({
    required this.text,
    required List<ChordPlacement> chords,
    this.isComment = false,
  }) : chords = List.unmodifiable(chords);

  final String text;

  /// Chords positioned at offsets in [text], measured in UTF-16 code units.
  /// This matches Dart's String indexing and can be converted to rendered
  /// pixel positions by measuring the corresponding text prefix.
  final List<ChordPlacement> chords;

  /// True for `{comment: ...}` and `{comment_italic: ...}` directives.
  final bool isComment;
}

/// A chord symbol anchored at a character offset in a [SongLine].
class ChordPlacement {
  const ChordPlacement({required this.symbol, required this.position});

  final String symbol;
  final int position;
}
