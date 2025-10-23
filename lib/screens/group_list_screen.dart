// lib/screens/group_list_screen.dart
import 'package:flut1/models.dart';
import 'package:flut1/screens/group_details_screen.dart'; // Import the new screen
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
  // Use the ViewModel
  final GroupListViewModel _viewModel = GroupListViewModel();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _inviteEmailController = TextEditingController();
  final TextEditingController _activityNameController = TextEditingController();


  void _createGroupDialog() {
    _groupNameController.clear(); // Clear previous input
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
                Navigator.pop(context); // Close dialog on success
              } else {
                 // Optionally show an error if name is empty
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

  void _inviteToGroupDialog(String groupId, String groupName) {
     _inviteEmailController.clear(); // Clear previous input
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invite User to "$groupName"'),
        content: TextField(
          controller: _inviteEmailController,
          decoration: const InputDecoration(hintText: 'Enter user email'),
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_inviteEmailController.text.isNotEmpty) {
                try {
                  // Show loading indicator maybe?
                  await _viewModel.inviteUserToGroup(groupId, _inviteEmailController.text);
                  Navigator.pop(context); // Close on success
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User invited successfully')),
                  );
                } catch (e) {
                   // Keep dialog open on error
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')), // Display error
                  );
                }
              } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an email address')),
                  );
              }
            },
            child: const Text('Invite'),
          ),
        ],
      ),
    );
  }

  // Dialog to add a new *type* of activity to a group
  void _addActivityDefinitionDialog(String groupId, String groupName) {
    _activityNameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Activity Type to "$groupName"'),
        content: TextField(
          controller: _activityNameController,
          decoration: const InputDecoration(hintText: 'e.g., Go for a beer, Play chess'),
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
              if (user != null && _activityNameController.text.isNotEmpty) {
                await _viewModel.addActivityDefinition(
                  groupId,
                  _activityNameController.text,
                  user.uid,
                );
                Navigator.pop(context);
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Activity type added!')),
                  );
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an activity name')),
                  );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false); // Use listen:false if only calling methods
    final user = Provider.of<User?>(context); // Keep listening here for user state

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await authService.signOut();
              // AuthGate will handle navigation
            },
          )
        ],
      ),
      body: user == null
          ? const Center(child: Text("Authenticating...")) // Or a loading indicator
          : StreamBuilder<List<Group>>(
              // Fetch groups using the ViewModel's FirestoreService instance
              stream: _viewModel.firestoreService.getGroupsStream(user.uid),
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
                      ),
                    ),
                  );
                }

                // --- Group List ---
                return ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        title: Text(group.name),
                        subtitle: Text('${group.memberUids.length} member(s)'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.person_add_alt_1),
                              tooltip: 'Invite User',
                              onPressed: () => _inviteToGroupDialog(group.id, group.name),
                            ),
                             IconButton(
                              icon: const Icon(Icons.playlist_add),
                              tooltip: 'Add Activity Type',
                              onPressed: () => _addActivityDefinitionDialog(group.id, group.name),
                            ),
                          ],
                        ),
                        onTap: () {
                          // Navigate to Group Details Screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GroupDetailsScreen(
                                groupId: group.id,
                                groupName: group.name, // Pass name for AppBar title
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGroupDialog,
        tooltip: 'Create Group',
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _inviteEmailController.dispose();
     _activityNameController.dispose();
    super.dispose();
  }
}