import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeBubbleService {
  static const MethodChannel _channel = MethodChannel('com.example.expense_tracker/bubble');

  static Future<bool> checkPermission() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final bool res = await _channel.invokeMethod('checkPermission');
      return res;
    } catch (e) {
      debugPrint('Error checking overlay permission: $e');
      return false;
    }
  }

  static Future<bool> requestPermission() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final bool res = await _channel.invokeMethod('requestPermission');
      return res;
    } catch (e) {
      debugPrint('Error requesting overlay permission: $e');
      return false;
    }
  }

  static Future<bool> startBubble() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final bool res = await _channel.invokeMethod('startBubble');
      return res;
    } catch (e) {
      debugPrint('Error starting native bubble: $e');
      return false;
    }
  }

  static Future<bool> stopBubble() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final bool res = await _channel.invokeMethod('stopBubble');
      return res;
    } catch (e) {
      debugPrint('Error stopping native bubble: $e');
      return false;
    }
  }

  static Future<bool> isBubbleRunning() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final bool res = await _channel.invokeMethod('isBubbleRunning');
      return res;
    } catch (e) {
      return false;
    }
  }

  static Future<void> updateTheme(String themeOption) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateTheme', {'theme': themeOption});
    } catch (e) {
      debugPrint('Error updating native bubble theme: $e');
    }
  }

  static void initializeListener(VoidCallback onExpenseAdded) {
    if (kIsWeb || !Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onExpenseAdded') {
        onExpenseAdded();
      }
    });
  }
}
