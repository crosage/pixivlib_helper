import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tagselector/model/system_summary_model.dart';
import 'package:tagselector/model/tag_model.dart';
import 'package:tagselector/service/api_service.dart';
import 'package:tagselector/utils.dart';

class TagCountPage extends StatefulWidget {
  const TagCountPage({super.key});

  @override
  State<TagCountPage> createState() => _TagCountPageState();
}

class _TagCountPageState extends State<TagCountPage> {
  final ApiService _api = ApiService.instance;

  late Future<_StatisticsDashboardData> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
  }

  Future<_StatisticsDashboardData> _loadDashboard() async {
    final results = await Future.wait([
      _api.fetchSystemSummary(),
      _api.fetchTagStatistics(),
    ]);

    return _StatisticsDashboardData(
      summary: results[0] as SystemSummaryModel,
      tags: results[1] as List<ExtendedTag>,
    );
  }

  void _reload() {
    setState(() {
      _dashboardFuture = _loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: FutureBuilder<_StatisticsDashboardData>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final dashboard = snapshot.data!;
          final summary = dashboard.summary;
          final tags = [...dashboard.tags]..sort((a, b) => b.count - a.count);
          final topTags = tags.take(16).toList();
          final tagTotalCount = math.max(
            1,
            topTags.fold<int>(0, (sum, item) => sum + item.count),
          );
          final libraryTotal = math.max(summary.imageTotal, 1);

          return LayoutBuilder(
            builder: (context, constraints) {
              final pageWidth = constraints.maxWidth;
              final compact = pageWidth < 760;
              final stacked = pageWidth < 1180;
              final pagePadding = compact ? 16.0 : 24.0;
              final gap = compact ? 10.0 : 12.0;
              final halfWidth = compact
                  ? pageWidth - pagePadding * 2
                  : ((pageWidth - pagePadding * 2 - gap) / 2)
                      .clamp(240.0, 420.0)
                      .toDouble();
              final regularCardWidth = compact
                  ? pageWidth - pagePadding * 2
                  : stacked
                      ? halfWidth
                      : 220.0;
              final wideCardWidth =
                  stacked ? pageWidth - pagePadding * 2 : 420.0;

              return SingleChildScrollView(
                padding: EdgeInsets.all(pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 880),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '系统总览',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontSize: compact ? 24 : 28,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '这里不只是看几个数字，而是帮你快速判断图库结构、同步健康度，以及今天值得先看的内容。',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: const Color(0xFF64748B),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('刷新'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        _StatCard(
                          width: regularCardWidth,
                          label: '图片总数',
                          value: '${summary.imageTotal}',
                          hint: '当前库里已登记的作品数量',
                          icon: Icons.image_outlined,
                        ),
                        _StatCard(
                          width: regularCardWidth,
                          label: '作者总数',
                          value: '${summary.authorTotal}',
                          hint: '当前已入库作者数量',
                          icon: Icons.groups_2_outlined,
                        ),
                        _StatCard(
                          width: regularCardWidth,
                          label: '最近 24 小时新增',
                          value: '${summary.recent24hAdded}',
                          hint: '帮助你判断今天是否有明显的入库增量',
                          icon: Icons.bolt_rounded,
                        ),
                        _StatCard(
                          width: regularCardWidth,
                          label: '运行中任务',
                          value: '${summary.runningTaskCount}',
                          hint: '后台抓取、导入、刷新等仍在执行的任务',
                          icon: Icons.sync_rounded,
                        ),
                        _StatCard(
                          width: regularCardWidth,
                          label: '最近失败',
                          value: '${summary.recentFailureCount}',
                          hint: '24 小时内异常次数，过高时优先检查 cookie、代理和网络',
                          icon: Icons.warning_amber_rounded,
                          accentColor: const Color(0xFFB45309),
                        ),
                        _StatCard(
                          width: wideCardWidth,
                          label: '缓存体积',
                          value: _formatBytes(summary.cacheTotalBytes),
                          hint:
                              '${summary.cacheFileCount} 个文件，缓存目录：${summary.cachePath.isEmpty ? '-' : summary.cachePath}',
                          icon: Icons.folder_outlined,
                          wide: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (stacked) ...[
                      _InsightPanel(
                        summary: summary,
                        bookmarkedRatio: summary.bookmarkedTotal / libraryTotal,
                        recentRatio: summary.recent24hAdded / libraryTotal,
                      ),
                      const SizedBox(height: 16),
                      _TopTagsPanel(
                        topTags: topTags,
                        tagTotalCount: tagTotalCount,
                      ),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _InsightPanel(
                              summary: summary,
                              bookmarkedRatio:
                                  summary.bookmarkedTotal / libraryTotal,
                              recentRatio:
                                  summary.recent24hAdded / libraryTotal,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _TopTagsPanel(
                              topTags: topTags,
                              tagTotalCount: tagTotalCount,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    final precision = size >= 100 ? 0 : (size >= 10 ? 1 : 2);
    return '${size.toStringAsFixed(precision)} ${units[unitIndex]}';
  }
}

class _StatisticsDashboardData {
  final SystemSummaryModel summary;
  final List<ExtendedTag> tags;

  const _StatisticsDashboardData({
    required this.summary,
    required this.tags,
  });
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFE),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final bool wide;
  final Color accentColor;

  const _StatCard({
    required this.width,
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    this.wide = false,
    this.accentColor = const Color(0xFF2563EB),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 18, color: accentColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              maxLines: wide ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF243B53),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              maxLines: wide ? 3 : 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightPanel extends StatelessWidget {
  final SystemSummaryModel summary;
  final double bookmarkedRatio;
  final double recentRatio;

  const _InsightPanel({
    required this.summary,
    required this.bookmarkedRatio,
    required this.recentRatio,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '内容结构',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            '这里更适合快速判断图库的收藏沉淀和近期活跃度，帮你看出最近是不是还在持续进新图。',
            style: TextStyle(
              color: Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          _RatioRow(
            label: '已收藏占比',
            value: '${summary.bookmarkedTotal} / ${summary.imageTotal}',
            ratio: bookmarkedRatio,
            color: const Color(0xFFE11D48),
          ),
          const SizedBox(height: 12),
          _RatioRow(
            label: '24 小时活跃度',
            value: '${summary.recent24hAdded} / ${summary.imageTotal}',
            ratio: recentRatio,
            color: const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }
}

class _RatioRow extends StatelessWidget {
  final String label;
  final String value;
  final double ratio;
  final Color color;

  const _RatioRow({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (ratio.clamp(0.0, 1.0) * 100).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ),
            Text(
              '$percent%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _TopTagsPanel extends StatelessWidget {
  final List<ExtendedTag> topTags;
  final int tagTotalCount;

  const _TopTagsPanel({
    required this.topTags,
    required this.tagTotalCount,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '高频标签',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            '这里比饼图更适合快速看出图库的主要构成，方便你判断自己最近更偏向哪些题材。',
            style: TextStyle(
              color: Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          if (topTags.isEmpty)
            const Text(
              '当前还没有可展示的标签统计。',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
          ...topTags.map((tag) {
            final ratio = tag.count / tagTotalCount;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tag.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${tag.count}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      minHeight: 7,
                      color: getRandomColor(tag.name.hashCode),
                      backgroundColor: const Color(0xFFE5E7EB),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
