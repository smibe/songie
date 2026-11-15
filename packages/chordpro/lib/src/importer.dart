import 'models.dart';

/// The input syntax recognized by [SongSourceImporter].
enum SongSourceFormat { chordPro, alignedText }

/// A normalized song source ready for parsing and storage as ChordPro.
class SongSourceImportResult {
  const SongSourceImportResult({
    required this.source,
    required this.format,
    required this.warnings,
  });

  final String source;
  final SongSourceFormat format;
  final List<String> warnings;
}

/// Detects supported song formats and converts aligned plain-text chord sheets
/// into ChordPro. The original ChordPro input is retained unchanged except
/// for a leading BOM and line-ending normalization.
class SongSourceImporter {
  SongSourceImporter();

  static final _titleDirective = RegExp(
    r'^\s*\{\s*(?:t|title)\s*:',
    caseSensitive: false,
    multiLine: true,
  );
  static final _sectionHeader = RegExp(r'^\s*\[([^\]]+)\]\s*$');
  static final _chordToken = RegExp(
    r'^[A-GH][#b]?(?:m|maj|min|sus|dim|aug)?[0-9]*(?:[#b][0-9]+)?(?:sus[0-9]+)?(?:/[A-GH][#b]?)?$|^N\.?C\.?$',
    caseSensitive: false,
  );
  static final _tabLine = RegExp(r'^\s*[eEADGB]\s*\|');

  SongSourceImportResult importSource(String input) {
    final normalized = input
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    if (normalized.trim().isEmpty) {
      throw const FormatException('The song text is empty.');
    }

    if (_titleDirective.hasMatch(normalized)) {
      return SongSourceImportResult(
        source: normalized,
        format: SongSourceFormat.chordPro,
        warnings: const [],
      );
    }

    return _convertAlignedText(normalized);
  }

  SongSourceImportResult _convertAlignedText(String source) {
    final lines = source
        .split('\n')
        .map((line) => line.replaceAll('\t', '    '))
        .toList(growable: false);
    final firstContentIndex =
        lines.indexWhere((line) => line.trim().isNotEmpty);
    if (firstContentIndex < 0) {
      throw const FormatException('The song text is empty.');
    }

    final header = lines[firstContentIndex].trim();
    final headerMatch =
        RegExp(r'^(.+?)\s+chords\s+by\s+(.+)$', caseSensitive: false)
            .firstMatch(header);
    if (headerMatch == null) {
      throw const FormatException(
        'Unsupported text format. Expected a first line like '
        '"Song Title Chords by Artist".',
      );
    }

    final title = _clean(headerMatch.group(1)!);
    final artist = _clean(headerMatch.group(2)!);
    final firstSectionIndex = _findFirstSection(lines, firstContentIndex + 1);
    if (firstSectionIndex < 0) {
      throw const FormatException(
        'No section heading found. Expected headings such as [Verse 1], '
        '[Chorus], [Refrain], or [Bridge].',
      );
    }

    final output = <String>[
      '{title: $title}',
      '{artist: $artist}',
    ];
    _appendHeaderMetadata(
      lines.sublist(firstContentIndex + 1, firstSectionIndex),
      output,
    );

    var pendingChords = <_AlignedChord>[];
    var inTabSection = false;

    for (var index = firstSectionIndex; index < lines.length; index++) {
      final line = lines[index];

      if (_isPageNumber(line)) continue;

      final sectionMatch = _sectionHeader.firstMatch(line);
      if (sectionMatch != null && _isKnownSection(sectionMatch.group(1)!)) {
        final label = _clean(sectionMatch.group(1)!);
        final kind = _sectionKind(lines, index, label);
        final directive = switch (kind) {
          SongSectionKind.chorus => 'start_of_chorus',
          SongSectionKind.bridge => 'start_of_bridge',
          SongSectionKind.tab => 'start_of_tab',
          _ => 'start_of_verse',
        };
        output.add('{$directive: $label}');
        pendingChords = [];
        inTabSection = kind == SongSectionKind.tab;
        continue;
      }

      if (line.trim().isEmpty) {
        output.add('');
        pendingChords = [];
        continue;
      }

      if (inTabSection) {
        output.add(line);
        continue;
      }

      if (_isChordRow(line)) {
        pendingChords.addAll(_readChords(line));
        continue;
      }

      output.add(
        pendingChords.isEmpty
            ? line
            : _insertChordMarkers(line, pendingChords),
      );
      pendingChords = [];
    }

    return SongSourceImportResult(
      source: output.join('\n').trimRight() + '\n',
      format: SongSourceFormat.alignedText,
      warnings: const [],
    );
  }

  int _findFirstSection(List<String> lines, int start) {
    for (var index = start; index < lines.length; index++) {
      final match = _sectionHeader.firstMatch(lines[index]);
      if (match != null && _isKnownSection(match.group(1)!)) {
        return index;
      }
    }
    return -1;
  }

