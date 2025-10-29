import 'package:flut1/firestore_service.dart';

class GroupListViewModel {
  final FirestoreService _firestoreService = FirestoreService();

  FirestoreService get firestoreService => _firestoreService;

  Future<void> createGroup(String groupName, String createdByUid) async {
    if (groupName.isNotEmpty) {
      await _firestoreService.createGroup(groupName, createdByUid);
    }
  }

  Future<void> inviteUser(String groupId, String groupName, String invitedByUid, String identifier) async {
    if (identifier.isNotEmpty) {
      final user = await _firestoreService.findUserByEmailOrUsername(identifier);
      if (user != null) {
        await _firestoreService.createGroupInvitation(groupId, groupName, invitedByUid, user.uid);
      } else {
        throw Exception('User not found');
      }
    }
  }

  Future<void> acceptInvitation(String invitationId, String uid, String groupId) async {
    await _firestoreService.acceptInvitation(invitationId, uid, groupId);
  }

  Future<void> declineInvitation(String invitationId) async {
    await _firestoreService.declineInvitation(invitationId);
  }

  Future<void> addActivityDefinition(String groupId, String activityName, String createdByUid) async {
    if (activityName.isNotEmpty) {
      await _firestoreService.addActivityToGroup(groupId, activityName, createdByUid);
    }
  }
}