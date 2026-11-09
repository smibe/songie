import 'models.dart';

/// Parses the practical ChordPro subset needed by Songie's first milestone.
///
/// Supported features include common metadata directives, chord markers,
/// verse/chorus/bridge/tab sections, and comment directives. Unknown
/// directives are retained as non-fatal warnings rather than aborting.
class ChordProParser {
  const ChordProParser();

  static const _metadataAliases = <String, String>{
    't': 'title',
    'title': 'title',
    'st': 'subtitle',
    'subtitle': 'subtitle',
    'a': 'artist',
    'artist': 'artist',
    'composer': 'composer',
    'lyricist': 'lyricist',
    'key': 'key',
    'capo': 'capo',
    'tempo': 'tempo',
    'time': 'time',
    'duration': 'duration',
    'album': 'album',
    'year': 'year',
    'copyright': 'copyright',
  };

  ChordProSong parse(String source) {
    final metadata = <String, String>{};
    final warnings = <String>[];
    final sections = <SongSection>[];
    var currentKind = SongSectionKind.verse;
    String? currentLabel;
    var currentLines = <SongLine>[];

    void finishSection() {
      if (currentLines.isNotEmpty) {
        sections.add(SongSection(
          kind: currentKind,
          label: currentLabel,
          lines: currentLines,
        ));
      }
      currentLines = <SongLine>[];
    }

    void beginSection(SongSectionKind kind, [String? label]) {
      finishSection();
      currentKind = kind;
      currentLabel = label == null || label.trim().isEmpty
          ? null
          : label.trim();
    }

    final lines = source.split(RegExp(r'\r\n|\n|\r'));
    var firstLine = 0;
    var lastLine = lines.length;
    // Ignore framing whitespace commonly introduced by multiline literals
    // and text editors, but preserve blank lines inside the song.
    while (firstLine < lastLine && lines[firstLine].trim().isEmpty) {
      firstLine++;
    }
    while (lastLine > firstLine && lines[lastLine - 1].trim().isEmpty) {
      lastLine--;
    }

    for (var lineIndex = firstLine; lineIndex < lastLine; lineIndex++) {
      final rawLine = lines[lineIndex];
      final directiveMatch =
          RegExp(r'^\s*\{([^{}]+)\}\s*$').firstMatch(rawLine);

      if (directiveMatch != null) {
        final directive = directiveMatch.group(1)!.trim();
        final separator = directive.indexOf(':');
        final rawName = (separator < 0
                ? directive
                : directive.substring(0, separator))
            .trim()
            .toLowerCase();
        final value = separator < 0
            ? ''
            : directive.substring(separator + 1).trim();
        final lineNumber = lineIndex + 1;

        final metadataKey = _metadataAliases[rawName];
        if (metadataKey != null) {
          metadata[metadataKey] = value;
          continue;
        }

        switch (rawName) {
          case 'start_of_chorus':
          case 'soc':
            beginSection(SongSectionKind.chorus, value);
            break;
          case 'start_of_verse':
          case 'sov':
            beginSection(SongSectionKind.verse, value);
            break;
          case 'start_of_bridge':
          case 'sob':
            beginSection(SongSectionKind.bridge, value);
            break;
          case 'start_of_tab':
          case 'sot':
            beginSection(SongSectionKind.tab, value);
            break;
          case 'end_of_chorus':
          case 'eoc':
          case 'end_of_verse':
          case 'eov':
          case 'end_of_bridge':
          case 'eob':
          case 'end_of_tab':
          case 'eot':
            beginSection(SongSectionKind.verse);
            break;
          case 'comment':
          case 'c':
          case 'comment_italic':
            currentLines.add(SongLine(
              text: value,
              chords: const [],
              isComment: true,
            ));
            break;
          case 'new_page':
          case 'column_break':
          case 'chorus':
          case 'sortorder':
            // Layout and display hints are intentionally ignored by the
            // first renderer; they are valid and should not be warnings.
            break;
          default:
            warnings.add(
              'Unsupported directive {$directive} at line $lineNumber.',
            );
        }
        continue;
      }

      currentLines.add(_parseLyricLine(rawLine));
    }

    finishSection();
    return ChordProSong(
      metadata: metadata,
      sections: sections,
      warnings: warnings,
      source: source,
    );
  }

  SongLine _parseLyricLine(String sourceLine) {
    final text = StringBuffer();
    final chords = <ChordPlacement>[];
    final chordPattern = RegExp(r'\[([^\[\]]+)\]');
    var sourceOffset = 0;
    var textOffset = 0;

    for (final match in chordPattern.allMatches(sourceLine)) {
      final symbol = match.group(1)!.trim();
      if (symbol.isEmpty) continue;

      final prefix = sourceLine.substring(sourceOffset, match.start);
      text.write(prefix);
      textOffset += prefix.length;
      chords.add(ChordPlacement(symbol: symbol, position: textOffset));
      sourceOffset = match.end;
    }

    final suffix = sourceLine.substring(sourceOffset);
    text.write(suffix);
    return SongLine(text: text.toString(), chords: chords);
  }
}
