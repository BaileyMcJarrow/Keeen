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
      // Use arrayUnion to add the token only if it's not already present
      // Consider adding logic to remove old/invalid tokens if necessary
      await userRef.update({'fcmTokens': FieldValue.arrayUnion([fcmToken])});
      print("Updated/Added FCM token for user: $uid");
    } catch (e) {
      // If the document doesn't exist, create it (optional, depends on flow)
      if (e is FirebaseException && e.code == 'not-found') {
        print("User document $uid not found, cannot update token.");
        // Decide if you want to create the user doc here or handle elsewhere
      } else {
        print("Error updating FCM token for user $uid: $e");
      }
    }
  }

  // getUser remains the same
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

  // getGroupStream remains the same
  Stream<Group?> getGroupStream(String groupId) {
     return _db
         .collection('groups')
         .doc(groupId)
         .snapshots()
         .map((doc) => doc.exists ? Group.fromDoc(doc) : null);
  }

  // --- ACTIVITY METHODS ---
  // addActivityToGroup remains the same
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

  // getActivitiesStream remains the same
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

  // ** UPDATED: Method to trigger the Cloud Function by writing activation data **
  Future<void> activateActivityAndNotify(
      {required String groupId,
      required String activityId,
      required String activityName,
      required String userId,
      required String userName,
      required DateTime activationTime,
      required String timeDescription
      }) async {

    // --- Write activation record to Firestore to trigger Cloud Function ---
    try {
      final activationData = {
          'userId': userId, // User who activated
          'userName': userName, // Their display name
          'activationTime': Timestamp.fromDate(activationTime), // When the activity starts
          'timeDescription': timeDescription, // e.g., "in 5 minutes"
          'activityName': activityName, // Name of the activity
          'groupId': groupId, // Group context
          'activityId': activityId, // Activity context
          'triggeredAt': FieldValue.serverTimestamp(), // Firestore server time
        };

      // Write to: /groups/{groupId}/activities/{activityId}/activations/{new_doc_id}
      await _db.collection('groups').doc(groupId)
        .collection('activities').doc(activityId)
        .collection('activations').add(activationData);

      print('Activation record created in Firestore for Cloud Function trigger.');

    } catch (e) {
      print('Error writing activation record: $e');
      // Let the UI know something went wrong
      throw Exception('Could not trigger notification process.');
    }

    // --- Keep Simulation for local feedback ---
    print('--- NOTIFICATION TRIGGER SIMULATION (Firestore write initiated) ---');
    print('User: $userName ($userId)');
    print('Group: $groupId');
    print('Activity: $activityName ($activityId)');
    print('Is starting "$activityName" $timeDescription ($activationTime)');
    print('Cloud Function should now process this Firestore event.');
    print('-------------------------------------');
  }


  // respondToActivity, getActivityResponsesStream, getKeenResponsesStream remain the same
  // (You might use these later for tracking who acknowledged the notification)
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