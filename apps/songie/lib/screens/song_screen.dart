import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/song.dart';
import '../settings/songie_settings.dart';
import 'song_reader_content.dart';

class SongScreen extends StatelessWidget {
  const SongScreen({
    required this.song,
    required this.settings,
    super.key,
  });

  final SongieSong song;
  final SongieSettings settings;

  void _openPerformanceMode(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PerformanceScreen(song: song, settings: settings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Song'),
        actions: [
          TextButton(
            onPressed: () => _openPerformanceMode(context),
            child: const Text('Full screen'),
          ),
        ],
      ),
      body: SongReaderContent(song: song, settings: settings),
    );
  }
}

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({
    required this.song,
    required this.settings,
    super.key,
  });

  final SongieSong song;
  final SongieSettings settings;

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  Timer? _hideControlsTimer;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_enterPerformanceMode());
    });
    _scheduleControlsHide();
  }

  Future<void> _enterPerformanceMode() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await WakelockPlus.enable();
  }

  void _scheduleControlsHide() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _revealControls() {
    if (!mounted) return;
    setState(() => _controlsVisible = true);
    _scheduleControlsHide();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _revealControls,
                child: SongReaderContent(
                  song: widget.song,
                  settings: widget.settings,
                  performanceMode: true,
                ),
              ),
            ),
            if (_controlsVisible)
              Positioned(
                top: 8,
                right: 12,
                child: Material(
                  color: Colors.white,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          unawaited(widget.settings.setLyricsFontSize(
                            widget.settings.lyricsFontSize - 2,
                          ));
                          _scheduleControlsHide();
                        },
                        child: const Text('A−'),
                      ),
                      TextButton(
                        onPressed: () {
                          unawaited(widget.settings.setLyricsFontSize(
                            widget.settings.lyricsFontSize + 2,
                          ));
                          _scheduleControlsHide();
                        },
                        child: const Text('A+'),
                      ),
                      TextButton(
                        onPressed: () {
                          unawaited(widget.settings.setShowChords(
                            !widget.settings.showChords,
                          ));
                          _scheduleControlsHide();
                        },
                        child: AnimatedBuilder(
                          animation: widget.settings,
                          builder: (context, _) => Text(
                            widget.settings.showChords
                                ? 'Chords on'
                                : 'Chords off',
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Exit'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
