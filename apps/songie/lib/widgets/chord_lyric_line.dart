import 'package:chordpro/chordpro.dart';
import 'package:flutter/material.dart';

/// Renders one lyric line with chord symbols aligned to their source offsets.
class ChordLyricLine extends StatelessWidget {
  const ChordLyricLine({
    required this.line,
    required this.fontSize,
    required this.showChords,
    super.key,
  });

  final SongLine line;
  final double fontSize;
  final bool showChords;

  @override
  Widget build(BuildContext context) {
    if (line.text.isEmpty) {
      return SizedBox(height: fontSize * 0.9);
    }

    final lyricStyle = DefaultTextStyle.of(context).style.merge(
      TextStyle(
        fontSize: fontSize,
        height: 1.35,
        color: line.isComment
            ? const Color(0xFF666666)
            : const Color(0xFF202020),
        fontStyle: line.isComment ? FontStyle.italic : FontStyle.normal,
      ),
    );

    if (!showChords || line.chords.isEmpty || line.isComment) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Text(line.text, style: lyricStyle),
      );
    }

    final chordStyle = DefaultTextStyle.of(context).style.merge(
      TextStyle(
        fontSize: fontSize * 0.72,
        height: 1.15,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF555555),
      ),
    );
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final lyricPainter = TextPainter(
      text: TextSpan(text: line.text, style: lyricStyle),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();

    final positionedChords = <_PositionedChord>[];
    var contentWidth = lyricPainter.width;
    var chordBandHeight = 0.0;

    for (final chord in line.chords) {
      final offset = chord.position.clamp(0, line.text.length).toInt();
      // Measure the caret in the complete lyric run. Measuring a separate
      // prefix can differ slightly because of kerning and text shaping.
      final chordLeft = lyricPainter
          .getOffsetForCaret(
            TextPosition(offset: offset),
            Rect.fromLTWH(0, 0, 1, lyricPainter.height),
          )
          .dx;
      final chordPainter = TextPainter(
        text: TextSpan(text: chord.symbol, style: chordStyle),
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout();

      positionedChords.add(
        _PositionedChord(chord.symbol, chordLeft),
      );
      final chordRight = chordLeft + chordPainter.width;
      if (chordRight > contentWidth) contentWidth = chordRight;
      if (chordPainter.height > chordBandHeight) {
        chordBandHeight = chordPainter.height;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: SizedBox(
          width: contentWidth.ceilToDouble(),
          height: chordBandHeight + 5 + lyricPainter.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: chordBandHeight + 5,
                child: Text(
                  line.text,
                  style: lyricStyle,
                  softWrap: false,
                ),
              ),
              for (final chord in positionedChords)
                Positioned(
                  left: chord.left,
                  top: 0,
                  child: Text(chord.symbol, style: chordStyle, softWrap: false),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PositionedChord {
  const _PositionedChord(this.symbol, this.left);

  final String symbol;
  final double left;
}
