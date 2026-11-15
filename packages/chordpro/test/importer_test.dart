import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

void main() {
  final importer = SongSourceImporter();
  const parser = ChordProParser();

  group('SongSourceImporter', () {
    test('recognizes and preserves a ChordPro source', () {
      const source = '{title: Existing song}\r\n{artist: Example}\r\n[G]Hello\r\n';
      final result = importer.importSource(source);

      expect(result.format, SongSourceFormat.chordPro);
      expect(result.source, '{title: Existing song}\n{artist: Example}\n[G]Hello\n');
      expect(parser.parse(result.source).title, 'Existing song');
    });

    test('converts aligned text, maps Refrain to chorus and imports capo', () {
      const source = '''
Example Tune Chords by Example Artist
Author: UnregisteredDifficulty: Beginner
Speed: 0.2
Transpose
Capo:
Capo 2.

[Intro]

E|-----0------|-------0----|
B|-1-3---3-0--|---1-3---3--|
G|------------|-0----------|

[Verse 1]

C              G     Am
Morning opens softly
        G                C
and the day is bright now

[Refrain]

         C
Sing together
           Am
through the night
''';

      final result = importer.importSource(source);
      final song = parser.parse(result.source);

      expect(result.format, SongSourceFormat.alignedText);
      expect(song.title, 'Example Tune');
      expect(song.artist, 'Example Artist');
      expect(song.metadata['capo'], '2');
      expect(song.sections, hasLength(4));

      final intro = song.sections[1];
      expect(intro.kind, SongSectionKind.tab);
      final firstTabLine = intro.lines.firstWhere((line) => line.text.isNotEmpty);
      expect(firstTabLine.text, 'E|-----0------|-------0----|');
      expect(firstTabLine.chords, isEmpty);

      final verse = song.sections[2];
      expect(verse.kind, SongSectionKind.verse);
      final firstLyricLine = verse.lines.firstWhere((line) => line.text.isNotEmpty);
      expect(firstLyricLine.text.trimRight(), 'Morning opens softly');
      expect(
        firstLyricLine.chords.map((chord) => chord.symbol),
        ['C', 'G', 'Am'],
      );

      final refrain = song.sections[3];
      expect(refrain.kind, SongSectionKind.chorus);
      expect(refrain.label, 'Refrain');
    });

    test('retains tuning and tempo metadata when present', () {
      const source = '''
Example song Chords by Example Artist
Difficulty: beginner
Tuning: E A D G B E
76 bpm
[Verse 1]
G
Hello
''';

      final result = importer.importSource(source);
      final song = parser.parse(result.source);

      expect(song.metadata['tempo'], '76');
      expect(
        song.sections.last.lines.firstWhere((line) => line.text.isNotEmpty).text,
        'Hello',
      );
    });

    test('rejects empty input and unsupported text formats', () {
      expect(
        () => importer.importSource('  \n'),
        throwsFormatException,
      );
      expect(
        () => importer.importSource('Just some lyrics without a header'),
        throwsFormatException,
      );
    });
  });
}
