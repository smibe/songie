/// Transposes a chord symbol by [semitones].
///
/// Chord quality and extensions are preserved. Slash-chord bass notes are
/// transposed as well. Non-chord labels (for example `N.C.`) are returned
/// unchanged.
String transposeChordSymbol(
  String chord,
  int semitones, {
  bool? preferFlats,
}) {
  final match = RegExp(
    r'^([A-Ga-g])([#b]?)(.*?)(?:/([A-Ga-g])([#b]?))?$'
  ).firstMatch(chord.trim());
  if (match == null) return chord;

  final root = '${match.group(1)!.toUpperCase()}${match.group(2)!}';
  final quality = match.group(3)!;
  final bassLetter = match.group(4);
  final bassAccidental = match.group(5) ?? '';
  final useFlats = preferFlats ??
      (match.group(2) == 'b' || bassAccidental == 'b');

  final transposedRoot = _transposeNote(root, semitones, useFlats);
  if (bassLetter == null) return '$transposedRoot$quality';

  final bass = _transposeNote(
    '${bassLetter.toUpperCase()}$bassAccidental',
    semitones,
    useFlats,
  );
  return '$transposedRoot$quality/$bass';
}

String _transposeNote(String note, int semitones, bool useFlats) {
  const naturalPitch = <String, int>{
    'C': 0,
    'D': 2,
    'E': 4,
    'F': 5,
    'G': 7,
    'A': 9,
    'B': 11,
  };
  const sharps = <String>[
    'C', 'C#', 'D', 'D#', 'E', 'F',
    'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];
  const flats = <String>[
    'C', 'Db', 'D', 'Eb', 'E', 'F',
    'Gb', 'G', 'Ab', 'A', 'Bb', 'B',
  ];

  final letter = note.substring(0, 1);
  final accidental = note.length > 1 ? note.substring(1) : '';
  var pitch = naturalPitch[letter]!;
  if (accidental == '#') pitch++;
  if (accidental == 'b') pitch--;
  final transposedPitch = ((pitch + semitones) % 12 + 12) % 12;
  return (useFlats ? flats : sharps)[transposedPitch];
}
