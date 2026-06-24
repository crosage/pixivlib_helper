import 'dart:async';

import 'package:tagselector/model/daily_ranking_model.dart';
import 'package:tagselector/model/image_model.dart';
import 'package:tagselector/service/cache_proxy_manager.dart';
import 'package:tagselector/service/remote_image_url.dart';

class ImagePrefetcher {
  ImagePrefetcher._();

  static final ImagePrefetcher instance = ImagePrefetcher._();

  final Set<String> _queuedOrCached = <String>{};
  final List<_PrefetchRequest> _queue = <_PrefetchRequest>[];
  int _active = 0;
  int _head = 0;

  static const int _maxConcurrentDownloads = 5;

  void prefetchImageModels(
    Iterable<ImageModel> images, {
    bool highQuality = false,
    int limit = 12,
  }) {
    prefetchUrls(
      images
          .map((image) => previewUrlForImage(image, highQuality: highQuality)),
      limit: limit,
    );
  }

  void prefetchRankingModels(
    Iterable<DailyRankingModel> images, {
    int limit = 12,
  }) {
    prefetchUrls(
      images.map((image) => image.thumbUrl),
      limit: limit,
    );
  }

  void prefetchUrls(
    Iterable<String> rawUrls, {
    int limit = 12,
  }) {
    var added = 0;
    for (final rawUrl in rawUrls) {
      if (added >= limit) break;
      final url = rawUrl.trim();
      if (url.isEmpty) continue;
      final proxiedUrl = proxiedImageUrl(url);
      if (!_queuedOrCached.add(proxiedUrl)) continue;
      _queue.add(
        _PrefetchRequest(
          url: proxiedUrl,
          headers: imageRequestHeaders(url, resolvedUrl: proxiedUrl),
        ),
      );
      added++;
    }
    _pump();
  }

  void _pump() {
    while (_active < _maxConcurrentDownloads && _head < _queue.length) {
      final request = _queue[_head++];
      _active++;
      unawaited(_download(request));
    }
    if (_head > 64 && _head * 2 >= _queue.length) {
      _queue.removeRange(0, _head);
      _head = 0;
    }
  }

  Future<void> _download(_PrefetchRequest request) async {
    try {
      await imageProxyCacheManager.downloadFile(
        request.url,
        authHeaders: request.headers,
      );
    } catch (_) {
      _queuedOrCached.remove(request.url);
    } finally {
      _active--;
      _pump();
    }
  }
}

class _PrefetchRequest {
  final String url;
  final Map<String, String>? headers;

  const _PrefetchRequest({
    required this.url,
    required this.headers,
  });
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
