import 'dart:io';

import 'package:flutter/services.dart';

class GalleryMetadataUpdate {
  final String uri;
  final DateTime dateTaken;

  const GalleryMetadataUpdate({
    required this.uri,
    required this.dateTaken,
  });

  Map<String, Object> toJson() => {
        'uri': uri,
        'dateTakenMillis': dateTaken.millisecondsSinceEpoch,
      };
}

class GallerySaver {
  GallerySaver._();

  static const MethodChannel _channel =
      MethodChannel('tagselector/media_store');

  static Future<String?> publishImage({
    required String sourcePath,
    required String displayName,
    required String mimeType,
    DateTime? dateTaken,
  }) async {
    if (!Platform.isAndroid) {
      return null;
    }

    return _channel.invokeMethod<String>('publishImage', {
      'sourcePath': sourcePath,
      'displayName': displayName,
      // Keep every artwork in one predictable gallery folder. The pid and
      // page number are already part of the file name, so subfolders add
      // clutter without preventing name collisions.
      'relativePath': 'PixivHelper',
      'mimeType': mimeType,
      if (dateTaken != null)
        'dateTakenMillis': dateTaken.millisecondsSinceEpoch,
    });
  }

  static Future<int> rewriteImageMetadata(
    List<GalleryMetadataUpdate> updates,
  ) async {
    if (!Platform.isAndroid || updates.isEmpty) {
      return 0;
    }

    return await _channel.invokeMethod<int>('rewriteImageMetadata', {
          'items': updates.map((update) => update.toJson()).toList(),
        }) ??
        0;
  }
}
