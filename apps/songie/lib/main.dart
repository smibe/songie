import 'package:flutter/widgets.dart';

import 'settings/songie_settings.dart';
import 'songie_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SongieSettings.load();
  runApp(SongieApp(settings: settings));
}
