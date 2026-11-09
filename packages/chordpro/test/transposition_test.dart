import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

void main() {
  group('transposeChordSymbol', () {
    test('transposes major and minor chords', () {
      expect(transposeChordSymbol('C', 2), 'D');
      expect(transposeChordSymbol('Am', 2), 'Bm');
    });

    test('preserves chord extensions and slash bass notes', () {
      expect(transposeChordSymbol('Cmaj7/E', 2), 'Dmaj7/F#');
    });

    test('uses flat notation when requested', () {
      expect(transposeChordSymbol('C', 1, preferFlats: true), 'Db');
    });

    test('preserves non-chord labels', () {
      expect(transposeChordSymbol('N.C.', 3), 'N.C.');
    });

    test('supports negative and octave transposition', () {
      expect(transposeChordSymbol('D', -2), 'C');
      expect(transposeChordSymbol('G', 12), 'G');
    });
  });
}
