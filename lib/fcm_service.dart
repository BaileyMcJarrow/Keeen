import 'package:firebase_messaging/firebase_messaging.dart';
import 'local_notification.dart'; // Using your existing service

// This must be a top-level function (not in a class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background,
  // make sure you call initializeApp first
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  print("Handling a background message: ${message.messageId}");
  // You can process the message here. 
  // The notification is typically handled by FCM automatically on Android.
}

class FcmService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final NotificationService _localNotifications = NotificationService();

  Future<void> init() async {
    // 1. Request permissions (required for iOS)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else {
      print('User declined or has not accepted permission');
    }

    // 2. Get the FCM token for this device
    final fcmToken = await _fcm.getToken();
    print("FCM Token: $fcmToken");
    // TODO: Save this token to your user's document in Firestore!
    // e.g., _firestoreService.saveUserToken(fcmToken);

    // 3. Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        
        // Use your existing local notification service to show it
        _localNotifications.showNotification(
          message.hashCode, // Use a unique ID
          message.notification!.title ?? 'New Message',
          message.notification!.body ?? '',
          message.data.toString(),
        );
      }
    });

    // 4. Set the background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
}