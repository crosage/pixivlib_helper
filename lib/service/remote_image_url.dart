import 'package:tagselector/service/api_service.dart';

String proxiedImageUrl(String rawUrl) {
  final trimmedUrl = rawUrl.trim();
  if (trimmedUrl.isEmpty) {
    return '';
  }

  final targetUri = Uri.tryParse(trimmedUrl);
  if (targetUri == null || !targetUri.hasScheme || targetUri.host.isEmpty) {
    return trimmedUrl;
  }

  if (_isAlreadyUsingApiHost(targetUri) || !_shouldProxyPixivAsset(targetUri)) {
    return trimmedUrl;
  }

  final baseUri = Uri.parse(ApiService.baseUrl);
  final normalizedBasePath = baseUri.path.endsWith('/')
      ? baseUri.path.substring(0, baseUri.path.length - 1)
      : baseUri.path;

  return baseUri.replace(
    path: '$normalizedBasePath/api/image/proxy',
    queryParameters: <String, String>{'url': trimmedUrl},
  ).toString();
}

bool _isAlreadyUsingApiHost(Uri targetUri) {
  final apiUri = Uri.parse(ApiService.baseUrl);
  return targetUri.scheme == apiUri.scheme &&
      targetUri.host == apiUri.host &&
      targetUri.port == apiUri.port;
}

bool _shouldProxyPixivAsset(Uri targetUri) {
  if (targetUri.scheme != 'http' && targetUri.scheme != 'https') {
    return false;
  }

  final host = targetUri.host.toLowerCase();
  return host == 'pximg.net' ||
      host.endsWith('.pximg.net') ||
      host == 'pixiv.net' ||
      host.endsWith('.pixiv.net');
}
