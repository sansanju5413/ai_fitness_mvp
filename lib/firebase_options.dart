// ignore_for_file: constant_identifier_names

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCkVPivUb39PNsIA6odYksGx_vGw-S8n9w',
    appId: '1:176933143278:android:c1e8094ac2187d9c9569ff',
    messagingSenderId: '176933143278',
    projectId: 'modarbapp',
    storageBucket: 'modarbapp.firebasestorage.app',
  );
}