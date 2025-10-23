// lib/view_models/group_details_view_model.dart
import 'dart:async';
import 'package:flut1/firestore_service.dart';
import 'package:flut1/models.dart';
import 'package:flutter/material.dart';

class GroupDetailsViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final String groupId;

  Group? _group;
  Group? get group => _group;

  List<AppUser> _members = [];
  List<AppUser> get members => _members;

  bool _isLoadingMembers = false;
  bool get isLoadingMembers => _isLoadingMembers;

  StreamSubscription? _groupSubscription;

  GroupDetailsViewModel(this.groupId) {
    _listenToGroup();
  }

  FirestoreService get firestoreService => _firestoreService;

  void _listenToGroup() {
    _groupSubscription?.cancel();
    _groupSubscription = _firestoreService.getGroupStream(groupId).listen((groupData) {
      if (groupData != null && _group?.memberUids.length != groupData.memberUids.length) {
         _group = groupData;
         fetchMembers(); // Refetch members if the list changes
      } else {
         _group = groupData;
      }
      notifyListeners(); // Notify UI about group data change
    });
  }


  Future<void> fetchMembers() async {
    if (_group == null || _isLoadingMembers) return;

    _isLoadingMembers = true;
    notifyListeners();

    List<AppUser> fetchedMembers = [];
    for (String uid in _group!.memberUids) {
      final user = await _firestoreService.getUser(uid);
      if (user != null) {
        fetchedMembers.add(user);
      } else {
         // Add a placeholder if user data is missing
         fetchedMembers.add(AppUser(uid: uid, email: 'Unknown User', displayName: uid.substring(0, 6)));
      }
    }
    _members = fetchedMembers;
    _isLoadingMembers = false;
    notifyListeners();
  }


  Future<void> activateActivity({
      required String activityId,
      required String activityName,
      required String userId,
      required String userName,
      required DateTime activationTime,
      required String timeDescription
    }) async {
     try {
        await _firestoreService.activateActivityAndNotify(
          groupId: groupId,
          activityId: activityId,
          activityName: activityName,
          userId: userId,
          userName: userName, // Pass user's name
          activationTime: activationTime,
          timeDescription: timeDescription,
        );
        // Optionally show success feedback
     } catch (e) {
       print("Error activating activity: $e");
       // Optionally show error feedback
       throw Exception("Failed to activate activity: $e");
     }
  }

   @override
  void dispose() {
    _groupSubscription?.cancel();
    super.dispose();
  }
}