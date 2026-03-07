import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/fly_swatter_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    // Khoa app o che do doc tren mobile.
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  try {
    // Chi khoi tao Firebase tren cac nen tang duoc ho tro, tranh loi khi test.
    if (!kIsWeb &&
        (Platform.isAndroid ||
            Platform.isIOS ||
            Platform.isMacOS ||
            Platform.isWindows ||
            Platform.isLinux)) {
      await Firebase.initializeApp();
    }
  } catch (error) {
    // App van chay duoc o che do local/offline neu Firebase khong san sang.
    debugPrint('[main] Firebase init skipped');
  }

  runApp(const FlySwatterApp());
}
