// lib/screens/group_details_screen.dart
import 'package:flut1/screens/find_users_screen.dart';
import 'package:flut1/models.dart';
import 'package:flut1/view_models/group_details_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For formatting time

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDetailsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final TextEditingController _activityNameController = TextEditingController();

  // --- MODIFIED: Now accepts context and viewModel ---
  void _addActivityDefinitionDialog(BuildContext consumerContext, GroupDetailsViewModel viewModel) {
    _activityNameController.clear();
    
    // Get messenger from the *state's* context.
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    // Get user from the *state's* context (it's provided at the root).
    final user = Provider.of<User?>(context, listen: false);

    showDialog(
      context: consumerContext, // Use the context from the Consumer
      builder: (dialogContext) => AlertDialog(
        title: Text('Add New Activity Type to "${widget.groupName}"'),
        content: TextField(
          controller: _activityNameController,
          decoration: const InputDecoration(hintText: 'e.g., Go for a beer, Play chess'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final activityName = _activityNameController.text.trim();
              if (activityName.isEmpty) {
                // Show snackbar inside dialog
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                   const SnackBar(content: Text('Please enter an activity name')),
                );
                return;
              }

              if (user != null) {
                try {
                  // Await the async call using the passed-in viewModel
                  await viewModel.addActivityDefinition(
                    activityName,
                    user.uid,
                  );
                  Navigator.pop(dialogContext); // Pop dialog *after* success
                  scaffoldMessenger.showSnackBar( // Use main messenger
                    const SnackBar(content: Text('Activity type added!')),
                  );
                } catch (e) {
                   Navigator.pop(dialogContext); // Pop on error
                   scaffoldMessenger.showSnackBar(
                     SnackBar(content: Text('Error adding activity: $e')),
                   );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // --- Confirmation Dialog Helper ---
  Future<bool> _showConfirmationDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false; // Return false if dialog is dismissed
  }

  void _leaveGroup(GroupDetailsViewModel viewModel, String uid) async {
    final confirmed = await _showConfirmationDialog(
      'Leave Group?',
      'Are you sure you want to leave "${widget.groupName}"?',
    );
    if (confirmed && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      try {
        await viewModel.leaveGroup(uid);
        navigator.pop(); // Go back to group list
        messenger.showSnackBar(
          SnackBar(content: Text('You have left "${widget.groupName}"')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error leaving group: $e')),
        );
      }
    }
  }

  void _deleteGroup(GroupDetailsViewModel viewModel) async {
     final confirmed = await _showConfirmationDialog(
      'Delete Group?',
      'Are you sure you want to permanently delete "${widget.groupName}"? This cannot be undone.',
    );
    if (confirmed && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      try {
        await viewModel.deleteGroup();
        navigator.pop(); // Go back to group list
        messenger.showSnackBar(
          SnackBar(content: Text('Group "${widget.groupName}" deleted')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error deleting group: $e')),
        );
      }
    }
  }


  @override
  void dispose() {
    _activityNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GroupDetailsViewModel(widget.groupId),
      child: Consumer<GroupDetailsViewModel>(
        builder: (context, viewModel, child) {
          final user = Provider.of<User?>(context);

          return Scaffold(
            appBar: AppBar(
              title: Text(widget.groupName),
              actions: [
                IconButton(
                  icon: const Icon(Icons.person_add),
                  tooltip: 'Invite Users',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FindUsersScreen(groupId: widget.groupId, groupName: widget.groupName),
                      ),
                    );
                  },
                ),
                if (user != null) // Only show menu if user is loaded
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'leave') {
                        _leaveGroup(viewModel, user.uid);
                      } else if (value == 'delete') {
                        _deleteGroup(viewModel);
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'leave',
                        child: Text('Leave Group'),
                      ),
                      if (viewModel.group != null && viewModel.group!.createdByUid == user.uid)
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text(
                            'Delete Group',
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            body: user == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Members Section ---
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('Members', style: Theme.of(context).textTheme.titleLarge),
                      ),
                      _buildMembersList(viewModel),

                      const Divider(),

                      // --- Activities Section ---
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                        child: Text('Activities', style: Theme.of(context).textTheme.titleLarge),
                      ),
                      Expanded(child: _buildActivitiesList(context, viewModel, user)),
                    ],
                  ),
            floatingActionButton: FloatingActionButton(
              // --- MODIFIED: Pass consumer context and viewModel ---
              onPressed: () => _addActivityDefinitionDialog(context, viewModel),
              tooltip: 'Add Activity',
              child: const Icon(Icons.add),
            ),
          );
        },
      ),
    );
  }

  // Helper to build Members List
  Widget _buildMembersList(GroupDetailsViewModel viewModel) {
     if (viewModel.isLoadingMembers) {
       return const Padding(
         padding: EdgeInsets.symmetric(vertical: 8.0),
         child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
       );
     }
     if (viewModel.members.isEmpty && viewModel.group != null) {
       // Trigger fetch if members list is empty but group exists
        WidgetsBinding.instance.addPostFrameCallback((_) {
          viewModel.fetchMembers();
        });
        return const Padding(
         padding: EdgeInsets.symmetric(vertical: 8.0),
         child: Center(child: Text("Loading members...")),
       );
     }
     if (viewModel.members.isEmpty) {
       return const Padding(
         padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
         child: Text("No members found."),
       );
     }

     return SizedBox(
       height: 60, // Adjust height as needed
       child: ListView.builder(
         scrollDirection: Axis.horizontal,
         padding: const EdgeInsets.symmetric(horizontal: 12.0),
         itemCount: viewModel.members.length,
         itemBuilder: (context, index) {
           final member = viewModel.members[index];
           return Padding(
             padding: const EdgeInsets.symmetric(horizontal: 4.0),
             child: Chip(
               avatar: CircleAvatar(
                 child: Text(member.displayName?.substring(0, 1).toUpperCase() ?? member.email?.substring(0, 1).toUpperCase() ?? '?'),
               ),
               label: Text(member.displayName ?? member.email ?? 'Unknown'),
             ),
           );
         },
       ),
     );
  }

  // Helper to build Activities List
  Widget _buildActivitiesList(BuildContext context, GroupDetailsViewModel viewModel, User currentUser) {
    return StreamBuilder<List<Activity>>(
      stream: viewModel.firestoreService.getActivitiesStream(widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final activities = snapshot.data ?? [];
        if (activities.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No activity types defined for this group yet.\nTap the + button to add some!',
                 textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            final bool canDelete = activity.createdByUid == currentUser.uid;

            return Dismissible(
              key: Key(activity.id),
              direction: canDelete ? DismissDirection.endToStart : DismissDirection.none,
              background: Container(
                color: Theme.of(context).colorScheme.error,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Icon(
                  Icons.delete,
                  color: Theme.of(context).colorScheme.onError,
                ),
              ),
              confirmDismiss: (direction) async {
                if (!canDelete) return false;
                return await _showConfirmationDialog(
                  'Delete Activity?',
                  'Are you sure you want to delete "${activity.name}"?',
                );
              },
              onDismissed: (direction) {
                if (canDelete) {
                  viewModel.deleteActivity(activity.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Activity "${activity.name}" deleted')),
                  );
                }
              },
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text(activity.name),
                  subtitle: Text('Added ${DateFormat.yMd().add_jm().format(activity.createdAt.toDate())}'),
                  leading: const Icon(Icons.directions_run), // Example Icon
                  trailing: ElevatedButton(
                     child: const Text('Keen?'),
                     onPressed: () {
                       _showTimeSelectionDialog(context, viewModel, activity, currentUser);
                     },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Time Selection Dialog ---
  void _showTimeSelectionDialog(
      BuildContext context,
      GroupDetailsViewModel viewModel,
      Activity activity,
      User currentUser) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Start "${activity.name}"?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notify group you are starting:'),
              const SizedBox(height: 10),
               Wrap(
                 spacing: 8,
                 runSpacing: 8,
                 children: [
                   _TimeOptionButton(
                     label: 'Now',
                     onPressed: () => _handleTimeSelection(context, dialogContext, viewModel, activity, currentUser, 0, 'now'),
                   ),
                   _TimeOptionButton(
                     label: 'In 5 min',
                     onPressed: () => _handleTimeSelection(context, dialogContext, viewModel, activity, currentUser, 5, 'in 5 minutes'),
                   ),
                    _TimeOptionButton(
                     label: 'In 15 min',
                     onPressed: () => _handleTimeSelection(context, dialogContext, viewModel, activity, currentUser, 15, 'in 15 minutes'),
                   ),
                    _TimeOptionButton(
                     label: 'In 30 min',
                     onPressed: () => _handleTimeSelection(context, dialogContext, viewModel, activity, currentUser, 30, 'in 30 minutes'),
                   ),
                   _TimeOptionButton(
                     label: 'In 1 hour',
                     onPressed: () => _handleTimeSelection(context, dialogContext, viewModel, activity, currentUser, 60, 'in 1 hour'),
                   ),
                 ],
               )

            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // --- Handle Time Selection ---
  void _handleTimeSelection(
    BuildContext mainPageContext,
    BuildContext dialogContext, // Context from the dialog
    GroupDetailsViewModel viewModel,
    Activity activity,
    User currentUser,
    int minutesFromNow,
    String timeDescription,
  ) async {
    final activationTime = DateTime.now().add(Duration(minutes: minutesFromNow));
    final userName = currentUser.displayName ?? currentUser.email ?? 'Someone';
    
    final scaffoldMessenger = ScaffoldMessenger.of(mainPageContext);
    
    try {
      Navigator.pop(dialogContext);
      scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Notifying group about "${activity.name}" $timeDescription...'))
      );

      await viewModel.activateActivity(
        activityId: activity.id,
        activityName: activity.name,
        userId: currentUser.uid,
        userName: userName,
        activationTime: activationTime,
        timeDescription: timeDescription,
      );

      scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Notification process triggered!'))
      );

    } catch (e) {
      scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'))
      );
    }
  }
}     

class _TimeOptionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _TimeOptionButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}