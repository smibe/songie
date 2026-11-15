import 'package:flutter/material.dart';

import '../data/membership_repository.dart';

/// Required profile step shown until the signed-in user has a display name.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    required this.uid,
    required this.email,
    required this.initialName,
    required this.membershipRepository,
    super.key,
  });

  final String uid;
  final String email;
  final String initialName;
  final FirestoreMembershipRepository membershipRepository;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final TextEditingController _nameController;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.length < 2 || name.length > 80) {
      setState(() {
        _error = 'Please enter a name between 2 and 80 characters.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.membershipRepository.saveOwnProfile(
        uid: widget.uid,
        email: widget.email,
        displayName: name,
      );
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is FormatException
            ? error.message.toString()
            : 'Could not save your profile: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Complete your profile',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Please enter your name so the Songie administrators know who is requesting access. Your account will not receive friend or admin access automatically.',
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.email,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    enabled: !_busy,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Your name',
                      hintText: 'First and last name',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) {
                      if (!_busy) _save();
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
