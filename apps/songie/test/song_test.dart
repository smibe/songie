import 'package:flutter_test/flutter_test.dart';
import 'package:songie/data/song.dart';

void main() {
  group('SongieSong', () {
    test('parses metadata from ChordPro source', () {
      const source = '''
{title: Test Song}
{artist: Test Artist}
{key: G}
[G]A line of [D]lyrics
''';

      final song = SongieSong.fromChordPro(id: 'test-song', source: source);

      expect(song.id, 'test-song');
      expect(song.title, 'Test Song');
      expect(song.artist, 'Test Artist');
      expect(song.key, 'G');
      expect(song.document.sections.single.lines.single.text, 'A line of lyrics');
    });

    test('maps a Firestore song document and retains ChordPro source', () {
      const source = '''
{title: Catalog Song}
{artist: Catalog Artist}
{key: D}
[D]The shared [A]song
''';

      final song = SongieSong.fromFirestore(
        id: 'catalog-song',
        data: {
          'title': 'Catalog Song',
          'artist': 'Catalog Artist',
          'key': 'D',
          'chordPro': source,
          'published': true,
          'schemaVersion': 1,
        },
      );

      expect(song.id, 'catalog-song');
      expect(song.title, 'Catalog Song');
      expect(song.artist, 'Catalog Artist');
      expect(song.key, 'D');
      expect(song.source, source);
      expect(song.document.sections.single.lines.single.chords, hasLength(2));
    });

    test('rejects a Firestore document without ChordPro source', () {
      expect(
        () => SongieSong.fromFirestore(
          id: 'broken-song',
          data: {'title': 'Broken'},
        ),
        throwsFormatException,
      );
    });
  });
}
