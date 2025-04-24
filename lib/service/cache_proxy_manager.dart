import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
http.Client createProxyClient(String proxyHost, int proxyPort, {bool skipBadCertificates = false}) {
  final client = HttpClient();
  client.findProxy = (uri) {
    return "PROXY $proxyHost:$proxyPort;";
  };
  if (skipBadCertificates) {
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    print('Proxy Client: Skipping bad certificate checks.');
  }
  return IOClient(client);
}

const String imageProxyHost = '127.0.0.1';
const int imageProxyPort = 7890; // int 类型
const bool skipImageCertCheck = true; // 调试用

final http.Client _proxyHttpClientForImages = createProxyClient(
  imageProxyHost,
  imageProxyPort,
  skipBadCertificates: skipImageCertCheck,
);

final HttpFileService _proxyHttpFileService = HttpFileService(
  httpClient: _proxyHttpClientForImages,
);

final Config _proxyImageCacheConfig = Config(
  'proxyImageCacheKey_v1',
  stalePeriod: const Duration(days: 15),
  maxNrOfCacheObjects: 200,
  fileService: _proxyHttpFileService,
);

final CacheManager imageProxyCacheManager = CacheManager(_proxyImageCacheConfig);

