import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tagselector/model/author_model.dart';
import 'package:tagselector/model/image_model.dart';
import 'package:tagselector/model/image_url_model.dart';
import 'package:tagselector/model/tag_model.dart';
import 'package:tagselector/pages/full_image_page.dart';
import 'package:tagselector/service/cache_proxy_manager.dart';
import 'package:tagselector/service/detail_visit_stats.dart';
import 'package:tagselector/service/remote_image_url.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final DetailVisitStats _stats = DetailVisitStats.instance;
  final TextEditingController _searchController = TextEditingController();

  List<DetailVisitRecord> _records = const [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _stats.addListener(_handleRecordsChanged);
    unawaited(_loadRecords());
  }

  @override
  void dispose() {
    _stats.removeListener(_handleRecordsChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    final records = await _stats.loadRecords();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  void _handleRecordsChanged() {
    if (!mounted) return;
    setState(() => _records = _stats.records);
  }

  List<DetailVisitRecord> get _visibleRecords {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _records;
    return _records.where((record) {
      return record.pid.toString().contains(query) ||
          record.title.toLowerCase().contains(query) ||
          record.authorName.toLowerCase().contains(query) ||
          record.authorUid.toLowerCase().contains(query) ||
          record.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList(growable: false);
  }

  Future<void> _openRecord(DetailVisitRecord record) async {
    final image = ImageModel(
      id: 0,
      pid: record.pid,
      author: Author(
        id: 0,
        name: record.authorName,
        uid: record.authorUid,
        avatarUrl: '',
        avatarUpdatedAt: 0,
        avatarNeedsRefresh: false,
      ),
      tags: record.tags
          .map((name) => Tag(id: 0, name: name, translateName: ''))
          .toList(growable: false),
      name: record.title,
      pages: const [],
      bookmarkCount: 0,
      isBookmarked: false,
      publishedAt: 0,
      updatedAt: 0,
      needsRefresh: false,
      urls: ImageUrlsModel(
        original: '',
        mini: record.thumbnailUrl,
        thumb: record.thumbnailUrl,
        small: record.thumbnailUrl,
        regular: record.thumbnailUrl,
      ),
    );
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FullImagePage(image: image)),
    );
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空浏览历史？'),
        content: const Text('这只会删除本机的详情页访问记录，无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _stats.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = _visibleRecords;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('浏览历史'),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              onPressed: _clearHistory,
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '清空浏览历史',
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: '搜索标题、作者、Tag 或 PID',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                          tooltip: '清除搜索',
                        ),
                ),
              ),
            ),
            Expanded(child: _buildBody(records)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<DetailVisitRecord> records) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_records.isEmpty) {
      return const _HistoryEmptyState(
        icon: Icons.history_rounded,
        title: '还没有浏览记录',
        description: '打开任意作品详情后，会自动保存在这里。',
      );
    }
    if (records.isEmpty) {
      return const _HistoryEmptyState(
        icon: Icons.search_off_rounded,
        title: '没有匹配的记录',
        description: '试试搜索作者名、作品标题、Tag 或 PID。',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
      cacheExtent: 400,
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        final section = _sectionFor(record.visitedAt);
        final previousSection = index == 0
            ? null
            : _sectionFor(records[index - 1].visitedAt);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (section != previousSection)
              Padding(
                padding: EdgeInsets.fromLTRB(4, index == 0 ? 4 : 18, 4, 8),
                child: Text(
                  section,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Dismissible(
                key: ValueKey('history-${record.pid}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  padding: const EdgeInsets.only(right: 22),
                  alignment: Alignment.centerRight,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white,
                  ),
                ),
                onDismissed: (_) {
                  unawaited(_stats.remove(record.pid));
                },
                child: _HistoryTile(
                  record: record,
                  onTap: () => _openRecord(record),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _sectionFor(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return '今天';
    if (difference == 1) return '昨天';
    if (difference < 7) return '最近 7 天';
    return '更早';
  }
}

class _HistoryTile extends StatelessWidget {
  final DetailVisitRecord record;
  final VoidCallback onTap;

  const _HistoryTile({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final visitedAt =
        DateTime.fromMillisecondsSinceEpoch(record.visitedAt * 1000);
    final time = '${visitedAt.hour.toString().padLeft(2, '0')}:'
        '${visitedAt.minute.toString().padLeft(2, '0')}';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 104,
          child: Row(
            children: [
              SizedBox(
                width: 104,
                height: 104,
                child: record.thumbnailUrl.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFFEFF2F6),
                        child: Icon(Icons.image_outlined,
                            color: Color(0xFF94A3B8)),
                      )
                    : CachedNetworkImage(
                        imageUrl: proxiedImageUrl(record.thumbnailUrl),
                        cacheManager: imageProxyCacheManager,
                        httpHeaders: imageRequestHeaders(record.thumbnailUrl),
                        fit: BoxFit.cover,
                        memCacheWidth: 320,
                        maxWidthDiskCache: 480,
                        fadeInDuration: Duration.zero,
                        placeholder: (_, __) =>
                            const ColoredBox(color: Color(0xFFEFF2F6)),
                        errorWidget: (_, __, ___) => const ColoredBox(
                          color: Color(0xFFEFF2F6),
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.title.isEmpty ? '未命名作品' : record.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        record.authorName.isEmpty
                            ? '未知作者'
                            : record.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            'PID ${record.pid}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFC7CDD6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _HistoryEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}
