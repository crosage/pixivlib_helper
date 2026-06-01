import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:tagselector/model/image_model.dart';
import 'package:tagselector/service/gallery_saver.dart';
import 'package:tagselector/service/remote_image_url.dart';

enum ArtworkDownloadStatus {
  queued,
  downloading,
  completed,
  failed,
}

class ArtworkDownloadTask {
  final String id;
  final String batchId;
  final int pid;
  final int pageIndex;
  final int pageCount;
  final String title;
  final String sourceUrl;
  final String savePath;
  final DateTime createdAt;

  ArtworkDownloadStatus status;
  int receivedBytes;
  int totalBytes;
  String? publishedUri;
  String? visiblePath;
  Object? error;

  ArtworkDownloadTask({
    required this.id,
    required this.batchId,
    required this.pid,
    required this.pageIndex,
    required this.pageCount,
    required this.title,
    required this.sourceUrl,
    required this.savePath,
    required this.createdAt,
    this.status = ArtworkDownloadStatus.queued,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.error,
  });

  double? get progress {
    if (totalBytes <= 0) {
      return null;
    }
    return (receivedBytes / totalBytes).clamp(0, 1).toDouble();
  }

  bool get isActive =>
      status == ArtworkDownloadStatus.queued ||
      status == ArtworkDownloadStatus.downloading;
}

class ArtworkDownloadBatch {
  final String id;
  final int pid;
  final String title;
  final List<ArtworkDownloadTask> tasks;
  final DateTime createdAt;

  const ArtworkDownloadBatch({
    required this.id,
    required this.pid,
    required this.title,
    required this.tasks,
    required this.createdAt,
  });

  bool get isCompleted =>
      tasks.isNotEmpty &&
      tasks.every((task) => task.status == ArtworkDownloadStatus.completed);

  bool get hasFailed =>
      tasks.any((task) => task.status == ArtworkDownloadStatus.failed);

  int get completedCount => tasks
      .where((task) => task.status == ArtworkDownloadStatus.completed)
      .length;

  String get firstSaveDirectory {
    if (tasks.isEmpty) return '';
    return path.dirname(tasks.first.visiblePath ?? tasks.first.savePath);
  }
}

class ArtworkDownloadManager extends ChangeNotifier {
  ArtworkDownloadManager._();

  static final ArtworkDownloadManager instance = ArtworkDownloadManager._();

  final Dio _dio = Dio();
  final List<ArtworkDownloadTask> _tasks = [];
  final List<ArtworkDownloadTask> _queue = [];
  final Map<String, Completer<ArtworkDownloadBatch>> _batchCompleters = {};
  final Map<String, Completer<void>> _batchProgressWaiters = {};

  int _activeCount = 0;
  int _sequence = 0;
  DateTime _lastProgressNotifyAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _progressNotifyTimer;

  static const int _maxConcurrentDownloads = 3;
  static const Duration _progressNotifyInterval = Duration(milliseconds: 220);

  List<ArtworkDownloadTask> get tasks => List.unmodifiable(_tasks);

  int get activeTaskCount => _tasks.where((task) => task.isActive).length;

  int get completedTaskCount => _tasks
      .where((task) => task.status == ArtworkDownloadStatus.completed)
      .length;

  int get failedTaskCount => _tasks
      .where((task) => task.status == ArtworkDownloadStatus.failed)
      .length;

  @override
  void dispose() {
    _progressNotifyTimer?.cancel();
    super.dispose();
  }

  Future<ArtworkDownloadBatch> downloadOriginalArtwork(ImageModel image) async {
    final pageIds = image.pages.isEmpty
        ? const [0]
        : image.pages.map((page) => page.pageId).toList(growable: false);
    final downloadDirectory = await _resolveDownloadDirectory(image.pid);
    final createdAt = DateTime.now();
    final batchId = '${image.pid}-${createdAt.microsecondsSinceEpoch}';
    final batchTasks = <ArtworkDownloadTask>[];

    for (var index = 0; index < pageIds.length; index++) {
      final sourceUrl =
          _resolveOriginalUrlForPage(image.urls.original, pageIds[index]);
      if (sourceUrl.isEmpty) {
        continue;
      }
      final savePath = path.join(
        downloadDirectory.path,
        _buildFileName(
          pid: image.pid,
          pageIndex: index,
          pageCount: pageIds.length,
          sourceUrl: sourceUrl,
        ),
      );
      final task = ArtworkDownloadTask(
        id: '$batchId-${_sequence++}',
        batchId: batchId,
        pid: image.pid,
        pageIndex: index,
        pageCount: pageIds.length,
        title:
            image.name.trim().isEmpty ? 'PID ${image.pid}' : image.name.trim(),
        sourceUrl: sourceUrl,
        savePath: savePath,
        createdAt: createdAt,
      );
      batchTasks.add(task);
    }

    if (batchTasks.isEmpty) {
      throw StateError('这个作品没有可下载的 origin 地址');
    }

    _tasks.insertAll(0, batchTasks);
    _queue.addAll(batchTasks);
    _batchCompleters[batchId] = Completer<ArtworkDownloadBatch>();
    notifyListeners();
    _pumpQueue();
    return _batchCompleters[batchId]!.future;
  }

