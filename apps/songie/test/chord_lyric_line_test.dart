import 'package:chordpro/chordpro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songie/widgets/chord_lyric_line.dart';

void main() {
  const parser = ChordProParser();
  final line = parser.parse('[G]Hello [D]world').sections.single.lines.single;

  testWidgets('shows chord symbols above lyric text when enabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChordLyricLine(
            line: line,
            fontSize: 24,
            showChords: true,
          ),
        ),
      ),
    );

    expect(find.text('G'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    expect(find.text('Hello world'), findsOneWidget);
  });

  testWidgets('hides chord symbols but keeps lyric text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChordLyricLine(
            line: line,
            fontSize: 24,
            showChords: false,
          ),
        ),
      ),
    );

    expect(find.text('G'), findsNothing);
    expect(find.text('D'), findsNothing);
    expect(find.text('Hello world'), findsOneWidget);
  });

  testWidgets('wraps long lyric lines while keeping chord labels', (
    tester,
  ) async {
    const lyricText =
        'This is a long line of lyrics that must wrap before it reaches the '
        'end of this narrow screen.';
    final longLine = SongLine(
      text: lyricText,
      chords: const [
        ChordPlacement(symbol: 'C', position: 0),
        ChordPlacement(symbol: 'G', position: 45),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 180,
              child: ChordLyricLine(
                line: longLine,
                fontSize: 20,
                showChords: true,
              ),
            ),
          ),
        ),
      ),
    );

    final lyricRows = tester
        .widgetList<Text>(find.byType(Text))
        .where((widget) => widget.style?.fontSize == 20)
        .toList();

    expect(lyricRows.length, greaterThan(1));
    expect(find.text('C'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);

    final rowStartingWithBefore = lyricRows.firstWhere(
      (widget) => widget.data!.startsWith('before'),
    );
    final chordRect = tester.getRect(find.text('G'));
    final lyricRect = tester.getRect(find.text(rowStartingWithBefore.data!));
    expect(lyricRect.top - chordRect.bottom, lessThan(12));

    expect(tester.takeException(), isNull);
  });
}
