
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';
import '../firestore_service.dart';
import '../view_models/group_details_view_model.dart';

class InvitationDetailsScreen extends StatelessWidget {
  final GroupInvitation invitation;

  const InvitationDetailsScreen({super.key, required this.invitation});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final user = Provider.of<User?>(context, listen: false);

    return ChangeNotifierProvider(
      create: (_) => GroupDetailsViewModel(invitation.groupId),
      child: Consumer<GroupDetailsViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Invitation to ${invitation.groupName}'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            body: viewModel.isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You have been invited to join the group "${invitation.groupName}".',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 20),
                        _buildMembersList(context, viewModel), // Pass context
                        const SizedBox(height: 20),
                        _buildActivitiesList(context, viewModel), // Pass context
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.secondary,
                                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () async {
                                await firestoreService.acceptInvitation(invitation.id, user!.uid, invitation.groupId);
                                Navigator.pop(context);
                              },
                              child: const Text('Accept', style: TextStyle(fontSize: 16)),
                            ),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Theme.of(context).colorScheme.error),
                                foregroundColor: Theme.of(context).colorScheme.error,
                                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () async {
                                await firestoreService.declineInvitation(invitation.id);
                                Navigator.pop(context);
                              },
                              child: const Text('Decline', style: TextStyle(fontSize: 16)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildMembersList(BuildContext context, GroupDetailsViewModel viewModel) {
    if (viewModel.isLoadingMembers) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.members.isEmpty) {
      return const Text('No members yet.', style: TextStyle(color: Colors.grey));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current Members:',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: viewModel.members
              .map((member) => Chip(
                    avatar: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                      child: Text(member.displayName?.substring(0, 1).toUpperCase() ?? member.email?.substring(0, 1).toUpperCase() ?? '?',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer)),
                    ),
                    label: Text(member.displayName ?? member.email ?? 'Unknown'),
                    backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildActivitiesList(BuildContext context, GroupDetailsViewModel viewModel) {
    return StreamBuilder<List<Activity>>(
      stream: viewModel.firestoreService.getActivitiesStream(viewModel.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No activities defined for this group yet.', style: TextStyle(color: Colors.grey));
        }
        final activities = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activities in Group:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(), // to prevent nested scrolling issues
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final activity = activities[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    leading: Icon(Icons.local_activity, color: Theme.of(context).colorScheme.primary),
                    title: Text(activity.name),
                    subtitle: Text('Added by ${activity.createdByUid.substring(0, 6)}...'), // Placeholder for created by user
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