  void clearFinished() {
    _tasks.removeWhere((task) =>
        task.status == ArtworkDownloadStatus.completed ||
        task.status == ArtworkDownloadStatus.failed);
    notifyListeners();
  }

  void retryTask(ArtworkDownloadTask task) {
    if (task.status != ArtworkDownloadStatus.failed) {
      return;
    }

    task.status = ArtworkDownloadStatus.queued;
    task.receivedBytes = 0;
    task.totalBytes = 0;
    task.error = null;
    task.publishedUri = null;
    task.visiblePath = null;
    _queue.remove(task);
    _queue.add(task);
    notifyListeners();
    _pumpQueue();
  }

  void retryFailedTasks() {
    final failedTasks = _tasks
        .where((task) => task.status == ArtworkDownloadStatus.failed)
        .toList(growable: false);
    if (failedTasks.isEmpty) {
      return;
    }

    for (final task in failedTasks) {
      task.status = ArtworkDownloadStatus.queued;
      task.receivedBytes = 0;
      task.totalBytes = 0;
      task.error = null;
      task.publishedUri = null;
      task.visiblePath = null;
      _queue.remove(task);
      _queue.add(task);
    }
    notifyListeners();
    _pumpQueue();
  }

  void _pumpQueue() {
    while (_activeCount < _maxConcurrentDownloads && _queue.isNotEmpty) {
      final task = _queue.removeAt(0);
      _activeCount++;
      unawaited(_downloadTask(task));
    }
  }

