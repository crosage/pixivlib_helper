import 'dart:io';

import 'package:flutter/services.dart';

class GallerySaver {
  GallerySaver._();

  static const MethodChannel _channel =
      MethodChannel('tagselector/media_store');

  static Future<String?> publishImage({
    required String sourcePath,
    required String displayName,
    required int pid,
    required String mimeType,
  }) async {
    if (!Platform.isAndroid) {
      return null;
    }

    return _channel.invokeMethod<String>('publishImage', {
      'sourcePath': sourcePath,
      'displayName': displayName,
      'relativePath': 'PixivHelper/$pid',
      'mimeType': mimeType,
    });
  }
}
