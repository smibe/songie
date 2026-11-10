const CHORD_TOKEN =
  /^(?:[A-G](?:#|b)?(?:(?:maj|min|m|M|dim|aug|sus|add|no)?(?:\d+)?(?:[#b]\d+)?)*(?:\/[A-G](?:#|b)?)?|N\.?C\.?)$/i;

const SECTION_HEADER = /^\s*\[([^\]]+)\]\s*$/;
const PAGE_HEADER = /^\s*page\s+\d+\s*\/\s*\d+\s*$/i;

function cleanDirectiveValue(value) {
  return value.replace(/[{}]/g, '').replace(/\s+/g, ' ').trim();
}

function isChordRow(line) {
  const tokens = [...line.matchAll(/\S+/g)];
  return tokens.length > 0 && tokens.every((token) => CHORD_TOKEN.test(token[0]));
}

function chordTokens(line) {
  return [...line.matchAll(/\S+/g)].map((match) => ({
    symbol: match[0],
    position: match.index,
  }));
}

function addChordMarkers(lyricLine, chords) {
  const ordered = [...chords].sort((left, right) => left.position - right.position);
  const lastPosition = ordered.at(-1)?.position ?? 0;
  const paddedLine = lyricLine.padEnd(Math.max(lyricLine.length, lastPosition), ' ');

  let cursor = 0;
  let result = '';

  for (const chord of ordered) {
    const position = Math.max(cursor, Math.min(chord.position, paddedLine.length));
    result += paddedLine.slice(cursor, position);
    result += '[' + chord.symbol + ']';
    cursor = position;
  }

  return result + paddedLine.slice(cursor);
}

function sectionDirective(label) {
  if (/^chorus\b/i.test(label)) return 'start_of_chorus';
  if (/^bridge\b/i.test(label)) return 'start_of_bridge';
  return 'start_of_verse';
}

/**
 * Converts the aligned plain-text chord-sheet layout used by many song sites
 * into ChordPro. Chord-only rows are treated as chord placements for the
 * following lyric row; their character columns become ChordPro chord anchors.
 */
export function convertAlignedChordSheet(source) {
  const lines = source
    .replace(/^\uFEFF/, '')
    .replace(/\r\n?/g, '\n')
    .split('\n')
    .map((line) => line.replace(/\t/g, '    '));

  const firstContentIndex = lines.findIndex((line) => line.trim().length > 0);
  if (firstContentIndex < 0) {
    throw new Error('The chord sheet is empty.');
  }

  const header = lines[firstContentIndex].trim();
  const headerMatch = /^(.*?)\s+chords\s+by\s+(.+)$/i.exec(header);
  if (!headerMatch || !headerMatch[1].trim() || !headerMatch[2].trim()) {
    throw new Error(
      'Unrecognized text chord-sheet header. Expected a first line like "Song Title Chords by Artist".',
    );
  }

  const title = cleanDirectiveValue(headerMatch[1]);
  const artist = cleanDirectiveValue(headerMatch[2]);
  const firstSectionIndex = lines.findIndex((line, index) => {
    if (index <= firstContentIndex) return false;
    const match = SECTION_HEADER.exec(line);
    return match && /^(verse|chorus|bridge|pre[- ]?chorus|intro|outro|interlude|instrumental|solo)\b/i.test(match[1].trim());
  });

  if (firstSectionIndex < 0) {
    throw new Error(
      'No [Verse], [Chorus], or other recognized section heading was found.',
    );
  }

  const output = [
    '{title: ' + title + '}',
    '{artist: ' + artist + '}',
  ];

  for (const line of lines.slice(firstContentIndex + 1, firstSectionIndex)) {
    const difficulty = /^\s*difficulty\s*:\s*(.+?)\s*$/i.exec(line);
    const tuning = /^\s*tuning\s*:\s*(.+?)\s*$/i.exec(line);
    const tempo = /\b(\d{2,3})\s*bpm\b/i.exec(line);
    const key = /^\s*key\s*:\s*(.+?)\s*$/i.exec(line);
    const capo = /^\s*capo\s*:\s*(.+?)\s*$/i.exec(line);

    if (difficulty) {
      output.push('{comment: Difficulty: ' + cleanDirectiveValue(difficulty[1]) + '}');
    } else if (tuning) {
      output.push('{comment: Tuning: ' + cleanDirectiveValue(tuning[1]) + '}');
    } else if (tempo) {
      output.push('{tempo: ' + tempo[1] + '}');
    } else if (key) {
      output.push('{key: ' + cleanDirectiveValue(key[1]) + '}');
    } else if (capo) {
      output.push('{capo: ' + cleanDirectiveValue(capo[1]) + '}');
    }
  }

  let pendingChords = [];

  for (let index = firstSectionIndex; index < lines.length; index += 1) {
    const line = lines[index];

    if (PAGE_HEADER.test(line)) {
      continue;
    }

    const sectionMatch = SECTION_HEADER.exec(line);
    if (sectionMatch) {
      const label = cleanDirectiveValue(sectionMatch[1]);
      if (/^(verse|chorus|bridge|pre[- ]?chorus|intro|outro|interlude|instrumental|solo)\b/i.test(label)) {
        output.push('{' + sectionDirective(label) + ': ' + label + '}');
        pendingChords = [];
        continue;
      }
    }

    if (line.trim().length === 0) {
      output.push('');
      pendingChords = [];
      continue;
    }

    if (isChordRow(line)) {
      pendingChords.push(...chordTokens(line));
      continue;
    }

    output.push(pendingChords.length > 0
      ? addChordMarkers(line, pendingChords)
      : line);
    pendingChords = [];
  }

  return output.join('\n').trimEnd() + '\n';
}

/**
 * Preserve canonical ChordPro files unchanged; convert the supported
 * chord-above-lyrics text layout automatically for import.
 */
export function normalizeSongSource(source) {
  const normalized = source.replace(/^\uFEFF/, '').replace(/\r\n?/g, '\n');

  if (/^\s*\{\s*(?:title|t)\s*:/im.test(normalized)) {
    return { format: 'ChordPro', source: normalized };
  }

  return {
    format: 'aligned text chord sheet',
    source: convertAlignedChordSheet(normalized),
  };
}
