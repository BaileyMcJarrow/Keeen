import 'package:cloud_firestore/cloud_firestore.dart';

// Represents a user in your system
class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final List<String> fcmTokens; // To send notifications

  AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.fcmTokens = const [],
  });
  
  // Convert to/from Firestore map
  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'fcmTokens': fcmTokens,
  };
}

// Represents a group
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

  // Convert from a Firestore snapshot
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

// Represents an activity within a group
class Activity {
  final String id;
  final String name;
  final String createdByUid;
  final DateTime activityTime; // The time the activity is happening
  final DateTime createdAt;

  Activity({
    required this.id,
    required this.name,
    required this.createdByUid,
    required this.activityTime,
    required this.createdAt,
  });
  
  factory Activity.fromDoc(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Activity(
      id: doc.id,
      name: data['name'] ?? '',
      createdByUid: data['createdByUid'] ?? '',
      activityTime: (data['activityTime'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}

// Represents a user's response to an activity
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
      uid: doc.id, // The doc ID will be the user's UID
      isKeen: data['isKeen'] ?? false,
      respondedAt: (data['respondedAt'] as Timestamp).toDate(),
    );
  }
}