  bool _isKnownSection(String label) {
    final value = label.trim().toLowerCase();
    return value.startsWith('verse') ||
        value.startsWith('strophe') ||
        value.startsWith('chorus') ||
        value.startsWith('refrain') ||
        value.startsWith('bridge') ||
        value.startsWith('pre-chorus') ||
        value.startsWith('pre chorus') ||
        value.startsWith('intro') ||
        value.startsWith('outro') ||
        value.startsWith('interlude') ||
        value.startsWith('instrumental') ||
        value.startsWith('solo') ||
        value == 'tab';
  }

  SongSectionKind _sectionKind(List<String> lines, int index, String label) {
    final value = label.toLowerCase();
    if (value.startsWith('chorus') || value.startsWith('refrain')) {
      return SongSectionKind.chorus;
    }
    if (value.startsWith('bridge')) return SongSectionKind.bridge;
    if (value == 'tab' ||
        value.startsWith('instrumental') ||
        value.startsWith('solo') ||
        ((value.startsWith('intro') || value.startsWith('outro')) &&
            _hasTabLines(lines, index + 1))) {
      return SongSectionKind.tab;
    }
    return SongSectionKind.verse;
  }

  bool _hasTabLines(List<String> lines, int start) {
    var inspected = 0;
    for (var index = start; index < lines.length; index++) {
      final line = lines[index];
      if (_sectionHeader.hasMatch(line)) return false;
      if (line.trim().isEmpty) continue;
      inspected++;
      if (_tabLine.hasMatch(line)) return true;
      if (inspected >= 8) return false;
    }
    return false;
  }

  void _appendHeaderMetadata(List<String> lines, List<String> output) {
    var difficultyAdded = false;
    var tuningAdded = false;
    var capoAdded = false;
    var tempoAdded = false;
    var keyAdded = false;

    for (final line in lines) {
      final difficulty = RegExp(
        r'difficulty\s*:?\s*(beginner|easy|intermediate|advanced|expert)',
        caseSensitive: false,
      ).firstMatch(line);
      if (!difficultyAdded && difficulty != null) {
        final difficultyLabel = _clean(difficulty.group(1)!);
        output.add('{comment: Difficulty: $difficultyLabel}');
        difficultyAdded = true;
      }

      final tuning =
          RegExp(r'tuning\s*:\s*(.+)$', caseSensitive: false).firstMatch(line);
      if (!tuningAdded && tuning != null) {
        final tuningLabel = _clean(tuning.group(1)!);
        output.add('{comment: Tuning: $tuningLabel}');
        tuningAdded = true;
      }

      final capo = RegExp(
        r'\bcapo\s*:?\s*(?:capo\s*)?(\d+)',
        caseSensitive: false,
      ).firstMatch(line);
      if (!capoAdded && capo != null) {
        output.add('{capo: ${capo.group(1)!}}');
        capoAdded = true;
      }

      final tempo =
          RegExp(r'\b(\d{2,3})\s*bpm\b', caseSensitive: false).firstMatch(line);
      if (!tempoAdded && tempo != null) {
        output.add('{tempo: ${tempo.group(1)!}}');
        tempoAdded = true;
      }

      final key =
          RegExp(r'\bkey\s*:\s*([A-G](?:#|b)?m?)\b', caseSensitive: false)
              .firstMatch(line);
      if (!keyAdded && key != null) {
        output.add('{key: ${key.group(1)!}}');
        keyAdded = true;
      }
    }
  }

  bool _isChordRow(String line) {
    final tokens = RegExp(r'\S+').allMatches(line);
    if (tokens.isEmpty) return false;
    return tokens.every((match) => _chordToken.hasMatch(match.group(0)!));
  }

  List<_AlignedChord> _readChords(String line) {
    return RegExp(r'\S+')
        .allMatches(line)
        .map(
          (match) => _AlignedChord(
            symbol: match.group(0)!,
            position: match.start,
          ),
        )
        .toList(growable: false);
  }

  String _insertChordMarkers(String lyricLine, List<_AlignedChord> chords) {
    final ordered = [...chords]
      ..sort((left, right) => left.position.compareTo(right.position));
    final lastPosition = ordered.last.position;
    final paddedLine = lyricLine.padRight(
      lyricLine.length < lastPosition ? lastPosition : lyricLine.length,
    );

    final result = StringBuffer();
    var cursor = 0;
    for (final chord in ordered) {
      final position = chord.position.clamp(cursor, paddedLine.length).toInt();
      result.write(paddedLine.substring(cursor, position));
      result.write('[${chord.symbol}]');
      cursor = position;
    }
    result.write(paddedLine.substring(cursor));
    return result.toString();
  }

  bool _isPageNumber(String line) {
    return RegExp(r'^\s*page\s+\d+\s*/\s*\d+\s*$', caseSensitive: false)
        .hasMatch(line);
  }

  String _clean(String value) {
    return value
        .replaceAll(RegExp(r'[{}]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _AlignedChord {
  const _AlignedChord({required this.symbol, required this.position});

  final String symbol;
  final int position;
}
