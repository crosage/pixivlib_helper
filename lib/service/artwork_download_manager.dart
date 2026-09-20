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
  canceled,
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
    if (status != ArtworkDownloadStatus.queued &&
        status != ArtworkDownloadStatus.downloading) {
      return null;
    }
    if (totalBytes <= 0) {
      return null;
    }
    return (receivedBytes / totalBytes).clamp(0, 1).toDouble();
  }

  bool get isActive =>
      status == ArtworkDownloadStatus.queued ||
      status == ArtworkDownloadStatus.downloading;

  bool get isCanceled => status == ArtworkDownloadStatus.canceled;
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

  bool get isActive => tasks.any((task) => task.isActive);

  bool get hasCanceled =>
      tasks.any((task) => task.status == ArtworkDownloadStatus.canceled);

  int get completedCount => tasks
      .where((task) => task.status == ArtworkDownloadStatus.completed)
      .length;

  int get canceledCount => tasks
      .where((task) => task.status == ArtworkDownloadStatus.canceled)
      .length;

  int get failedCount =>
      tasks.where((task) => task.status == ArtworkDownloadStatus.failed).length;

  double? get progress {
    if (tasks.isEmpty) return null;
    var knownProgress = 0.0;
    var hasKnownProgress = false;
    for (final task in tasks) {
      if (task.status == ArtworkDownloadStatus.completed) {
        knownProgress += 1;
        hasKnownProgress = true;
      } else if (task.totalBytes > 0) {
        knownProgress +=
            (task.receivedBytes / task.totalBytes).clamp(0, 1).toDouble();
        hasKnownProgress = true;
      }
    }
    return hasKnownProgress ? knownProgress / tasks.length : null;
  }

  String get firstSaveDirectory {
    if (tasks.isEmpty) return '';
    return path.dirname(tasks.first.visiblePath ?? tasks.first.savePath);
  }
}

class ArtworkDownloadManager extends ChangeNotifier {
  ArtworkDownloadManager._();

  static final ArtworkDownloadManager instance = ArtworkDownloadManager._();

  final Dio _dio = Dio(
    BaseOptions(connectTimeout: const Duration(seconds: 15)),
  );
  final List<ArtworkDownloadTask> _tasks = [];
  final List<ArtworkDownloadTask> _queue = [];
  final Map<String, Completer<ArtworkDownloadBatch>> _batchCompleters = {};
  final Map<String, Completer<void>> _batchProgressWaiters = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final Set<String> _activeTaskIds = <String>{};

  int _sequence = 0;
  DateTime _lastProgressNotifyAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _progressNotifyTimer;

  static const int _maxConcurrentDownloads = 3;
  static const Duration _progressNotifyInterval = Duration(milliseconds: 220);

  List<ArtworkDownloadTask> get tasks => List.unmodifiable(_tasks);

  List<ArtworkDownloadBatch> get batches {
    final grouped = <String, List<ArtworkDownloadTask>>{};
    final order = <String>[];
    for (final task in _tasks) {
      if (!grouped.containsKey(task.batchId)) {
        order.add(task.batchId);
        grouped[task.batchId] = <ArtworkDownloadTask>[];
      }
      grouped[task.batchId]!.add(task);
    }
    return order.map((id) {
      final batchTasks = grouped[id]!;
      return ArtworkDownloadBatch(
        id: id,
        pid: batchTasks.first.pid,
        title: batchTasks.first.title,
        tasks: List.unmodifiable(batchTasks),
        createdAt: batchTasks.first.createdAt,
      );
    }).toList(growable: false);
  }

  int get activeTaskCount => _tasks.where((task) => task.isActive).length;

  int get completedTaskCount => _tasks
      .where((task) => task.status == ArtworkDownloadStatus.completed)
      .length;

  int get failedTaskCount => _tasks
      .where((task) => task.status == ArtworkDownloadStatus.failed)
      .length;

  int get activeBatchCount => batches.where((batch) => batch.isActive).length;

  @override
  void dispose() {
    _progressNotifyTimer?.cancel();
    super.dispose();
  }

