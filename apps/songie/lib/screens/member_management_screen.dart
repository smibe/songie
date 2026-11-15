import 'package:flutter/material.dart';

import '../data/membership_repository.dart';
import '../data/song_access.dart';

class MemberManagementScreen extends StatefulWidget {
  const MemberManagementScreen({
    required this.membershipRepository,
    required this.currentUid,
    super.key,
  });

  final FirestoreMembershipRepository membershipRepository;
  final String currentUid;

  @override
  State<MemberManagementScreen> createState() =>
      _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  late final Stream<List<SongieMembership>> _membersStream;
  final _searchController = TextEditingController();
  String _query = '';
  String? _savingUid;

  @override
  void initState() {
    super.initState();
    _membersStream = widget.membershipRepository.watchMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _changeRole(
    SongieMembership member,
    SongieMemberRole newRole,
  ) async {
    if (newRole == member.role || member.uid == widget.currentUid) return;

    final name = member.displayName.trim().isEmpty
        ? member.email
        : member.displayName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change user role?'),
        content: Text(
          'Set the role of $name to "${newRole.label}"? '
          'This changes which songs the user can access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Change role'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _savingUid = member.uid;
    });

    try {
      await widget.membershipRepository.setRole(
        uid: member.uid,
        role: newRole,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role updated for $name.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update role: $error')),
      );
    } finally {
      if (mounted) setState(() => _savingUid = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Manage users')),
      body: StreamBuilder<List<SongieMembership>>(
        stream: _membersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load users: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final members = [...snapshot.data!]
            ..sort((a, b) {
              final nameA = a.displayName.isEmpty ? a.email : a.displayName;
              final nameB = b.displayName.isEmpty ? b.email : b.displayName;
              return nameA.toLowerCase().compareTo(nameB.toLowerCase());
            });
          final visibleMembers = members.where((member) {
            final haystack =
                '${member.displayName} ${member.email}'.toLowerCase();
            return query.isEmpty || haystack.contains(query);
          }).toList(growable: false);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.clear),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${members.length} registered users',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              Expanded(
                child: visibleMembers.isEmpty
                    ? const Center(child: Text('No matching users.'))
                    : ListView.separated(
                        itemCount: visibleMembers.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final member = visibleMembers[index];
                          final isCurrentUser =
                              member.uid == widget.currentUid;
                          final name = member.displayName.trim().isEmpty
                              ? 'Name not provided'
                              : member.displayName;

                          return ListTile(
                            title: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              member.email.isEmpty
                                  ? 'Email unavailable'
                                  : member.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: SizedBox(
                              width: 126,
                              child: DropdownButton<SongieMemberRole>(
                                value: member.role,
                                isExpanded: true,
                                underline: const SizedBox.shrink(),
                                onChanged: isCurrentUser ||
                                        _savingUid != null
                                    ? null
                                    : (role) {
                                        if (role != null) {
                                          _changeRole(member, role);
                                        }
                                      },
                                items: SongieMemberRole.values
                                    .map(
                                      (role) => DropdownMenuItem(
                                        value: role,
                                        child: Text(role.label),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ),
                          );
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
