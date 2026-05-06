import 'package:tagselector/service/api_service.dart';
import 'package:tagselector/service/app_user_session.dart';

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

Map<String, String>? imageRequestHeaders(
  String rawUrl, {
  String? resolvedUrl,
}) {
  final trimmedUrl = rawUrl.trim();
  if (trimmedUrl.isEmpty) {
    return null;
  }

  final effectiveUrl = (resolvedUrl ?? proxiedImageUrl(trimmedUrl)).trim();
  final effectiveUri = Uri.tryParse(effectiveUrl);
  if (_isProxyEndpoint(effectiveUri)) {
    final userId = AppUserSession.instance.activeUserId;
    if (userId == null || userId <= 0) {
      return null;
    }
    return {'X-App-User-Id': '$userId'};
  }

  final rawUri = Uri.tryParse(trimmedUrl);
  if (_shouldProxyPixivAsset(rawUri)) {
    return const {'Referer': 'https://www.pixiv.net/'};
  }

  return null;
}

bool _isProxyEndpoint(Uri? uri) {
  if (uri == null) {
    return false;
  }

  final apiUri = Uri.parse(ApiService.baseUrl);
  final normalizedBasePath = apiUri.path.endsWith('/')
      ? apiUri.path.substring(0, apiUri.path.length - 1)
      : apiUri.path;
  final proxyPath = '$normalizedBasePath/api/image/proxy';

  return uri.scheme == apiUri.scheme &&
      uri.host == apiUri.host &&
      uri.port == apiUri.port &&
      uri.path == proxyPath;
}

bool _isAlreadyUsingApiHost(Uri targetUri) {
  final apiUri = Uri.parse(ApiService.baseUrl);
  return targetUri.scheme == apiUri.scheme &&
      targetUri.host == apiUri.host &&
      targetUri.port == apiUri.port;
}

bool _shouldProxyPixivAsset(Uri? targetUri) {
  if (targetUri == null) {
    return false;
  }

  if (targetUri.scheme != 'http' && targetUri.scheme != 'https') {
    return false;
  }

  final host = targetUri.host.toLowerCase();
  return host == 'pximg.net' ||
      host.endsWith('.pximg.net') ||
      host == 'pixiv.net' ||
      host.endsWith('.pixiv.net');
}
