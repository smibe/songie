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

          final wrappedRows = _wrapTextToWidth(
            text: line.text,
            maxWidth: maxWidth,
            style: lyricStyle,
            textDirection: textDirection,
            textScaler: textScaler,
          );
          final children = <Widget>[];

          for (var rowIndex = 0; rowIndex < wrappedRows.length; rowIndex++) {
            final row = wrappedRows[rowIndex];
            final isLastRow = rowIndex == wrappedRows.length - 1;
            final rowPainter = TextPainter(
              text: TextSpan(text: row.text, style: lyricStyle),
              textDirection: textDirection,
              textScaler: textScaler,
            )..layout();

            final positionedChords = <_PositionedChord>[];
            var chordBandHeight = 0.0;

            for (final chord in line.chords) {
              final offset = chord.position.clamp(0, line.text.length).toInt();
              final belongsToRow = offset >= row.start &&
                  (offset < row.end || (isLastRow && offset == row.end));
              if (!belongsToRow) continue;

              final localOffset = (offset - row.start)
                  .clamp(0, row.text.length)
                  .toInt();
              final chordLeft = rowPainter
                  .getOffsetForCaret(
                    TextPosition(offset: localOffset),
                    Rect.fromLTWH(0, 0, 1, rowPainter.height),
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
              positionedChords.add(
                _PositionedChord(
                  chord.symbol,
                  chordLeft.clamp(0.0, maximumLeft).toDouble(),
                ),
              );
              if (chordPainter.height > chordBandHeight) {
                chordBandHeight = chordPainter.height;
              }
              chordPainter.dispose();
            }

            final rowHeight = rowPainter.height;
            rowPainter.dispose();

            if (positionedChords.isEmpty) {
              children.add(
                SizedBox(
                  width: maxWidth,
                  height: row.text.isEmpty ? fontSize * 1.35 : rowHeight,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      row.text,
                      softWrap: false,
                      style: lyricStyle,
                    ),
                  ),
                ),
              );
            } else {
              const chordGap = 5.0;
              children.add(
                SizedBox(
                  width: maxWidth,
                  height: chordBandHeight + chordGap + rowHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        top: chordBandHeight + chordGap,
                        child: Text(
                          row.text,
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
          }

          return SizedBox(
            width: maxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          );
        },
      ),
    );
  }

  /// Wraps at whitespace without relying on TextPainter.getLineBoundary().
  ///
  /// That method currently returns incorrect ranges for wrapped text in some
  /// Flutter web builds. Measuring each candidate row ourselves keeps the
  /// chord offsets deterministic across web and native renderers.
  List<_LyricRow> _wrapTextToWidth({
    required String text,
    required double maxWidth,
    required TextStyle style,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    double measure(String value) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final rows = <_LyricRow>[];
    var paragraphStart = 0;

    while (paragraphStart <= text.length) {
      final newline = text.indexOf('\n', paragraphStart);
      final paragraphEnd = newline < 0 ? text.length : newline;
      final paragraph = text.substring(paragraphStart, paragraphEnd);

      if (paragraph.isEmpty) {
        rows.add(_LyricRow(paragraphStart, paragraphEnd, ''));
      } else {
        var current = '';
        var currentStart = paragraphStart;
        var currentEnd = paragraphStart;

        void flushCurrent() {
          if (current.isEmpty) return;
          rows.add(_LyricRow(currentStart, currentEnd, current));
          current = '';
        }

        void appendLongToken(String token, int tokenStart) {
          var fragmentStart = 0;
          var offset = 0;

          while (offset < token.length) {
            final nextOffset = _nextCodePointOffset(token, offset);
            final candidate = token.substring(fragmentStart, nextOffset);

            if (offset > fragmentStart && measure(candidate) > maxWidth) {
              final fragment = token.substring(fragmentStart, offset);
              rows.add(
                _LyricRow(
                  tokenStart + fragmentStart,
                  tokenStart + offset,
                  fragment,
                ),
              );
              fragmentStart = offset;
            } else {
              offset = nextOffset;
            }
          }

          if (fragmentStart < token.length) {
            rows.add(
              _LyricRow(
                tokenStart + fragmentStart,
                tokenStart + token.length,
                token.substring(fragmentStart),
              ),
            );
          }
        }

        void appendToken(String token, int tokenStart, int tokenEnd) {
          if (token.isEmpty) return;

          final candidate = current + token;
          if (current.isNotEmpty && measure(candidate) > maxWidth) {
            flushCurrent();
          }

          if (measure(token) <= maxWidth) {
            if (current.isEmpty) currentStart = tokenStart;
            current += token;
            currentEnd = tokenEnd;
          } else {
            flushCurrent();
            appendLongToken(token, tokenStart);
            currentStart = tokenEnd;
            currentEnd = tokenEnd;
          }
        }

        var cursor = 0;
        for (final match in RegExp(r'\S+\s*').allMatches(paragraph)) {
          final tokenStart = cursor;
          final tokenEnd = match.end;
          appendToken(
            paragraph.substring(cursor, tokenEnd),
            paragraphStart + tokenStart,
            paragraphStart + tokenEnd,
          );
          cursor = tokenEnd;
        }

        if (cursor < paragraph.length) {
          appendToken(
            paragraph.substring(cursor),
            paragraphStart + cursor,
            paragraphEnd,
          );
        }

        flushCurrent();
      }

      if (newline < 0) break;
      paragraphStart = newline + 1;
      if (paragraphStart == text.length) {
        rows.add(_LyricRow(paragraphStart, paragraphStart, ''));
        break;
      }
    }

    return rows;
  }

  int _nextCodePointOffset(String value, int offset) {
    final firstCodeUnit = value.codeUnitAt(offset);
    final isHighSurrogate =
        firstCodeUnit >= 0xD800 && firstCodeUnit <= 0xDBFF;
    return offset + (isHighSurrogate ? 2 : 1);
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

class _LyricRow {
  const _LyricRow(this.start, this.end, this.text);

  final int start;
  final int end;
  final String text;
}

class _PositionedChord {
  const _PositionedChord(this.symbol, this.left);

  final String symbol;
  final double left;
}
