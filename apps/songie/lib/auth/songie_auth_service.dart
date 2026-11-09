import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Passwordless email-link authentication for the Songie web app.
class SongieAuthService {
  SongieAuthService(this._auth);

  static const _pendingEmailKey = 'songie.pendingEmailLink';
  static const _actionUrl = 'https://songie-prod.web.app';

  final FirebaseAuth _auth;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  bool get isEmailSignInLink =>
      kIsWeb && _auth.isSignInWithEmailLink(Uri.base.toString());

  Future<String?> loadPendingEmail() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_pendingEmailKey);
  }

  Future<void> sendSignInLink(String email) async {
    if (!kIsWeb) {
      throw UnsupportedError(
        'Passwordless email-link sign-in is currently available in the web app.',
      );
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw const FormatException('Please enter a valid email address.');
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_pendingEmailKey, normalizedEmail);

    try {
      await _auth.sendSignInLinkToEmail(
        email: normalizedEmail,
        actionCodeSettings: ActionCodeSettings(
          url: _actionUrl,
          handleCodeInApp: true,
        ),
      );
    } catch (_) {
      await preferences.remove(_pendingEmailKey);
      rethrow;
    }
  }

  /// Completes a link opened in this browser.
  ///
  /// Firebase requires the email address again when the link is opened on a
  /// different device/browser. In that case the sign-in screen asks for it.
  Future<UserCredential> completeSignIn(String email) async {
    if (!isEmailSignInLink) {
      throw StateError('The current page does not contain a Songie sign-in link.');
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw const FormatException('Please enter the email address that received the link.');
    }

    final credential = await _auth.signInWithEmailLink(
      email: normalizedEmail,
      emailLink: Uri.base.toString(),
    );

    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_pendingEmailKey);
    return credential;
  }

  /// Completes a sign-in automatically when the link is opened in the same
  /// browser where the email address was entered.
  Future<bool> completePendingSignIn() async {
    if (!isEmailSignInLink) return false;

    final email = await loadPendingEmail();
    if (email == null || email.isEmpty) return false;

    await completeSignIn(email);
    return true;
  }

  Future<void> signOut() => _auth.signOut();
}
