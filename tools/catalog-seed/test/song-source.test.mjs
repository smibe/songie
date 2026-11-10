import assert from 'node:assert/strict';
import test from 'node:test';

import { convertAlignedChordSheet, normalizeSongSource } from '../song-source.mjs';

const plainTextSheet = [
  'Test Song Chords by Example Artist',
  'Difficulty: beginner',
  'Tuning: E A D G B E',
  'Strumming pattern',
  '76 bpm',
  'Chords',
  'G       C     G',
  '[Verse 1]',
  'G       C     G',
  'Hello there my friend',
  '        F',
  "we'll be fine tonight",
  '[Chorus]',
  'D     G',
  'Sing along now',
  '',
].join('\n');

test('converts aligned chord rows into ChordPro chord anchors', () => {
  const converted = convertAlignedChordSheet(plainTextSheet);

  assert.match(converted, /^\{title: Test Song\}$/m);
  assert.match(converted, /^\{artist: Example Artist\}$/m);
  assert.match(converted, /^\{comment: Difficulty: beginner\}$/m);
  assert.match(converted, /^\{comment: Tuning: E A D G B E\}$/m);
  assert.match(converted, /^\{tempo: 76\}$/m);
  assert.match(converted, /^\{start_of_verse: Verse 1\}$/m);
  assert.match(converted, /^\{start_of_chorus: Chorus\}$/m);
  assert.match(converted, /^\[G\]Hello th\[C\]ere my\[G\] friend$/m);
  assert.match(converted, /^we'll be\[F\] fine tonight$/m);
  assert.match(converted, /^\[D\]Sing a\[G\]long now$/m);
});

test('auto-detection keeps existing ChordPro source unchanged', () => {
  const source = '{title: Existing Song}\n{artist: Example Artist}\n[G]Hello\n';
  const result = normalizeSongSource(source);

  assert.equal(result.format, 'ChordPro');
  assert.equal(result.source, source);
});

test('auto-detection converts a plain text chord sheet', () => {
  const result = normalizeSongSource(plainTextSheet);

  assert.equal(result.format, 'aligned text chord sheet');
  assert.match(result.source, /^\{title: Test Song\}$/m);
  assert.match(result.source, /^\[G\]Hello th\[C\]ere my\[G\] friend$/m);
});

test('reports a useful error for unsupported text layouts', () => {
  assert.throws(
    () => convertAlignedChordSheet('This is not a supported chord sheet.'),
    /Expected a first line like "Song Title Chords by Artist"/,
  );

  assert.throws(
    () => convertAlignedChordSheet('Song Chords by Artist\nNo section here'),
    /No \[Verse\], \[Chorus\], or other recognized section heading/,
  );
});