  Future<ArtworkDownloadBatch> downloadOriginalArtwork(ImageModel image) async {
    final pageIds = image.pages.isEmpty
        ? const [0]
        : image.pages.map((page) => page.pageId).toList(growable: false);
    final downloadDirectory = await _resolveDownloadDirectory();
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
    final completedBatchIds = batches
        .where((batch) => batch.isCompleted)
        .map((batch) => batch.id)
        .toSet();
    _tasks.removeWhere((task) => completedBatchIds.contains(task.batchId));
    notifyListeners();
  }

  void cancelTask(ArtworkDownloadTask task) {
    if (task.status == ArtworkDownloadStatus.completed ||
        task.status == ArtworkDownloadStatus.failed ||
        task.status == ArtworkDownloadStatus.canceled) {
      return;
    }

    if (task.status == ArtworkDownloadStatus.queued) {
      _queue.remove(task);
      task.status = ArtworkDownloadStatus.canceled;
      task.error = null;
      task.receivedBytes = 0;
      task.totalBytes = 0;
      task.publishedUri = null;
      task.visiblePath = null;
      notifyListeners();
      _notifyBatchProgress(task.batchId);
      _completeFinishedBatches();
      return;
    }

    task.status = ArtworkDownloadStatus.canceled;
    task.error = null;
    // Leave the partial byte count intact. The retained file is resumed with
    // an HTTP Range request when the user chooses to continue this task.
    task.publishedUri = null;
    task.visiblePath = null;

    final token = _cancelTokens[task.id];
    if (token != null && !token.isCancelled) {
      token.cancel('user canceled');
    }
    notifyListeners();
    _notifyBatchProgress(task.batchId);
    _completeFinishedBatches();
    // The active slot is released in _downloadTask's finally block after Dio
    // has actually stopped writing, keeping the concurrency limit accurate.
  }

  void cancelAllPending() {
    final pending = _tasks
        .where((task) =>
            task.status == ArtworkDownloadStatus.queued ||
            task.status == ArtworkDownloadStatus.downloading)
        .toList(growable: false);
    if (pending.isEmpty) {
      return;
    }
    for (final task in pending) {
      cancelTask(task);
    }
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
    while (
        _activeTaskIds.length < _maxConcurrentDownloads && _queue.isNotEmpty) {
      final task = _queue.removeAt(0);
      if (task.status == ArtworkDownloadStatus.canceled) {
        continue;
      }
      _activeTaskIds.add(task.id);
      unawaited(_downloadTask(task));
    }
  }

  void cancelBatch(ArtworkDownloadBatch batch) {
    for (final task in batch.tasks.where((task) => task.isActive)) {
      cancelTask(task);
    }
  }

  void resumeBatch(ArtworkDownloadBatch batch) {
    final resumable = batch.tasks.where(
      (task) => task.status == ArtworkDownloadStatus.canceled,
    );
    var changed = false;
    for (final task in resumable) {
      task.status = ArtworkDownloadStatus.queued;
      task.error = null;
      task.publishedUri = null;
      task.visiblePath = null;
      _queue.remove(task);
      _queue.add(task);
      changed = true;
    }
    if (changed) {
      notifyListeners();
      _pumpQueue();
    }
  }

  void retryBatchFailures(ArtworkDownloadBatch batch) {
    for (final task in batch.tasks) {
      if (task.status == ArtworkDownloadStatus.failed) {
        retryTask(task);
      }
    }
  }

  void removeBatch(ArtworkDownloadBatch batch) {
    cancelBatch(batch);
    _tasks.removeWhere((task) => task.batchId == batch.id);
    _queue.removeWhere((task) => task.batchId == batch.id);
    _batchProgressWaiters.remove(batch.id);
    notifyListeners();
  }

