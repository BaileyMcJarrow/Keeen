// lib/screens/find_users_screen.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flut1/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FindUsersScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const FindUsersScreen({super.key, required this.groupId, required this.groupName});

  @override
  _FindUsersScreenState createState() => _FindUsersScreenState();
}

class _FindUsersScreenState extends State<FindUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _users = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchUsers(""); // Fetch all users on initial load
  }

  Future<void> _searchUsers(String query) async {
    // Removed the check for empty query.
    // We now assume the backend returns all users for an empty query.

    setState(() {
      _isLoading = true;
    });

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'africa-south1').httpsCallable('searchUsers');
      final results = await callable.call(<String, dynamic>{
        'search': query,
      });
      setState(() {
        _users = results.data['users'];
        _isLoading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      print('Error calling searchUsers function: ${e.message}');
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('An unknown error occurred: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _inviteUser(String targetUserId) async {
    final user = Provider.of<User?>(context, listen: false);
    if (user == null) return;

    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await firestoreService.createGroupInvitation(
        widget.groupId,
        widget.groupName,
        user.uid,
        targetUserId,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Invitation sent!')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error sending invitation: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Users to Invite'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by username or email',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchUsers(_searchController.text),
                ),
              ),
              onChanged: _searchUsers, // Searches as user types
              autofocus: true,
            ),
          ),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Expanded(
                  child: ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      // TODO: Add a check here to prevent inviting users already in the group
                      return ListTile(
                        title: Text(user['displayName'] ?? user['email'] ?? 'Unknown'),
                        subtitle: Text(user['email'] ?? ''),
                        trailing: ElevatedButton(
                          child: const Text('Invite'),
                          onPressed: () => _inviteUser(user['uid']),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}