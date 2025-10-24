// lib/fcm_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'local_notification.dart'; // Using your existing service
import 'firestore_service.dart'; // Import FirestoreService

// Background handler remains the same
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); // Needed if using other Firebase services
}

class FcmService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final NotificationService _localNotifications = NotificationService();
  final FirestoreService _firestoreService; // Added FirestoreService instance

  // Constructor requires FirestoreService
  FcmService({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  Future<void> init() async {
    // 1. Request permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true, announcement: false, badge: true, carPlay: false,
      criticalAlert: false, provisional: false, sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission');

      // 2. Get and save the FCM token (if user is logged in)
      await saveTokenToFirestore();

      // Listen for token refreshes and save them too
      _fcm.onTokenRefresh.listen((newToken) async {
        print("FCM Token Refreshed: $newToken");
        await saveTokenToFirestore(token: newToken); // Pass the new token
      });

    } else {
      print('User declined or has not accepted notification permission');
    }

    // 3. Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        _localNotifications.showNotification(
          message.hashCode,
          message.notification!.title ?? 'New Message',
          message.notification!.body ?? '',
          message.data['groupId'] ?? message.data.toString(), // Example payload
        );
      }
    });

    // 4. Set the background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Helper method to save the token
  Future<void> saveTokenToFirestore({String? token}) async {
    // Get the token if not provided (e.g., on initial load)
    final fcmToken = token ?? await _fcm.getToken();
    print("Attempting to save FCM Token: $fcmToken");

    if (fcmToken != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          // Use the injected FirestoreService instance
          await _firestoreService.updateUserToken(user.uid, fcmToken);
          print("FCM token saved to Firestore for user ${user.uid}");
        } catch (e) {
          print("Error saving FCM token to Firestore: $e");
        }
      } else {
        print("User not logged in, cannot save FCM token yet.");
      }
    } else {
      print("Could not get FCM token.");
    }
  }
}