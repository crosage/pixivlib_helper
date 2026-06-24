import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:tagselector/components/mobile_chrome.dart';
import 'package:tagselector/service/artwork_download_manager.dart';

Future<void> showDownloadProgressSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) {
      return DeferredSheetContent(
        placeholder: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.42,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        builder: (_) => const DownloadProgressSheet(),
      );
    },
  );
}

class DownloadProgressSheet extends StatelessWidget {
  const DownloadProgressSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = ArtworkDownloadManager.instance;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;

    return SafeArea(
      child: AnimatedBuilder(
        animation: manager,
        builder: (context, _) {
          final tasks = manager.tasks;
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '下载任务',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      if (manager.failedTaskCount > 0)
                        TextButton.icon(
                          onPressed: manager.retryFailedTasks,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('重试失败'),
                        ),
                      if (tasks.any((task) => !task.isActive))
                        TextButton(
                          onPressed: manager.clearFinished,
                          child: const Text('清理完成项'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '进行中 ${manager.activeTaskCount} · 已完成 ${manager.completedTaskCount} · 失败 ${manager.failedTaskCount}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (tasks.isEmpty)
                    const _EmptyDownloads()
                  else
                    Flexible(
              child: ListView.separated(
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _DownloadTaskTile(task: tasks[index]);
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        children: [
          Icon(Icons.download_done_rounded, size: 34, color: Color(0xFF94A3B8)),
          SizedBox(height: 8),
          Text(
            '还没有下载任务',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadTaskTile extends StatelessWidget {
  final ArtworkDownloadTask task;

  const _DownloadTaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final progress = task.progress;
    final statusText = switch (task.status) {
      ArtworkDownloadStatus.queued => '等待中',
      ArtworkDownloadStatus.downloading => progress == null
          ? '下载中'
          : '下载中 ${(progress * 100).toStringAsFixed(0)}%',
      ArtworkDownloadStatus.completed => '已保存',
      ArtworkDownloadStatus.failed => '失败',
      ArtworkDownloadStatus.canceled => '已取消',
    };
    final statusColor = switch (task.status) {
      ArtworkDownloadStatus.completed => const Color(0xFF16A34A),
      ArtworkDownloadStatus.failed => const Color(0xFFE11D48),
      ArtworkDownloadStatus.canceled => const Color(0xFF94A3B8),
      ArtworkDownloadStatus.queued => const Color(0xFF64748B),
      ArtworkDownloadStatus.downloading => const Color(0xFF0A84FF),
    };
    final pageText =
        task.pageCount > 1 ? 'P${task.pageIndex + 1}/${task.pageCount}' : '单图';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EEF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  _iconForStatus(task.status),
                  size: 17,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${task.pid} · $pageText · ${_formatBytes(task.receivedBytes, task.totalBytes)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _TaskActionStrip(
                task: task,
                statusText: statusText,
                statusColor: statusColor,
              ),
            ],
          ),
          if (task.status == ArtworkDownloadStatus.downloading ||
              task.status == ArtworkDownloadStatus.queued) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: progress,
                backgroundColor: const Color(0xFFEFF2F7),
                valueColor: AlwaysStoppedAnimation<Color>(
                  statusColor.withValues(alpha: 0.9),
                ),
              ),
            ),
            const SizedBox(height: 7),
          ] else
            const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _displayPath(task.visiblePath ?? task.savePath),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
              if (task.status == ArtworkDownloadStatus.completed &&
                  !Platform.isAndroid)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: '打开所在目录',
                  onPressed: () => _openParentDirectory(task.savePath),
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                ),
            ],
          ),
          if (task.status == ArtworkDownloadStatus.failed &&
              task.error != null) ...[
            const SizedBox(height: 4),
            Text(
              task.error.toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFE11D48),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconForStatus(ArtworkDownloadStatus status) {
    return switch (status) {
      ArtworkDownloadStatus.queued => Icons.schedule_rounded,
      ArtworkDownloadStatus.downloading => Icons.downloading_rounded,
      ArtworkDownloadStatus.completed => Icons.check_rounded,
      ArtworkDownloadStatus.failed => Icons.error_outline_rounded,
      ArtworkDownloadStatus.canceled => Icons.close_rounded,
    };
  }

  static String _formatBytes(int received, int total) {
    if (total <= 0) {
      return received <= 0 ? '未知大小' : _bytes(received);
    }
    return '${_bytes(received)} / ${_bytes(total)}';
  }

  static String _bytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    final exp = math.min(
      (math.log(bytes) / math.log(1024)).floor(),
      units.length - 1,
    );
    final value = bytes / math.pow(1024, exp);
    return '${value.toStringAsFixed(exp == 0 ? 0 : 1)} ${units[exp]}';
  }

  static String _displayPath(String savePath) {
    final directory = path.dirname(savePath);
    final fileName = path.basename(savePath);
    return '$directory${Platform.pathSeparator}$fileName';
  }

  static Future<void> _openParentDirectory(String savePath) async {
    final directory = path.dirname(savePath);
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [directory]);
      return;
    }
    if (Platform.isMacOS) {
      await Process.run('open', [directory]);
      return;
    }
    if (Platform.isLinux) {
      await Process.run('xdg-open', [directory]);
    }
  }
}

class _TaskActionStrip extends StatelessWidget {
  final ArtworkDownloadTask task;
  final String statusText;
  final Color statusColor;

  const _TaskActionStrip({
    required this.task,
    required this.statusText,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final manager = ArtworkDownloadManager.instance;
    final canCancel = task.status == ArtworkDownloadStatus.queued ||
        task.status == ArtworkDownloadStatus.downloading;
    final canDelete = task.status == ArtworkDownloadStatus.canceled ||
        task.status == ArtworkDownloadStatus.failed ||
        task.status == ArtworkDownloadStatus.completed;
    final canRetry = task.status == ArtworkDownloadStatus.failed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          statusText,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: statusColor,
          ),
        ),
        const SizedBox(height: 2),
        Wrap(
          spacing: 4,
          children: [
            if (canCancel)
              TextButton(
                onPressed: () => manager.cancelTask(task),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('取消'),
              ),
            if (canDelete)
              TextButton(
                onPressed: () => manager.removeTask(task),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('删除'),
              ),
            if (canRetry)
              TextButton(
                onPressed: () => manager.retryTask(task),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('重试'),
              ),
          ],
        ),
      ],
    );
  }
}
