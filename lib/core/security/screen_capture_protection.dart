import 'package:flutter/services.dart';

class ScreenCaptureProtection {
  static const MethodChannel _channel = MethodChannel(
    'sick_of_football/screen_capture',
  );

  static Future<void> enable() async {
    try {
      await _channel.invokeMethod<void>('enable');
    } on MissingPluginException {
      // Screenshot blocking is implemented for Android only.
    }
  }

  static Future<void> disable() async {
    try {
      await _channel.invokeMethod<void>('disable');
    } on MissingPluginException {
      // Screenshot blocking is implemented for Android only.
    }
  }
}
