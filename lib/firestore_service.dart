// lib/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- USER METHODS ---
  Future<void> createUser(User user, String fcmToken, {String? username}) async {
    final userRef = _db.collection('users').doc(user.uid);
    final userData = {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'username': username,
      'fcmTokens': [fcmToken],
    };
    final docSnapshot = await userRef.get();
    if (!docSnapshot.exists) {
      await userRef.set(userData);
      print("Firestore document created for user: ${user.uid}");
    } else {
      print("Firestore document already exists for user: ${user.uid}");
      await userRef.update({'fcmTokens': FieldValue.arrayUnion([fcmToken])});
      print("Updated FCM token for existing user: ${user.uid}");
    }
  }

  Future<bool> isUsernameAvailable(String username) async {
    final query = await _db.collection('users').where('username', isEqualTo: username).limit(1).get();
    return query.docs.isEmpty;
  }

  Future<void> setUsername(String uid, String username) async {
    await _db.collection('users').doc(uid).update({'username': username});
  }

  Future<void> updateUserToken(String uid, String fcmToken) async {
    final userRef = _db.collection('users').doc(uid);
    try {
      await userRef.update({'fcmTokens': FieldValue.arrayUnion([fcmToken])});
      print("Updated/Added FCM token for user: $uid");
    } catch (e) {
      if (e is FirebaseException && e.code == 'not-found') {
        print("User document $uid not found, cannot update token.");
        // This might happen for anonymous users, let's try set with merge
        await userRef.set({'fcmTokens': FieldValue.arrayUnion([fcmToken])}, SetOptions(merge: true));
        print("Created/merged user document $uid with FCM token.");
      } else {
        print("Error updating FCM token for user $uid: $e");
      }
    }
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return AppUser.fromDoc(doc);
    }
    return null;
  }

  Stream<AppUser?> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return AppUser.fromDoc(doc);
      }
      return null;
    });
  }

  Future<AppUser?> findUserByEmailOrUsername(String identifier) async {
    QuerySnapshot query;
    if (identifier.contains('@')) {
      query = await _db.collection('users').where('email', isEqualTo: identifier).limit(1).get();
    } else {
      query = await _db.collection('users').where('username', isEqualTo: identifier).limit(1).get();
    }

    if (query.docs.isNotEmpty) {
      return AppUser.fromDoc(query.docs.first);
    }
    return null;
  }

  // --- GROUP METHODS ---
  Future<DocumentReference> createGroup(String groupName, String createdByUid) async {
    return await _db.collection('groups').add({
      'name': groupName,
      'createdByUid': createdByUid,
      'memberUids': [createdByUid],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createGroupInvitation(String groupId, String groupName, String invitedByUid, String targetUserId) async {
    // Check if user is already a member
    final groupDoc = await _db.collection('groups').doc(groupId).get();
    if (groupDoc.exists) {
      final group = Group.fromDoc(groupDoc);
      if (group.memberUids.contains(targetUserId)) {
        throw Exception('User is already in this group');
      }
    }

    // Check for existing pending invitation
    final existingInvite = await _db.collection('invitations')
      .where('groupId', isEqualTo: groupId)
      .where('invitedUser', isEqualTo: targetUserId)
      .where('status', isEqualTo: 'pending')
      .limit(1)
      .get();
    
    if (existingInvite.docs.isNotEmpty) {
      throw Exception('Invitation has already been sent');
    }

    await _db.collection('invitations').add({
      'groupId': groupId,
      'groupName': groupName,
      'invitedBy': invitedByUid,
      'invitedUser': targetUserId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<GroupInvitation>> getInvitationsStream(String uid) {
    return _db
        .collection('invitations')
        .where('invitedUser', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => GroupInvitation.fromDoc(doc)).toList());
  }

  Future<void> acceptInvitation(String invitationId, String uid, String groupId) async {
    WriteBatch batch = _db.batch();

    // Add user to group
    final groupRef = _db.collection('groups').doc(groupId);
    batch.update(groupRef, {'memberUids': FieldValue.arrayUnion([uid])});

    // Update invitation status
    final invitationRef = _db.collection('invitations').doc(invitationId);
    batch.update(invitationRef, {'status': 'accepted'});
    
    await batch.commit();
  }

  Future<void> declineInvitation(String invitationId) async {
    await _db.collection('invitations').doc(invitationId).update({
      'status': 'declined',
    });
  }

  Stream<List<Group>> getGroupsStream(String uid) {
    return _db
        .collection('groups')
        .where('memberUids', arrayContains: uid)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Group.fromDoc(doc)).toList());
  }

  Stream<Group?> getGroupStream(String groupId) {
     return _db
         .collection('groups')
         .doc(groupId)
         .snapshots()
         .map((doc) => doc.exists ? Group.fromDoc(doc) : null);
  }

  // --- NEW: Leave Group ---
  Future<void> leaveGroup(String groupId, String uid) async {
    await _db.collection('groups').doc(groupId).update({
      'memberUids': FieldValue.arrayRemove([uid]),
    });
    // TODO: Consider what happens if the creator leaves.
    // TODO: Consider deleting the group if the last member leaves.
  }

  // --- NEW: Delete Group ---
  Future<void> deleteGroup(String groupId) async {
    await _db.collection('groups').doc(groupId).delete();
    // WARNING: This is a shallow delete. Subcollections (activities,
    // activations, responses) will NOT be deleted. A Cloud Function
    // is required to recursively delete subcollections.
  }

  // --- ACTIVITY METHODS ---
  Future<void> addActivityToGroup(
    String groupId,
    String activityName,
    String createdByUid,
  ) async {
    try {
      await _db.collection('groups').doc(groupId).collection('activities').add({
        'name': activityName,
        'createdByUid': createdByUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('Activity "$activityName" definition created in group $groupId');
    } catch (e) {
      print('Error creating activity definition: $e');
      rethrow;
    }
  }

  // --- NEW: Delete Activity ---
  Future<void> deleteActivity(String groupId, String activityId) async {
    await _db.collection('groups').doc(groupId)
      .collection('activities').doc(activityId)
      .delete();
    // This also performs a shallow delete. Activations and responses
    // for this activity will remain. A Cloud Function is better.
  }

  Stream<List<Activity>> getActivitiesStream(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('activities')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Activity.fromDoc(doc)).toList());
  }

  Future<void> activateActivityAndNotify(
      {required String groupId,
      required String activityId,
      required String activityName,
      required String userId,
      required String userName,
      required DateTime activationTime,
      required String timeDescription
      }) async {

    try {
      final activationData = {
          'userId': userId,
          'userName': userName,
          'activationTime': Timestamp.fromDate(activationTime),
          'timeDescription': timeDescription,
          'activityName': activityName,
          'groupId': groupId,
          'activityId': activityId,
          'triggeredAt': FieldValue.serverTimestamp(),
        };

      await _db.collection('groups').doc(groupId)
        .collection('activities').doc(activityId)
        .collection('activations').add(activationData);

      print('Activation record created in Firestore for Cloud Function trigger.');

    } catch (e) {
      print('Error writing activation record: $e');
      throw Exception('Could not trigger notification process.');
    }
  }

   Future<void> respondToActivity({
    required String groupId,
    required String activityId,
    required String uid,
    required bool isKeen,
  }) async {
    final responseRef = _db
        .collection('groups')
        .doc(groupId)
        .collection('activities')
        .doc(activityId)
        .collection('responses')
        .doc(uid);

    await responseRef.set({
      'isKeen': isKeen,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ActivityResponse>> getActivityResponsesStream(
      String groupId, String activityId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('activities')
        .doc(activityId)
        .collection('responses')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ActivityResponse.fromDoc(doc)).toList());
  }

  Stream<List<ActivityResponse>> getKeenResponsesStream(
      String groupId, String activityId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('activities')
        .doc(activityId)
        .collection('responses')
        .where('isKeen', isEqualTo: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ActivityResponse.fromDoc(doc)).toList());
  }
}