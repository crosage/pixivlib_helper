// ignore_for_file: implementation_imports

import 'dart:io' as io;

import 'package:file/file.dart' as fs;
import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/src/storage/file_system/file_system.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const String imageProxyHost = '127.0.0.1';
const int imageProxyPort = 7890;
const bool skipImageCertCheck = true;
const String _imageCacheKey = 'pixiv_proxy_image_cache_d_drive_v1';
const String _imageCacheFolderName = 'image_cache';
const String _windowsImageCacheRoot = r'D:\PixivHelperCache';

const LocalFileSystem _localFileSystem = LocalFileSystem();

http.Client createProxyClient(
  String proxyHost,
  int proxyPort, {
  bool skipBadCertificates = false,
}) {
  final client = io.HttpClient();
  client.findProxy = (uri) => 'PROXY $proxyHost:$proxyPort;';
  if (skipBadCertificates) {
    client.badCertificateCallback =
        (io.X509Certificate cert, String host, int port) => true;
    debugPrint('Proxy Client: Skipping bad certificate checks.');
  }
  return IOClient(client);
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

class CacheFileEntry {
  final String name;
  final String path;
  final int sizeBytes;
  final DateTime modifiedAt;

  const CacheFileEntry({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.modifiedAt,
  });
}

class CacheDirectoryStats {
  final String path;
  final int fileCount;
  final int totalBytes;
  final List<CacheFileEntry> recentFiles;

  const CacheDirectoryStats({
    required this.path,
    required this.fileCount,
    required this.totalBytes,
    required this.recentFiles,
  });
}

final HttpFileService _proxyHttpFileService = HttpFileService(
  httpClient: http.Client(),
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

Future<CacheDirectoryStats> collectImageCacheStats({
  int maxEntries = 30,
}) async {
  final directory = await resolveImageCacheDirectory();
  final recentFiles = <CacheFileEntry>[];
  var fileCount = 0;
  var totalBytes = 0;

  if (await directory.exists()) {
    await for (final entity
        in directory.list(recursive: true, followLinks: false)) {
      if (entity is! io.File) {
        continue;
      }
      final stat = await entity.stat();
      final sizeBytes = stat.size;
      totalBytes += sizeBytes;
      fileCount++;
      recentFiles.add(
        CacheFileEntry(
          name: p.basename(entity.path),
          path: entity.path,
          sizeBytes: sizeBytes,
          modifiedAt: stat.modified,
        ),
      );
    }
  }

  recentFiles
      .sort((left, right) => right.modifiedAt.compareTo(left.modifiedAt));

  return CacheDirectoryStats(
    path: directory.path,
    fileCount: fileCount,
    totalBytes: totalBytes,
    recentFiles: recentFiles.take(maxEntries).toList(),
  );
}

Future<void> clearImageCache() async {
  await imageProxyCacheManager.emptyCache();
  final directory = await resolveImageCacheDirectory();
  if (!await directory.exists()) {
    return;
  }

  await for (final entity in directory.list(followLinks: false)) {
    await entity.delete(recursive: true);
  }
}

Future<void> openImageCacheDirectory() async {
  final path = await getImageCacheDirectoryPath();

  Future<void> ensureSuccess(io.ProcessResult result, String command) async {
    if (result.exitCode != 0) {
      throw Exception('无法打开缓存目录，命令 $command 退出码: ${result.exitCode}');
    }
  }

  if (io.Platform.isWindows) {
    final result = await io.Process.run('explorer.exe', [path]);
    await ensureSuccess(result, 'explorer.exe');
    return;
  }
  if (io.Platform.isMacOS) {
    final result = await io.Process.run('open', [path]);
    await ensureSuccess(result, 'open');
    return;
  }
  if (io.Platform.isLinux) {
    final result = await io.Process.run('xdg-open', [path]);
    await ensureSuccess(result, 'xdg-open');
  }
}
