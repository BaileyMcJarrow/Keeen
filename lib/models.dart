// lib/models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// AppUser class remains the same
class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? username;
  final List<String> fcmTokens; // To send notifications

  AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.username,
    this.fcmTokens = const [],
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'username': username,
        'fcmTokens': fcmTokens,
      };

  // Optional: Factory to create AppUser from Firestore doc if you need to display member names
  factory AppUser.fromDoc(DocumentSnapshot doc) {
     Map data = doc.data() as Map<String, dynamic>;
     return AppUser(
       uid: doc.id,
       email: data['email'],
       displayName: data['displayName'],
       username: data['username'],
       fcmTokens: List<String>.from(data['fcmTokens'] ?? []),
     );
  }
}

class GroupInvitation {
  final String id;
  final String groupId;
  final String groupName;
  final String invitedBy; // UID of user who invited
  final String status; // pending, accepted, declined

  GroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.invitedBy,
    required this.status,
  });

  factory GroupInvitation.fromDoc(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return GroupInvitation(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      groupName: data['groupName'] ?? '',
      invitedBy: data['invitedBy'] ?? '',
      status: data['status'] ?? 'pending',
    );
  }
}

// Group class remains the same
class Group {
  final String id;
  final String name;
  final String createdByUid;
  final List<String> memberUids;

  Group({
    required this.id,
    required this.name,
    required this.createdByUid,
    required this.memberUids,
  });

  factory Group.fromDoc(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Group(
      id: doc.id,
      name: data['name'] ?? '',
      createdByUid: data['createdByUid'] ?? '',
      memberUids: List<String>.from(data['memberUids'] ?? []),
    );
  }
}

// Represents an activity within a group (MODIFIED)
class Activity {
  final String id;
  final String name;
  final String createdByUid;
  final Timestamp createdAt; // Keep track of when the *definition* was created
  // Removed activityTime - it's now set dynamically on activation

  Activity({
    required this.id,
    required this.name,
    required this.createdByUid,
    required this.createdAt,
  });

  factory Activity.fromDoc(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Activity(
      id: doc.id,
      name: data['name'] ?? '',
      createdByUid: data['createdByUid'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(), // Use current time as fallback
    );
  }
}

// ActivityResponse remains the same for now
class ActivityResponse {
  final String uid; // The user who responded
  final bool isKeen;
  final DateTime respondedAt;

  ActivityResponse({
    required this.uid,
    required this.isKeen,
    required this.respondedAt,
  });

  factory ActivityResponse.fromDoc(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ActivityResponse(
      uid: doc.id,
      isKeen: data['isKeen'] ?? false,
      respondedAt: (data['respondedAt'] as Timestamp).toDate(),
    );
  }
}