  Future<void> _downloadTask(ArtworkDownloadTask task) async {
    if (task.status == ArtworkDownloadStatus.canceled) {
      _releaseActiveSlot(task);
      return;
    }

    task.status = ArtworkDownloadStatus.downloading;
    notifyListeners();

    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;
    File? saveFile;
    try {
      saveFile = File(task.savePath);
      await saveFile.parent.create(recursive: true);
      final existingBytes =
          await saveFile.exists() ? await saveFile.length() : 0;
      final downloadUrl = proxiedImageUrl(task.sourceUrl);
      final response = await _dio.download(
        downloadUrl,
        task.savePath,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 25),
          sendTimeout: const Duration(seconds: 15),
          headers: {
            ...?imageRequestHeaders(task.sourceUrl, resolvedUrl: downloadUrl),
            if (existingBytes > 0) 'Range': 'bytes=$existingBytes-',
          },
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
        cancelToken: cancelToken,
        deleteOnError: false,
        fileAccessMode:
            existingBytes > 0 ? FileAccessMode.append : FileAccessMode.write,
        onReceiveProgress: (received, total) {
          if (task.status == ArtworkDownloadStatus.canceled) {
            return;
          }
          task.receivedBytes = existingBytes + received;
          task.totalBytes = total > 0 ? existingBytes + total : 0;
          _notifyProgressChanged();
        },
      );
      if (existingBytes > 0 &&
          response.statusCode != HttpStatus.partialContent) {
        // A proxy may ignore Range and return 200. Appending that response
        // would corrupt the image, so transparently retry this page cleanly.
        await saveFile.delete();
        task.receivedBytes = 0;
        task.totalBytes = 0;
        await _dio.download(
          downloadUrl,
          task.savePath,
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: true,
            receiveTimeout: const Duration(seconds: 25),
            sendTimeout: const Duration(seconds: 15),
            headers: imageRequestHeaders(
              task.sourceUrl,
              resolvedUrl: downloadUrl,
            ),
          ),
          cancelToken: cancelToken,
          deleteOnError: false,
          fileAccessMode: FileAccessMode.write,
          onReceiveProgress: (received, total) {
            if (task.status == ArtworkDownloadStatus.canceled) return;
            task.receivedBytes = received;
            task.totalBytes = total;
            _notifyProgressChanged();
          },
        );
      }
      if (task.status == ArtworkDownloadStatus.canceled ||
          cancelToken.isCancelled) {
        return;
      }
      await _waitForEarlierBatchTasks(task);
      if (task.status == ArtworkDownloadStatus.canceled ||
          cancelToken.isCancelled) {
        return;
      }
      final publishedUri = await GallerySaver.publishImage(
        sourcePath: task.savePath,
        displayName: path.basename(task.savePath),
        mimeType: _mimeTypeForPath(task.savePath),
        dateTaken: _gallerySortTimeForTask(task),
      );
      if (task.status == ArtworkDownloadStatus.canceled ||
          cancelToken.isCancelled) {
        return;
      }
      if (publishedUri != null) {
        task.publishedUri = publishedUri;
        task.visiblePath =
            'Pictures/PixivHelper/${path.basename(task.savePath)}';
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
      final canceled =
          error is DioException && error.type == DioExceptionType.cancel;
      if (canceled || cancelToken.isCancelled) {
        // A quick tap on "continue" may queue the task before Dio has
        // finished unwinding the canceled request. Preserve that queued state.
        if (task.status != ArtworkDownloadStatus.queued) {
          task.status = ArtworkDownloadStatus.canceled;
          task.error = null;
          task.publishedUri = null;
          task.visiblePath = null;
        }
      } else {
        task.status = ArtworkDownloadStatus.failed;
        task.error = error;
      }
    } finally {
      _cancelTokens.remove(task.id);
      _releaseActiveSlot(task);
      notifyListeners();
      _notifyBatchProgress(task.batchId);
      _completeFinishedBatches();
      _pumpQueue();
    }
  }

  void _releaseActiveSlot(ArtworkDownloadTask task) {
    _activeTaskIds.remove(task.id);
  }

  void removeTask(ArtworkDownloadTask task) {
    final wasActive = task.isActive;
    if (wasActive) {
      cancelTask(task);
    }
    _tasks.remove(task);
    _queue.remove(task);
    _cancelTokens.remove(task.id);
    _batchProgressWaiters.remove(task.batchId);
    notifyListeners();
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

  Future<Directory> _resolveDownloadDirectory() async {
    if (Platform.isAndroid) {
      final tempDirectory = await getTemporaryDirectory();
      final directory = Directory(
        path.join(tempDirectory.path, 'PixivHelper', 'downloads'),
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
      final directory = Directory(path.join(candidate.path, 'PixivHelper'));
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
