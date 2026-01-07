import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:5000";
    }

    if (Platform.isAndroid) {
      // Emulator uses 10.0.2.2
      return "http://10.0.2.2:5000";
    }

    // iOS physical device or others
    return "http://192.168.8.115:5000";
  }
}

