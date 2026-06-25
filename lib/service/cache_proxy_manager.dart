// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:io' as io;

import 'package:file/file.dart' as fs;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/src/storage/file_system/file_system.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const String _imageCacheKey = 'pixiv_proxy_image_cache_d_drive_v1';
const String _imageCacheFolderName = 'image_cache';
const String _windowsImageCacheRoot = r'D:\PixivHelperCache';

const LocalFileSystem _localFileSystem = LocalFileSystem();

class TimeoutHttpClient extends http.BaseClient {
  final http.Client _inner;
  final Duration responseTimeout;
  final Duration idleTimeout;

  TimeoutHttpClient({
    http.Client? inner,
    this.responseTimeout = const Duration(seconds: 18),
    this.idleTimeout = const Duration(seconds: 18),
  }) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request).timeout(responseTimeout);
    return http.StreamedResponse(
      response.stream.timeout(idleTimeout),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

class PersistentIOFileSystem implements FileSystem {
  PersistentIOFileSystem(this.cacheKey)
      : _fileDir = _createCacheDirectory(cacheKey);

  final String cacheKey;
  final Future<fs.Directory> _fileDir;

  static Future<fs.Directory> _createCacheDirectory(String cacheKey) async {
    final path = await getImageCacheDirectoryPath(cacheKey: cacheKey);
    final directory = _localFileSystem.directory(path);
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<fs.File> createFile(String name) async {
    final directory = await _fileDir;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.childFile(name);
  }
}

final HttpFileService _proxyHttpFileService = HttpFileService(
  httpClient: TimeoutHttpClient(),
);

final Config _proxyImageCacheConfig = Config(
  _imageCacheKey,
  stalePeriod: const Duration(days: 3650),
  maxNrOfCacheObjects: 5000,
  fileService: _proxyHttpFileService,
  fileSystem: PersistentIOFileSystem(_imageCacheKey),
);

final CacheManager imageProxyCacheManager =
    CacheManager(_proxyImageCacheConfig);

Future<io.Directory> resolveImageCacheDirectory({
  String cacheKey = _imageCacheKey,
}) async {
  final baseDirectory = await _resolveCacheBaseDirectory();
  final cachePath = p.join(
    baseDirectory.path,
    _imageCacheFolderName,
    cacheKey,
  );
  final cacheDirectory = io.Directory(cachePath);
  if (!await cacheDirectory.exists()) {
    await cacheDirectory.create(recursive: true);
  }
  return cacheDirectory;
}

Future<io.Directory> _resolveCacheBaseDirectory() async {
  if (io.Platform.isWindows) {
    final directory = io.Directory(_windowsImageCacheRoot);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  final fallbackDirectory = await getApplicationSupportDirectory();
  if (!await fallbackDirectory.exists()) {
    await fallbackDirectory.create(recursive: true);
  }
  return fallbackDirectory;
}

Future<String> getImageCacheDirectoryPath({
  String cacheKey = _imageCacheKey,
}) async {
  final directory = await resolveImageCacheDirectory(cacheKey: cacheKey);
  return directory.path;
}
