// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyAA2JbmtD52JMCz483glEV8eX1ZDeK0fZE',
        appId: '1:32660558108:web:102632793b65058953ead9',
        messagingSenderId: '32660558108',
        projectId: 'aksabeg-b6571',
        authDomain: 'aksabeg-b6571.firebaseapp.com',
        storageBucket: 'aksabeg-b6571.appspot.com',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const FirebaseOptions(
          apiKey: 'AIzaSyCczxrmzYiFRZuDHOqhgqcH-DGvV1z8WZ0', // ✅ تم الإصلاح
          appId: '1:32660558108:android:102632793b65058953ead9', // ✅ تم الإصلاح
          messagingSenderId: '32660558108',
          projectId: 'aksabeg-b6571',
          databaseURL: 'https://aksabeg-b6571-default-rtdb.firebaseio.com',
          storageBucket: 'aksabeg-b6571.firebasestorage.app',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }
}
