import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tagselector/service/artwork_download_manager.dart';

Future<void> showDownloadProgressSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .58,
      minChildSize: .28,
      maxChildSize: .92,
      snap: true,
      snapSizes: const [.42, .72],
      builder: (_, scrollController) => DownloadProgressSheet(
        scrollController: scrollController,
      ),
    ),
  );
}

class DownloadProgressSheet extends StatelessWidget {
  final ScrollController? scrollController;

  const DownloadProgressSheet({super.key, this.scrollController});

  @override
  Widget build(BuildContext context) {
    final manager = ArtworkDownloadManager.instance;
    return SafeArea(
      child: AnimatedBuilder(
        animation: manager,
        builder: (context, _) {
          final batches = manager.batches;
          final metadataStatus = manager.finalizingMetadataBatchCount > 0
              ? ' · 正在整理顺序'
              : manager.failedMetadataBatchCount > 0
                  ? ' · 顺序整理失败 ${manager.failedMetadataBatchCount}'
                  : '';
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(
                      child: Text('下载任务',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827)))),
                  if (manager.activeTaskCount > 0)
                    IconButton(
                        tooltip: '取消全部下载',
                        onPressed: manager.cancelAllPending,
                        icon: const Icon(Icons.stop_circle_outlined)),
                  if (manager.hasClearableFinishedBatches)
                    IconButton(
                        tooltip: '清理已结束任务',
                        onPressed: manager.clearFinished,
                        icon: const Icon(Icons.delete_sweep_outlined)),
                ]),
                const SizedBox(height: 3),
                Text(
                  '作品 ${batches.length} · 下载中 ${manager.activeBatchCount} · '
                  '已完成 ${manager.completedTaskCount} 张$metadataStatus',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                if (batches.isEmpty)
                  const _EmptyDownloads()
                else
                  Flexible(
                      child: ListView.separated(
                    controller: scrollController,
                    itemCount: batches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) =>
                        _DownloadBatchTile(batch: batches[index]),
                  )),
              ],
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
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB))),
        child: const Column(children: [
          Icon(Icons.download_done_rounded, size: 32, color: Color(0xFF94A3B8)),
          SizedBox(height: 8),
          Text('还没有下载任务',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: Color(0xFF334155)))
        ]),
      );
}

class _DownloadBatchTile extends StatefulWidget {
  final ArtworkDownloadBatch batch;
  const _DownloadBatchTile({required this.batch});
  @override
  State<_DownloadBatchTile> createState() => _DownloadBatchTileState();
}

class _DownloadBatchTileState extends State<_DownloadBatchTile> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final batch = widget.batch;
    final status = _statusFor(batch);
    final progress = batch.progress;
    final metadataError =
        ArtworkDownloadManager.instance.metadataErrorForBatch(batch.id);
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFFBFCFE),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE6EBF2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 8, 10),
            child: Row(children: [
              _StatusIcon(status: status),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(batch.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B))),
                    const SizedBox(height: 3),
                    Text(
                        '${batch.pid} · ${batch.quality.label} · ${batch.completedCount}/${batch.tasks.length} 张${batch.hasCanceled ? ' · 可继续' : ''}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B))),
                  ])),
              _BatchMenu(batch: batch),
              Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: const Color(0xFF64748B)),
            ]),
          ),
        ),
        if (batch.isActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                    minHeight: 4,
                    value: progress,
                    backgroundColor: const Color(0xFFE8EEF6))),
          ),
        if (_expanded) ...[
          const Divider(height: 1, color: Color(0xFFE6EBF2)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text('保存到 ${_displayPath(batch.firstSaveDirectory)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ),
          if (metadataError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SelectableText(
                '顺序整理失败：$metadataError',
                style: const TextStyle(fontSize: 11, color: Color(0xFFB42318)),
              ),
            ),
          for (final task in batch.tasks) _PageRow(task: task),
          if (!Platform.isAndroid && batch.completedCount > 0)
            Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                    onPressed: () => _openDirectory(batch.firstSaveDirectory),
                    icon: const Icon(Icons.folder_open_rounded, size: 17),
                    label: const Text('打开文件夹'))),
        ],
      ]),
    );
  }

  _BatchStatus _statusFor(ArtworkDownloadBatch batch) {
    if (batch.isActive) return _BatchStatus.active;
    if (batch.hasFailed) return _BatchStatus.failed;
    if (batch.hasCanceled) return _BatchStatus.canceled;
    return _BatchStatus.completed;
  }
}

