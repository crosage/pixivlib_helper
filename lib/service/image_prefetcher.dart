import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tagselector/model/daily_ranking_model.dart';
import 'package:tagselector/model/image_model.dart';
import 'package:tagselector/service/cache_proxy_manager.dart';
import 'package:tagselector/service/remote_image_url.dart';

class ImagePrefetcher {
  ImagePrefetcher._();

  static final ImagePrefetcher instance = ImagePrefetcher._();

  final Set<String> _queuedOrCached = <String>{};
  final List<String> _queue = <String>[];
  int _active = 0;

  static const int _maxConcurrentDownloads = 6;

  void prefetchImageModels(
    Iterable<ImageModel> images, {
    bool highQuality = false,
    int limit = 18,
  }) {
    prefetchUrls(
      images
          .map((image) => previewUrlForImage(image, highQuality: highQuality)),
      limit: limit,
    );
  }

  void prefetchRankingModels(
    Iterable<DailyRankingModel> images, {
    int limit = 18,
  }) {
    prefetchUrls(
      images.map((image) => image.thumbUrl),
      limit: limit,
    );
  }

  void prefetchUrls(
    Iterable<String> rawUrls, {
    int limit = 18,
  }) {
    var added = 0;
    for (final rawUrl in rawUrls) {
      if (added >= limit) break;
      final url = rawUrl.trim();
      if (url.isEmpty) continue;
      final proxiedUrl = proxiedImageUrl(url);
      if (!_queuedOrCached.add(proxiedUrl)) continue;
      _queue.add(proxiedUrl);
      added++;
    }
    _pump();
  }

  void _pump() {
    while (_active < _maxConcurrentDownloads && _queue.isNotEmpty) {
      final url = _queue.removeAt(0);
      _active++;
      unawaited(_download(url));
    }
  }

  Future<void> _download(String url) async {
    try {
      await imageProxyCacheManager.downloadFile(url);
    } catch (error) {
      _queuedOrCached.remove(url);
      if (kDebugMode) {
        debugPrint('Image prefetch failed: $error');
      }
    } finally {
      _active--;
      _pump();
    }
  }
}

String previewUrlForImage(
  ImageModel image, {
  required bool highQuality,
}) {
  final candidates = highQuality
      ? [image.urls.regular, image.urls.small, image.urls.thumb]
      : [image.urls.small, image.urls.regular, image.urls.thumb];
  for (final url in candidates) {
    if (url.trim().isNotEmpty) {
      return url;
    }
  }
  return '';
}
