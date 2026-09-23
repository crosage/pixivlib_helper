import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeShare {
  NativeShare._();

  static const MethodChannel _channel =
      MethodChannel('tagselector/native_share');

  static Future<bool> shareText({
    required String text,
    String title = '',
  }) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _channel.invokeMethod<void>('shareText', {
        'text': text,
        'title': title,
      });
      return true;
    }

    await Clipboard.setData(ClipboardData(text: text));
    return false;
  }
}
