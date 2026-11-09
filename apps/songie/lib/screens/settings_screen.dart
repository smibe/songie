import 'dart:async';

import 'package:flutter/material.dart';

import '../settings/songie_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.settings, super.key});

  final SongieSettings settings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AnimatedBuilder(
        animation: settings,
        builder: (context, _) {
          return ListView(
            children: [
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                title: const Text('Show guitar chords'),
                subtitle: const Text(
                  'Display chord symbols above the lyrics.',
                ),
                value: settings.showChords,
                onChanged: (value) {
                  unawaited(settings.setShowChords(value));
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Row(
                  children: [
                    const Expanded(child: Text('Lyrics text size')),
                    Text(settings.lyricsFontSize.round().toString()),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Slider.adaptive(
                  min: SongieSettings.minLyricsFontSize,
                  max: SongieSettings.maxLyricsFontSize,
                  divisions: 10,
                  value: settings.lyricsFontSize,
                  onChanged: (value) {
                    unawaited(settings.setLyricsFontSize(value));
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
