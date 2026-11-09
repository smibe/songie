import 'package:flutter/material.dart';

import '../data/song.dart';
import '../settings/songie_settings.dart';
import '../widgets/chord_lyric_line.dart';

class SongReaderContent extends StatelessWidget {
  const SongReaderContent({
    required this.song,
    required this.settings,
    this.performanceMode = false,
    super.key,
  });

  final SongieSong song;
  final SongieSettings settings;
  final bool performanceMode;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final fontSize = settings.lyricsFontSize *
            (performanceMode ? 1.12 : 1.0);
        return ListView(
          padding: EdgeInsets.symmetric(
            horizontal: performanceMode ? 32 : 24,
            vertical: performanceMode ? 28 : 24,
          ),
          children: [
            Text(
              song.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF202020),
              ),
            ),
            if (song.artist.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                song.artist,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF666666),
                ),
              ),
            ],
            const SizedBox(height: 28),
            for (final section in song.document.sections) ...[
              if (section.label != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Text(
                    section.label!,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF777777),
                    ),
                  ),
                ),
              ],
              for (final line in section.lines)
                ChordLyricLine(
                  line: line,
                  fontSize: fontSize,
                  showChords: settings.showChords,
                ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}
