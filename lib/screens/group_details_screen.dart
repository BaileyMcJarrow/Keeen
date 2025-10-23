// lib/screens/group_details_screen.dart
import 'package:flut1/models.dart';
import 'package:flut1/view_models/group_details_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For formatting time

class GroupDetailsScreen extends StatelessWidget {
  final String groupId;
  final String groupName;

  const GroupDetailsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  Widget build(BuildContext context) {
    // Provide the ViewModel for this screen
    return ChangeNotifierProvider(
      create: (_) => GroupDetailsViewModel(groupId),
      child: Consumer<GroupDetailsViewModel>(
        builder: (context, viewModel, child) {
          final user = Provider.of<User?>(context); // Get current user

          return Scaffold(
            appBar: AppBar(
              title: Text(groupName),
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
      stream: viewModel.firestoreService.getActivitiesStream(groupId),
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
                'No activity types defined for this group yet.\nGo back and add some!',
                 textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                title: Text(activity.name),
                subtitle: Text('Added ${DateFormat.yMd().add_jm().format(activity.createdAt.toDate())}'), // Show creation time
                leading: const Icon(Icons.directions_run), // Example Icon
                trailing: ElevatedButton(
                   child: const Text('Keen?'),
                   onPressed: () {
                     _showTimeSelectionDialog(context, viewModel, activity, currentUser);
                   },
                ),
                // Or make the whole tile tappable:
                // onTap: () {
                //   _showTimeSelectionDialog(context, viewModel, activity, currentUser);
                // },
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
              // Use Expanded + ListView if options get long
               Wrap(
                 spacing: 8,
                 runSpacing: 8,
                 children: [
                   _TimeOptionButton(
                     label: 'Now',
                     onPressed: () => _handleTimeSelection(dialogContext, viewModel, activity, currentUser, 0, 'now'),
                   ),
                   _TimeOptionButton(
                     label: 'In 5 min',
                     onPressed: () => _handleTimeSelection(dialogContext, viewModel, activity, currentUser, 5, 'in 5 minutes'),
                   ),
                    _TimeOptionButton(
                     label: 'In 15 min',
                     onPressed: () => _handleTimeSelection(dialogContext, viewModel, activity, currentUser, 15, 'in 15 minutes'),
                   ),
                    _TimeOptionButton(
                     label: 'In 30 min',
                     onPressed: () => _handleTimeSelection(dialogContext, viewModel, activity, currentUser, 30, 'in 30 minutes'),
                   ),
                   _TimeOptionButton(
                     label: 'In 1 hour',
                     onPressed: () => _handleTimeSelection(dialogContext, viewModel, activity, currentUser, 60, 'in 1 hour'),
                   ),
                   // Add more options if needed
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
    BuildContext dialogContext, // Context from the dialog
    GroupDetailsViewModel viewModel,
    Activity activity,
    User currentUser,
    int minutesFromNow,
    String timeDescription,
  ) async {
    final activationTime = DateTime.now().add(Duration(minutes: minutesFromNow));
    final userName = currentUser.displayName ?? currentUser.email ?? 'Someone'; // Get user's name

    try {
      // Close the time dialog first
      Navigator.pop(dialogContext);

       // Show a confirmation or loading indicator
       ScaffoldMessenger.of(dialogContext).showSnackBar(
           SnackBar(content: Text('Notifying group about "${activity.name}" $timeDescription...')),
       );


      await viewModel.activateActivity(
        activityId: activity.id,
        activityName: activity.name,
        userId: currentUser.uid,
        userName: userName,
        activationTime: activationTime,
        timeDescription: timeDescription,
      );

      // Confirmation feedback (optional, depends if activateActivity throws)
       ScaffoldMessenger.of(dialogContext).showSnackBar(
           const SnackBar(content: Text('Notification process triggered!')),
       );

    } catch (e) {
      // Show error if activation fails
       ScaffoldMessenger.of(dialogContext).showSnackBar(
           SnackBar(content: Text('Error: ${e.toString()}')),
       );
    }
  }
}


// Simple button for time options - Copied from previous home_screen
class _TimeOptionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _TimeOptionButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton( // Changed to ElevatedButton for better visibility
      onPressed: onPressed,
      child: Text(label),
    );
  }
}