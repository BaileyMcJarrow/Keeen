// lib/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- USER METHODS ---
  // createUser remains the same
  Future<void> createUser(User user, String fcmToken) async {
    final userRef = _db.collection('users').doc(user.uid);
    final userData = {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
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

  // updateUserToken remains the same
  Future<void> updateUserToken(String uid, String fcmToken) async {
    final userRef = _db.collection('users').doc(uid);
    try {
      await userRef.update({'fcmTokens': FieldValue.arrayUnion([fcmToken])});
      print("Updated FCM token for user: $uid");
    } catch (e) {
      print("Error updating FCM token for user $uid: $e");
    }
  }

  // Helper to get user details - needed for displaying member names
  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return AppUser.fromDoc(doc);
    }
    return null;
  }

  // --- GROUP METHODS ---
  // createGroup remains the same
  Future<DocumentReference> createGroup(String groupName, String createdByUid) async {
    return await _db.collection('groups').add({
      'name': groupName,
      'createdByUid': createdByUid,
      'memberUids': [createdByUid],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // inviteUserToGroup remains the same
  Future<void> inviteUserToGroup(String groupId, String userEmail) async {
    final userQuery = await _db.collection('users').where('email', isEqualTo: userEmail).limit(1).get();
    if (userQuery.docs.isNotEmpty) {
      final userId = userQuery.docs.first.id;
      await _db.collection('groups').doc(groupId).update({
        'memberUids': FieldValue.arrayUnion([userId]),
      });
    } else {
      throw Exception('User with email $userEmail not found');
    }
  }

  // getGroupsStream remains the same
  Stream<List<Group>> getGroupsStream(String uid) {
    return _db
        .collection('groups')
        .where('memberUids', arrayContains: uid)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Group.fromDoc(doc)).toList());
  }

  // Get details for a single group
  Stream<Group?> getGroupStream(String groupId) {
     return _db
         .collection('groups')
         .doc(groupId)
         .snapshots()
         .map((doc) => doc.exists ? Group.fromDoc(doc) : null);
  }

  // --- ACTIVITY METHODS ---

  // MODIFIED: No longer takes activityTime
  Future<void> addActivityToGroup(
    String groupId,
    String activityName,
    String createdByUid,
  ) async {
    try {
      await _db.collection('groups').doc(groupId).collection('activities').add({
        'name': activityName,
        'createdByUid': createdByUid,
        'createdAt': FieldValue.serverTimestamp(), // Store creation time
        // 'activityTime' is removed
      });
      print('Activity "$activityName" definition created in group $groupId');
    } catch (e) {
      print('Error creating activity definition: $e');
      rethrow;
    }
  }

  // Get activities for a group
  Stream<List<Activity>> getActivitiesStream(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('activities')
        .orderBy('createdAt', descending: true) // Order by creation time
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Activity.fromDoc(doc)).toList());
  }

  // NEW: Method to signify an activity is being started
  // This is where you'd trigger the Cloud Function in a real app
  Future<void> activateActivityAndNotify(
      {required String groupId,
      required String activityId,
      required String activityName,
      required String userId,
      required String userName, // User display name for notification
      required DateTime activationTime,
      required String timeDescription // e.g., "in 5 minutes"
      }) async {
    // Placeholder: In a real app, you would likely call a Cloud Function here.
    // The function would then fetch member tokens and send FCM messages.
    print(
        '--- NOTIFICATION SIMULATION ---');
    print('User: $userName ($userId)');
    print('Group: $groupId');
    print('Activity: $activityName ($activityId)');
    print('Is starting "$activityName" $timeDescription ($activationTime)');
    print('Needs to notify other members via Cloud Function.');
    print('-----------------------------');

    // Optionally, you could store the activation event in Firestore for history
    // For example, in a subcollection under the activity:
    // await _db.collection('groups').doc(groupId)
    //   .collection('activities').doc(activityId)
    //   .collection('activations').add({
    //     'userId': userId,
    //     'userName': userName,
    //     'activationTime': Timestamp.fromDate(activationTime),
    //     'timeDescription': timeDescription,
    //   });
  }

  // respondToActivity might be repurposed or removed depending on final logic
  // For now, it's kept but might not be directly used in the new flow.
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

  // getActivityResponsesStream and getKeenResponsesStream might also be repurposed/removed
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