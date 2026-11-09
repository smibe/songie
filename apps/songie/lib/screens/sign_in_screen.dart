import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/songie_auth_service.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({required this.authService, super.key});

  final SongieAuthService authService;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  bool _busy = false;
  bool _linkSent = false;
  String? _message;
  String? _error;

  bool get _completingLink => widget.authService.isEmailSignInLink;

  @override
  void initState() {
    super.initState();
    _loadPendingEmail();
  }

  Future<void> _loadPendingEmail() async {
    final email = await widget.authService.loadPendingEmail();
    if (!mounted || email == null || _emailController.text.isNotEmpty) return;
    _emailController.text = email;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendLink() async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });

    try {
      await widget.authService.sendSignInLink(_emailController.text);
      if (!mounted) return;
      setState(() {
        _linkSent = true;
        _message =
            'We sent you a sign-in link. Open it in this browser to complete sign-in.';
      });
    } on FirebaseAuthException catch (error) {
      _showError(_friendlyAuthError(error));
    } on FormatException catch (error) {
      _showError(error.message.toString());
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeLink() async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });

    try {
      await widget.authService.completeSignIn(_emailController.text);
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (error) {
      _showError(_friendlyAuthError(error));
    } on FormatException catch (error) {
      _showError(error.message.toString());
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  String _friendlyAuthError(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'Please enter a valid email address.',
      'invalid-action-code' || 'expired-action-code' =>
        'This sign-in link is invalid or has expired. Request a new one.',
      'user-disabled' => 'This account has been disabled.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'unauthorized-continue-uri' || 'unauthorized-domain' =>
        'The Songie domain is not authorized in Firebase Authentication settings.',
      _ => error.message ?? 'Sign-in failed. Please try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final completingLink = _completingLink;

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in to Songie')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                completingLink ? 'Complete sign-in' : 'Sign in without a password',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                completingLink
                    ? 'Enter the email address that received this sign-in link.'
                    : 'Enter your email address. We will send you a one-time sign-in link.',
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  if (_busy) return;
                  if (completingLink) {
                    _completeLink();
                  } else {
                    _sendLink();
                  }
                },
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                )),
                const SizedBox(height: 12),
              ],
              if (_message != null) ...[
                Text(_message!),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: _busy
                    ? null
                    : completingLink
                        ? _completeLink
                        : _sendLink,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        completingLink
                            ? 'Complete sign-in'
                            : 'Send sign-in link',
                      ),
              ),
              if (_linkSent && !completingLink) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() {
                    _linkSent = false;
                    _message = null;
                  }),
                  child: const Text('Use another email address'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
