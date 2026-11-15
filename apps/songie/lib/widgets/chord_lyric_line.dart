import 'package:chordpro/chordpro.dart';
import 'package:flutter/material.dart';

/// Renders one lyric line with chord symbols aligned to their source offsets.
class ChordLyricLine extends StatelessWidget {
  const ChordLyricLine({
    required this.line,
    required this.fontSize,
    required this.showChords,
    this.isTab = false,
    super.key,
  });

  final SongLine line;
  final double fontSize;
  final bool showChords;
  final bool isTab;

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

    if (isTab) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: Text(
            line.text,
            softWrap: false,
            style: lyricStyle.copyWith(
              fontFamily: 'monospace',
              fontSize: fontSize * 0.82,
              height: 1.2,
            ),
          ),
        ),
      );
    }

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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          if (!maxWidth.isFinite) {
            // Song content normally has a bounded width. Keep a safe fallback
            // for other callers that place this widget in an unbounded row.
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: _buildUnwrappedChordLine(
                lyricStyle: lyricStyle,
                chordStyle: chordStyle,
                textDirection: textDirection,
                textScaler: textScaler,
              ),
            );
          }

          final lyricPainter = TextPainter(
            text: TextSpan(text: line.text, style: lyricStyle),
            textDirection: textDirection,
            textScaler: textScaler,
          )..layout(maxWidth: maxWidth);
          final lineMetrics = lyricPainter.computeLineMetrics();
          final rows = <Widget>[];
          var start = 0;
          var visualLine = 0;

          // TextPainter applies the same word-wrapping rules as the Text
          // widget. Split at those visual boundaries so each wrapped row can
          // reserve its own space for chord symbols.
          while (start < line.text.length) {
            if (visualLine >= lineMetrics.length) {
              rows.add(Text(line.text.substring(start), style: lyricStyle));
              break;
            }

            final range = lyricPainter.getLineBoundary(
              TextPosition(
                offset: start,
                affinity: TextAffinity.downstream,
              ),
            );
            var end = range.end;
            if (end <= start) end = start + 1;
            if (end > line.text.length) end = line.text.length;

            final metric = lineMetrics[visualLine];
            final lyricSegment = line.text.substring(start, end);
            final positionedChords = <_PositionedChord>[];
            var chordBandHeight = 0.0;

            for (final chord in line.chords) {
              final offset = chord.position.clamp(0, line.text.length).toInt();
              final belongsToLine = offset >= start &&
                  (offset < end ||
                      (end == line.text.length && offset == end));
              if (!belongsToLine) continue;

              // Measure the caret in the complete lyric paragraph. This keeps
              // kerning and shaping identical to the original source line.
              final caretOffset = lyricPainter
                  .getOffsetForCaret(
                    TextPosition(
                      offset: offset,
                      affinity: TextAffinity.downstream,
                    ),
                    Rect.fromLTWH(
                      0,
                      0,
                      1,
                      lyricPainter.preferredLineHeight,
                    ),
                  )
                  .dx;

              final chordPainter = TextPainter(
                text: TextSpan(text: chord.symbol, style: chordStyle),
                textDirection: textDirection,
                textScaler: textScaler,
              )..layout();
              final maximumLeft = maxWidth > chordPainter.width
                  ? maxWidth - chordPainter.width
                  : 0.0;
              final left = (caretOffset - metric.left)
                  .clamp(0.0, maximumLeft)
                  .toDouble();

              positionedChords.add(_PositionedChord(chord.symbol, left));
              if (chordPainter.height > chordBandHeight) {
                chordBandHeight = chordPainter.height;
              }
              chordPainter.dispose();
            }

            if (positionedChords.isEmpty) {
              rows.add(
                SizedBox(
                  width: maxWidth,
                  height: metric.height,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      lyricSegment,
                      softWrap: false,
                      style: lyricStyle,
                    ),
                  ),
                ),
              );
            } else {
              const chordGap = 5.0;
              rows.add(
                SizedBox(
                  width: maxWidth,
                  height: chordBandHeight + chordGap + metric.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        top: chordBandHeight + chordGap,
                        child: Text(
                          lyricSegment,
                          softWrap: false,
                          style: lyricStyle,
                        ),
                      ),
                      for (final chord in positionedChords)
                        Positioned(
                          left: chord.left,
                          top: 0,
                          child: Text(
                            chord.symbol,
                            softWrap: false,
                            style: chordStyle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }

            start = end;
            visualLine++;
          }

          lyricPainter.dispose();

          return SizedBox(
            width: maxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: rows,
            ),
          );
        },
      ),
    );
  }

  Widget _buildUnwrappedChordLine({
    required TextStyle lyricStyle,
    required TextStyle chordStyle,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
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

      positionedChords.add(_PositionedChord(chord.symbol, chordLeft));
      final chordRight = chordLeft + chordPainter.width;
      if (chordRight > contentWidth) contentWidth = chordRight;
      if (chordPainter.height > chordBandHeight) {
        chordBandHeight = chordPainter.height;
      }
      chordPainter.dispose();
    }

    final result = SizedBox(
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
    );
    lyricPainter.dispose();
    return result;
  }
}

class _PositionedChord {
  const _PositionedChord(this.symbol, this.left);

  final String symbol;
  final double left;
}
