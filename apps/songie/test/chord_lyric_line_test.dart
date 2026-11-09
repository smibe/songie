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
}
