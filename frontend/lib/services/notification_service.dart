import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool isInitialized = false;

  Future<void> initialize() async {
    try {
      // Request device push permissions
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        isInitialized = true;
        print('User granted notification permissions.');
        
        // Listen for foreground notifications
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          print('Notification received in foreground: ${message.notification?.title}');
        });
      }
    } catch (e) {
      print('FCM Init skipped or failed (Running without active Firebase credentials): $e');
    }
  }

  Future<String?> getDeviceToken() async {
    if (!isInitialized) return null;
    try {
      return await _fcm.getToken();
    } catch (e) {
      print('Failed to get FCM registration token: $e');
      return null;
    }
  }
}
