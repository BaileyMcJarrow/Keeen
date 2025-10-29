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

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isLoadingMembers = false;
  bool get isLoadingMembers => _isLoadingMembers;

  StreamSubscription? _groupSubscription;

  GroupDetailsViewModel(this.groupId) {
    _listenToGroup();
    _fetchInitialData();
  }

  FirestoreService get firestoreService => _firestoreService;

  Future<void> _fetchInitialData() async {
    _isLoading = true;
    notifyListeners();
    // The _listenToGroup will handle setting _group and calling fetchMembers
    await Future.delayed(const Duration(milliseconds: 500)); 
    _isLoading = false;
    notifyListeners();
  }

  void _listenToGroup() {
    _groupSubscription?.cancel();
    _groupSubscription = _firestoreService.getGroupStream(groupId).listen((groupData) {
      if (groupData != null) {
         bool membersChanged = _group == null || _group?.memberUids.length != groupData.memberUids.length;
         _group = groupData;
         if (membersChanged) {
            fetchMembers(); // Refetch members if the list changes
         }
      } else {
         _group = null; // Group was deleted
      }
      _isLoading = false;
      notifyListeners();
    });
  }


  Future<void> fetchMembers() async {
    if (_group == null) {
      _members = [];
      notifyListeners();
      return;
    }
    
    _isLoadingMembers = true;
    notifyListeners();

    List<AppUser> fetchedMembers = [];
    for (String uid in _group!.memberUids) {
      final user = await _firestoreService.getUser(uid);
      if (user != null) {
        fetchedMembers.add(user);
      } else {
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
          userName: userName,
          activationTime: activationTime,
          timeDescription: timeDescription,
        );
     } catch (e) {
       print("Error activating activity: $e");
       throw Exception("Failed to activate activity: $e");
     }
  }

  Future<void> addActivityDefinition(String activityName, String createdByUid) async {
    if (activityName.isNotEmpty) {
      await _firestoreService.addActivityToGroup(groupId, activityName, createdByUid);
    }
  }

  // --- NEW METHODS ---

  Future<void> leaveGroup(String uid) async {
    try {
      await _firestoreService.leaveGroup(groupId, uid);
    } catch (e) {
      print("Error leaving group: $e");
      throw Exception("Failed to leave group: $e");
    }
  }

  Future<void> deleteGroup() async {
    try {
      await _firestoreService.deleteGroup(groupId);
    } catch (e) {
      print("Error deleting group: $e");
      throw Exception("Failed to delete group: $e");
    }
  }

  Future<void> deleteActivity(String activityId) async {
     try {
      await _firestoreService.deleteActivity(groupId, activityId);
    } catch (e) {
      print("Error deleting activity: $e");
      throw Exception("Failed to delete activity: $e");
    }
  }

   @override
  void dispose() {
    _groupSubscription?.cancel();
    super.dispose();
  }
}