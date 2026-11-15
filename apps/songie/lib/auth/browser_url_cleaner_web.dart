import 'package:web/web.dart' as web;

/// Removes one-time Firebase email-link parameters from the browser URL.
///
/// A pending Songie room code is retained so an invitation survives sign-in.
void clearFirebaseAuthUrl() {
  final currentUri = Uri.base;
  final roomCode = currentUri.queryParameters['room'];
  final cleanUri = currentUri.replace(
    path: '/',
    queryParameters: roomCode == null || roomCode.trim().isEmpty
        ? <String, String>{}
        : {'room': roomCode},
    fragment: '',
  );

  web.window.history.replaceState(null, '', cleanUri.toString());
}
