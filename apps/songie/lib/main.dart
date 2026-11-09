import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'data/firestore_song_repository.dart';
import 'firebase_options.dart';
import 'settings/songie_settings.dart';
import 'songie_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;
  try {
    // Configure persistence before the first Firestore operation. This
    // setting is supported by the current FlutterFire API on web and mobile.
    firestore.settings = const Settings(persistenceEnabled: true);
  } on FirebaseException catch (error) {
    // Persistent storage may be unavailable in a restricted browser context.
    // Firestore can still operate with its in-memory cache.
    debugPrint(
      'Firestore persistence unavailable (${error.code}): ${error.message}',
    );
  }

  final settings = await SongieSettings.load();
  final songRepository = FirestoreSongRepository(firestore);

  runApp(
    SongieApp(
      settings: settings,
      songRepository: songRepository,
    ),
  );
}