  Future<void> _downloadTask(ArtworkDownloadTask task) async {
    task.status = ArtworkDownloadStatus.downloading;
    notifyListeners();

    try {
      final saveFile = File(task.savePath);
      await saveFile.parent.create(recursive: true);
      if (await saveFile.exists()) {
        await saveFile.delete();
      }
      final downloadUrl = proxiedImageUrl(task.sourceUrl);
      await _dio.download(
        downloadUrl,
        task.savePath,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(seconds: 30),
          headers: imageRequestHeaders(
            task.sourceUrl,
            resolvedUrl: downloadUrl,
          ),
        ),
        onReceiveProgress: (received, total) {
          task.receivedBytes = received;
          task.totalBytes = total;
          _notifyProgressChanged();
        },
      );
      await _waitForEarlierBatchTasks(task);
      final publishedUri = await GallerySaver.publishImage(
        sourcePath: task.savePath,
        displayName: path.basename(task.savePath),
        pid: task.pid,
        mimeType: _mimeTypeForPath(task.savePath),
        dateTaken: _gallerySortTimeForTask(task),
      );
      if (publishedUri != null) {
        task.publishedUri = publishedUri;
        task.visiblePath =
            'Pictures/PixivHelper/${task.pid}/${path.basename(task.savePath)}';
        try {
          await saveFile.delete();
        } catch (_) {
          // The gallery copy succeeded; keeping the temp file is harmless.
        }
      } else {
        task.visiblePath = task.savePath;
      }
      task.status = ArtworkDownloadStatus.completed;
    } catch (error) {
      task.status = ArtworkDownloadStatus.failed;
      task.error = error;
    } finally {
      _activeCount--;
      notifyListeners();
      _notifyBatchProgress(task.batchId);
      _completeFinishedBatches();
      _pumpQueue();
    }
  }

  void _notifyProgressChanged() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastProgressNotifyAt);
    if (elapsed >= _progressNotifyInterval) {
      _progressNotifyTimer?.cancel();
      _progressNotifyTimer = null;
      _lastProgressNotifyAt = now;
      notifyListeners();
      return;
    }

    _progressNotifyTimer ??= Timer(_progressNotifyInterval - elapsed, () {
      _progressNotifyTimer = null;
      _lastProgressNotifyAt = DateTime.now();
      notifyListeners();
    });
  }

  Future<void> _waitForEarlierBatchTasks(ArtworkDownloadTask task) async {
    if (task.pageCount <= 1 || task.pageIndex == 0) {
      return;
    }

    // Downloading may finish out of order, but gallery insertion order should
    // stay p0, p1, p2... so albums sort manga pages predictably.
    while (_tasks.any(
      (candidate) =>
          candidate.batchId == task.batchId &&
          candidate.pageIndex < task.pageIndex &&
          candidate.isActive,
    )) {
      final waiter = _batchProgressWaiters.putIfAbsent(
        task.batchId,
        () => Completer<void>(),
      );
      await waiter.future;
    }
  }

  void _notifyBatchProgress(String batchId) {
    final waiter = _batchProgressWaiters.remove(batchId);
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  }

  void _completeFinishedBatches() {
    final pending = Map<String, Completer<ArtworkDownloadBatch>>.from(
      _batchCompleters,
    );
    for (final entry in pending.entries) {
      final batchTasks = _tasks.where((task) => task.batchId == entry.key);
      if (batchTasks.isEmpty || batchTasks.any((task) => task.isActive)) {
        continue;
      }
      final list = batchTasks.toList(growable: false);
      entry.value.complete(
        ArtworkDownloadBatch(
          id: entry.key,
          pid: list.first.pid,
          title: list.first.title,
          tasks: list,
          createdAt: list.first.createdAt,
        ),
      );
      _batchCompleters.remove(entry.key);
      _batchProgressWaiters.remove(entry.key);
    }
  }

  Future<Directory> _resolveDownloadDirectory(int pid) async {
    if (Platform.isAndroid) {
      final tempDirectory = await getTemporaryDirectory();
      final directory = Directory(
        path.join(tempDirectory.path, 'PixivHelper', 'downloads', '$pid'),
      );
      await directory.create(recursive: true);
      return directory;
    }

    final candidates = <Directory?>[
      await _safeDirectory(getDownloadsDirectory),
      await _safeAndroidPublicDownloadsDirectory(),
      await _safeDirectory(getExternalStorageDirectory),
      await _safeDirectory(getApplicationDocumentsDirectory),
    ];

    for (final candidate in candidates) {
      if (candidate == null) continue;
      final directory =
          Directory(path.join(candidate.path, 'PixivHelper', '$pid'));
      try {
        await directory.create(recursive: true);
        return directory;
      } catch (_) {
        continue;
      }
    }

    throw StateError('无法创建下载目录');
  }

  Future<Directory?> _safeDirectory(
      Future<Directory?> Function() resolver) async {
    try {
      return await resolver();
    } catch (_) {
      return null;
    }
  }

  Future<Directory?> _safeAndroidPublicDownloadsDirectory() async {
    if (!Platform.isAndroid) return null;
    try {
      final directory = Directory('/storage/emulated/0/Download');
      if (await directory.exists()) {
        return directory;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String _buildFileName({
    required int pid,
    required int pageIndex,
    required int pageCount,
    required String sourceUrl,
  }) {
    final uri = Uri.tryParse(sourceUrl);
    final extension = _extensionFromUrl(uri?.path ?? sourceUrl);
    final width = pageCount <= 1 ? 1 : (pageCount - 1).toString().length;
    final pageSuffix = pageCount > 1
        ? '_p${pageIndex.toString().padLeft(width.clamp(3, 6), '0')}'
        : '';
    return '$pid$pageSuffix$extension';
  }

  DateTime _gallerySortTimeForTask(ArtworkDownloadTask task) {
    if (task.pageCount <= 1) {
      return task.createdAt;
    }

    // Android gallery apps commonly sort albums by newest media first. Keep
    // later manga pages newer so multi-page works display as pN, pN-1...
    // consistently even when MediaStore scanning completes unpredictably.
    final reverseOffset = task.pageCount - 1 - task.pageIndex;
    return task.createdAt.subtract(Duration(seconds: reverseOffset));
  }

  String _extensionFromUrl(String sourcePath) {
    final extension = path.extension(sourcePath).toLowerCase();
    if (extension == '.jpg' ||
        extension == '.jpeg' ||
        extension == '.png' ||
        extension == '.gif' ||
        extension == '.webp') {
      return extension;
    }
    return '.jpg';
  }

  String _resolveOriginalUrlForPage(String originalUrl, int pageID) {
    if (originalUrl.isEmpty) {
      return '';
    }
    final matcher = RegExp(r'_p\d+');
    if (matcher.hasMatch(originalUrl)) {
      return originalUrl.replaceFirst(matcher, '_p$pageID');
    }
    return originalUrl;
  }

  String _mimeTypeForPath(String filePath) {
    return switch (path.extension(filePath).toLowerCase()) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}
