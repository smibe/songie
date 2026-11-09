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

const _longRoadHome = '''
{title: The Long Road Home}
{artist: Songie Demo}
{key: C}
{tempo: 92}
{start_of_verse: Verse 1}
[C]The station clock is [G]running slow tonight,
[Am]Rain is drawing [F]silver lines across the [C]glass;
[C]I have a pocket [G]full of little plans,
[F]And a map with [G]more than one way [C]home.
{end_of_verse}
{start_of_chorus: Chorus}
[F]Take the long way [C]home if you need to,
[G]Leave a little [Am]space for the view;
[F]Every turning [C]has a story,
[Dm]Every mile can [G]bring you back to [C]you.
{end_of_chorus}
{start_of_verse: Verse 2}
[C]There are windows [G]glowing on the hillside,
[Am]Someone's kitchen [F]smells of bread and [C]thyme;
[C]A bicycle is [G]leaning by the doorway,
[F]And the evening [G]settles into [C]time.
[Am]I used to think the [Em]answer was a straight road,
[F]A line that never [C]wandered or went wrong;
[Dm]Now I know the [Am]best things take their [F]own route,
[G]And sometimes getting [G7]lost is how you [C]find a song.
{end_of_verse}
{start_of_chorus: Chorus}
[F]Take the long way [C]home if you need to,
[G]Leave a little [Am]space for the view;
[F]Every turning [C]has a story,
[Dm]Every mile can [G]bring you back to [C]you.
{end_of_chorus}
{start_of_bridge: Bridge}
[Am]When the road is [Em]dark, keep the window [F]open,
[C]Let the quiet [G]air remind you where you [Am]are;
[Dm]You don't have to [Am]see the whole horizon,
[F]Just the next small [G]step beneath the [C]stars.
{end_of_bridge}
{start_of_verse: Verse 3}
[C]So if you see me [G]coming round the corner,
[Am]With a little [F]dust upon my [C]shoes;
[C]I'll have stories [G]folded in my jacket,
[F]And a little [G]more patience than I [C]used to.
{end_of_verse}
{start_of_chorus: Final chorus}
[F]Take the long way [C]home if you need to,
[G]Leave a little [Am]space for the view;
[F]Every turning [C]has a story,
[Dm]Every mile can [G]bring you back to [C]you.
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
  SongieSong(
    id: 'long-road-home',
    source: _longRoadHome,
    document: _parser.parse(_longRoadHome),
  ),
];
