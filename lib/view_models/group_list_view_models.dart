// lib/view_models/group_list_view_model.dart
import 'package:flut1/firestore_service.dart';
import 'package:flutter/material.dart'; // For ChangeNotifier if needed later

// Using a simple class for now, can be upgraded to ChangeNotifier if complex state arises
class GroupListViewModel {
  final FirestoreService _firestoreService = FirestoreService();

  FirestoreService get firestoreService => _firestoreService;

  Future<void> createGroup(String groupName, String createdByUid) async {
    if (groupName.isNotEmpty) {
      await _firestoreService.createGroup(groupName, createdByUid);
    }
    // Add error handling if needed
  }

  Future<void> inviteUserToGroup(String groupId, String userEmail) async {
     if (userEmail.isNotEmpty) {
       await _firestoreService.inviteUserToGroup(groupId, userEmail);
     }
     // Error handling is done in the dialog for immediate feedback
  }

   // Method to add a new activity *definition*
  Future<void> addActivityDefinition(String groupId, String activityName, String createdByUid) async {
    if (activityName.isNotEmpty) {
      await _firestoreService.addActivityToGroup(groupId, activityName, createdByUid);
    }
     // Add error handling if needed
  }
}