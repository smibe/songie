import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

void main() {
  group('ChordProParser', () {
    const parser = ChordProParser();

    test('reads common metadata aliases', () {
      final song = parser.parse('''
{t: Example song}
{artist: Example artist}
{key: G}
{capo: 2}
''');

      expect(song.title, 'Example song');
      expect(song.artist, 'Example artist');
      expect(song.key, 'G');
      expect(song.metadata['capo'], '2');
    });

    test('removes chord markers and preserves their text offsets', () {
      final song = parser.parse('[G]Hello [D]world');
      final line = song.sections.single.lines.single;

      expect(line.text, 'Hello world');
      expect(line.chords, hasLength(2));
      expect(line.chords[0].symbol, 'G');
      expect(line.chords[0].position, 0);
      expect(line.chords[1].symbol, 'D');
      expect(line.chords[1].position, 6);
    });

    test('creates chorus and verse sections in document order', () {
      final song = parser.parse('''
{start_of_verse: Verse 1}
First verse
{end_of_verse}
{soc}
Chorus line
{eoc}
Second verse
''');

      expect(song.sections, hasLength(3));
      expect(song.sections[0].kind, SongSectionKind.verse);
      expect(song.sections[0].label, 'Verse 1');
      expect(song.sections[1].kind, SongSectionKind.chorus);
      expect(song.sections[2].kind, SongSectionKind.verse);
    });

    test('supports comment directives and reports unknown directives', () {
      final song = parser.parse('''
{comment: Play softly}
{some_future_directive: value}
Lyrics
''');

      expect(song.sections.single.lines.first.isComment, isTrue);
      expect(song.sections.single.lines.first.text, 'Play softly');
      expect(song.warnings, hasLength(1));
      expect(song.warnings.single, contains('some_future_directive'));
    });

    test('keeps Unicode characters intact before chord markers', () {
      final song = parser.parse('🙂[C]Hello');
      final line = song.sections.single.lines.single;

      expect(line.text, '🙂Hello');
      expect(line.chords.single.position, 2);
    });

    test('preserves unmatched square brackets as lyric text', () {
      final song = parser.parse('A [bracketed note');
      expect(song.sections.single.lines.single.text, 'A [bracketed note');
    });
  });
}
