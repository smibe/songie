import 'package:chordpro/chordpro.dart';

class SongieSong {
  const SongieSong({
    required this.id,
    required this.source,
    required this.document,
  });

  final String id;
  final String source;
  final ChordProSong document;

  String get title => document.title ?? 'Untitled song';
  String get artist => document.artist ?? '';
}

const _morningLight = '''
{title: Morning Light}
{artist: Songie Demo}
{key: G}
{start_of_verse: Verse 1}
[G]When the morning [D]opens
[Em]And the road is [C]clear
[G]Take a quiet [D]moment
[C]Let the day begin [G]here
{end_of_verse}
{start_of_chorus: Chorus}
[C]Step by step, [G]mile by mile
[D]Leave a little [Em]room to smile
[C]The road is [G]wide, the sky is [D]bright
[C]Keep on walking [D]toward the [G]light
{end_of_chorus}
''';

const _quietRiver = '''
{title: Quiet River}
{artist: Songie Demo}
{key: D}
{start_of_verse: Verse 1}
[D]The water moves [A]without a sound
[Bm]It finds its way [G]around the ground
[D]No need to [A]rush the day
[G]The river knows [A]its quiet way
{end_of_verse}
{start_of_chorus: Chorus}
[G]Slow down, [D]breathe in
[A]Let the [Bm]morning begin
[G]One clear [D]note, one [A]open sky
[G]Let the [A]passing moments [D]fly
{end_of_chorus}
''';

const _parser = ChordProParser();

final demoSongs = <SongieSong>[
  SongieSong(
    id: 'morning-light',
    source: _morningLight,
    document: _parser.parse(_morningLight),
  ),
  SongieSong(
    id: 'quiet-river',
    source: _quietRiver,
    document: _parser.parse(_quietRiver),
  ),
];
