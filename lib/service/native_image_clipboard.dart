import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'cache_proxy_manager.dart';
import 'remote_image_url.dart';

class NativeImageClipboard {
  NativeImageClipboard._();

  static const MethodChannel _channel =
      MethodChannel('tagselector/image_clipboard');
  static const Map<String, String> _pixivHeaders = {
    'Referer': 'https://www.pixiv.net/',
  };

  static Future<void> copyNetworkImage(String imageUrl) async {
    if (imageUrl.isEmpty) {
      throw ArgumentError.value(imageUrl, 'imageUrl', 'Image URL is empty.');
    }

    final resolvedImageUrl = proxiedImageUrl(imageUrl);

    final file = await imageProxyCacheManager.getSingleFile(
      resolvedImageUrl,
      headers: imageRequestHeaders(
            imageUrl,
            resolvedUrl: resolvedImageUrl,
          ) ??
          (resolvedImageUrl == imageUrl ? _pixivHeaders : null),
    );
    final encodedBytes = await file.readAsBytes();
    if (encodedBytes.isEmpty) {
      throw StateError('Image bytes are empty.');
    }

    final pngBytes = await _encodeAsPng(encodedBytes);
    await _channel.invokeMethod<void>('copyImage', pngBytes);
  }

  static Future<Uint8List> _encodeAsPng(Uint8List encodedBytes) async {
    final codec = await ui.instantiateImageCodec(encodedBytes);
    try {
      final frame = await codec.getNextFrame();
      try {
        final byteData = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (byteData == null) {
          throw StateError('Failed to encode PNG bytes.');
        }
        return byteData.buffer.asUint8List();
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
}
