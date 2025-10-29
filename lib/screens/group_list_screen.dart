// lib/screens/group_list_screen.dart
import 'package:flut1/models.dart';
import 'package:flut1/screens/find_users_screen.dart'; // Import FindUsersScreen
import 'package:flut1/screens/group_details_screen.dart';
import 'package:flut1/screens/invitation_details_screen.dart';
import 'package:flut1/screens/profile_screen.dart'; // Import ProfileScreen
import 'package:flut1/view_models/group_list_view_models.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  final GroupListViewModel _viewModel = GroupListViewModel();
  final TextEditingController _groupNameController = TextEditingController();
  // Removed: final TextEditingController _inviteIdentifierController = TextEditingController();

  void _createGroupDialog() {
    _groupNameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Group'),
        content: TextField(
          controller: _groupNameController,
          decoration: const InputDecoration(hintText: 'Enter group name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = Provider.of<User?>(context, listen: false);
              if (user != null && _groupNameController.text.isNotEmpty) {
                await _viewModel.createGroup(_groupNameController.text, user.uid);
                Navigator.pop(context);
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a group name')),
                  );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // Removed: void _inviteToGroupDialog(String groupId, String groupName) { ... }
  
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = Provider.of<User?>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keeen'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await authService.signOut();
            },
          )
        ],
      ),
      body: user == null
          ? const Center(child: Text("Authenticating..."))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInvitationsList(user.uid),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('My Groups', style: Theme.of(context).textTheme.headlineMedium),
                ),
                Expanded(child: _buildGroupsList(user.uid)),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGroupDialog,
        tooltip: 'Create Group',
        child: const Icon(Icons.add),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
      ),
    );
  }

  Widget _buildInvitationsList(String uid) {
    return StreamBuilder<List<GroupInvitation>>(
      stream: _viewModel.firestoreService.getInvitationsStream(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink(); // No invitations, show nothing
        }
        final invitations = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Invitations', style: Theme.of(context).textTheme.headlineMedium),
            ),
            ListView.builder(
              shrinkWrap: true,
              itemCount: invitations.length,
              itemBuilder: (context, index) {
                final invitation = invitations[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    title: Text('Invitation to join ${invitation.groupName}'),
                    leading: Icon(Icons.mail, color: Theme.of(context).colorScheme.secondary),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InvitationDetailsScreen(invitation: invitation),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const Divider(height: 30, thickness: 1),
          ],
        );
      },
    );
  }

  Widget _buildGroupsList(String uid) {
    return StreamBuilder<List<Group>>(
      stream: _viewModel.firestoreService.getGroupsStream(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading groups: ${snapshot.error}'));
        }
        final groups = snapshot.data ?? [];
        if (groups.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'You are not in any groups yet.\nTap the + button to create one!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }
        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${group.memberUids.length} member(s)'),
                leading: Icon(Icons.group, color: Theme.of(context).colorScheme.primary),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.person_add_alt_1),
                      tooltip: 'Invite User',
                      // MODIFIED: Navigate to FindUsersScreen
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FindUsersScreen(groupId: group.id, groupName: group.name),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupDetailsScreen(
                        groupId: group.id,
                        groupName: group.name,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    // Removed: _inviteIdentifierController.dispose();
    super.dispose();
  }
}