class _BatchMenu extends StatelessWidget {
  final ArtworkDownloadBatch batch;
  const _BatchMenu({required this.batch});
  @override
  Widget build(BuildContext context) {
    final manager = ArtworkDownloadManager.instance;
    return PopupMenuButton<_BatchAction>(
      tooltip: '任务操作',
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (action) {
        switch (action) {
          case _BatchAction.cancel:
            manager.cancelBatch(batch);
          case _BatchAction.resume:
            manager.resumeBatch(batch);
          case _BatchAction.retry:
            manager.retryBatchFailures(batch);
          case _BatchAction.reorder:
            manager.retryBatchMetadata(batch);
          case _BatchAction.remove:
            manager.removeBatch(batch);
        }
      },
      itemBuilder: (_) => [
        if (batch.isActive)
          const PopupMenuItem(value: _BatchAction.cancel, child: Text('取消下载')),
        if (batch.hasCanceled)
          const PopupMenuItem(value: _BatchAction.resume, child: Text('继续下载')),
        if (batch.hasFailed)
          const PopupMenuItem(value: _BatchAction.retry, child: Text('重试失败项')),
        if (manager.hasMetadataError(batch.id))
          const PopupMenuItem(
            value: _BatchAction.reorder,
            child: Text('重新整理顺序'),
          ),
        if (!batch.isActive)
          const PopupMenuItem(value: _BatchAction.remove, child: Text('移除任务')),
      ],
    );
  }
}

enum _BatchAction { cancel, resume, retry, reorder, remove }

enum _BatchStatus { active, completed, failed, canceled }

class _StatusIcon extends StatelessWidget {
  final _BatchStatus status;
  const _StatusIcon({required this.status});
  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      _BatchStatus.active => (
          Icons.downloading_rounded,
          const Color(0xFF2563EB)
        ),
      _BatchStatus.completed => (
          Icons.check_circle_rounded,
          const Color(0xFF16A34A)
        ),
      _BatchStatus.failed => (
          Icons.error_outline_rounded,
          const Color(0xFFE11D48)
        ),
      _BatchStatus.canceled => (
          Icons.pause_circle_outline_rounded,
          const Color(0xFF64748B)
        ),
    };
    return Icon(icon, size: 22, color: color);
  }
}

class _PageRow extends StatelessWidget {
  final ArtworkDownloadTask task;
  const _PageRow({required this.task});
  @override
  Widget build(BuildContext context) {
    final label = switch (task.status) {
      ArtworkDownloadStatus.queued => '等待中',
      ArtworkDownloadStatus.downloading => '下载中',
      ArtworkDownloadStatus.completed => '已保存',
      ArtworkDownloadStatus.failed => '失败',
      ArtworkDownloadStatus.canceled => '已暂停',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(children: [
        SizedBox(
            width: 46,
            child: Text(task.pageCount > 1 ? 'P${task.pageIndex + 1}' : '单图',
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
        Expanded(
            child: Text(_formatBytes(task.receivedBytes, task.totalBytes),
                style:
                    const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF526176))),
      ]),
    );
  }
}

String _formatBytes(int received, int total) => total <= 0
    ? (received == 0 ? '大小未知' : _bytes(received))
    : '${_bytes(received)} / ${_bytes(total)}';
String _bytes(int value) {
  if (value <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  final exponent =
      math.min((math.log(value) / math.log(1024)).floor(), units.length - 1);
  return '${(value / math.pow(1024, exponent)).toStringAsFixed(exponent == 0 ? 0 : 1)} ${units[exponent]}';
}

String _displayPath(String value) => value.isEmpty ? 'PixivHelper' : value;
Future<void> _openDirectory(String directory) async {
  if (Platform.isWindows) {
    await Process.run('explorer.exe', [directory]);
  } else if (Platform.isMacOS) {
    await Process.run('open', [directory]);
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [directory]);
  }
}
