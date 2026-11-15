import 'dart:html' as html;

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

  html.window.history.replaceState(null, '', cleanUri.toString());
}
