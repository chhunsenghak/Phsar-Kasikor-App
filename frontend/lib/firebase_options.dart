import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'services/config_service.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
    apiKey: ConfigService.get('FIREBASE_WEB_API_KEY'),
    appId: ConfigService.get('FIREBASE_WEB_APP_ID'),
    messagingSenderId: ConfigService.get('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: ConfigService.get('FIREBASE_PROJECT_ID'),
    authDomain: ConfigService.get('FIREBASE_AUTH_DOMAIN'),
    storageBucket: ConfigService.get('FIREBASE_STORAGE_BUCKET'),
  );

  static FirebaseOptions get android => FirebaseOptions(
    apiKey: ConfigService.get('FIREBASE_ANDROID_API_KEY'),
    appId: ConfigService.get('FIREBASE_ANDROID_APP_ID'),
    messagingSenderId: ConfigService.get('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: ConfigService.get('FIREBASE_PROJECT_ID'),
    storageBucket: ConfigService.get('FIREBASE_STORAGE_BUCKET'),
  );

  static FirebaseOptions get ios => FirebaseOptions(
    apiKey: ConfigService.get('FIREBASE_IOS_API_KEY'),
    appId: ConfigService.get('FIREBASE_IOS_APP_ID'),
    messagingSenderId: ConfigService.get('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: ConfigService.get('FIREBASE_PROJECT_ID'),
    storageBucket: ConfigService.get('FIREBASE_STORAGE_BUCKET'),
    iosBundleId: ConfigService.get('FIREBASE_IOS_BUNDLE_ID'),
  );
}
