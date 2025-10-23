import 'package:cloud_firestore/cloud_firestore.dart';
// Import the renamed AppUser if you need it elsewhere, otherwise remove if unused
import 'models.dart'; 
// IMPORT FIREBASE AUTH USER explicitly
import 'package:firebase_auth/firebase_auth.dart' show User;

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- USER METHODS ---
  
  // Create a new user document when they sign up
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
       // Optionally update the FCM token array here
       await userRef.update({'fcmTokens': FieldValue.arrayUnion([fcmToken])});
       print("Updated FCM token for existing user: ${user.uid}");
    }
  }

  Future<void> updateUserToken(String uid, String fcmToken) async {
    final userRef = _db.collection('users').doc(uid);
    try {
      // Atomically add the new token to the array if it doesn't exist
      await userRef.update({
        'fcmTokens': FieldValue.arrayUnion([fcmToken])
      });
      print("Updated FCM token for user: $uid");
    } catch (e) {
      print("Error updating FCM token for user $uid: $e");
      // Consider more robust error handling if needed
    }
  }

  // --- GROUP METHODS ---

  Future<DocumentReference> createGroup(String groupName, String createdByUid) async {
    return await _db.collection('groups').add({
      'name': groupName,
      'createdByUid': createdByUid,
      'memberUids': [createdByUid], // Creator is the first member
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  
  Future<void> inviteUserToGroup(String groupId, String userEmail) async {
    // 1. Find user by email
    final userQuery = await _db.collection('users').where('email', isEqualTo: userEmail).limit(1).get();
    
    if (userQuery.docs.isNotEmpty) {
      final userId = userQuery.docs.first.id;
      // 2. Add user's UID to the group's member list
      await _db.collection('groups').doc(groupId).update({
        'memberUids': FieldValue.arrayUnion([userId]),
      });
    } else {
      throw Exception('User not found');
    }
  }

  // Get a stream of groups for the current user
  Stream<List<Group>> getGroupsStream(String uid) {
    return _db
        .collection('groups')
        .where('memberUids', arrayContains: uid)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Group.fromDoc(doc)).toList());
  }

  // --- ACTIVITY METHODS ---
  
  Future<void> addActivityToGroup(String groupId, String activityName, String createdByUid, DateTime activityTime) async {
    await _db.collection('groups').doc(groupId).collection('activities').add({
      'name': activityName,
      'createdByUid': createdByUid,
      'activityTime': Timestamp.fromDate(activityTime),
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // TODO: This is where you trigger a Push Notification!
    // You would call a Cloud Function here, passing the groupId and activityName.
    // The Cloud Function would then get all fcmTokens for users in the group
    // (except the creator) and send them a message.
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
        .doc(uid); // Use user's UID as the document ID

    await responseRef.set({
      'isKeen': isKeen,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get a stream of all responses for a specific activity
  Stream<List<ActivityResponse>> getActivityResponsesStream(String groupId, String activityId) {
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
  
  // Get a stream of just the "keen" responses
  Stream<List<ActivityResponse>> getKeenResponsesStream(String groupId, String activityId) {
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