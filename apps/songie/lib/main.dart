import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
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
  if (kIsWeb) {
    try {
      await firestore.enablePersistence(
        const PersistenceSettings(synchronizeTabs: true),
      );
    } on FirebaseException catch (error) {
      // A browser can reject persistent storage (for example, another tab
      // may already own the persistence lease). Firestore still works with
      // its in-memory cache, so this must not prevent the app from starting.
      debugPrint(
        'Firestore web persistence unavailable (${error.code}): ${error.message}',
      );
    }
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
