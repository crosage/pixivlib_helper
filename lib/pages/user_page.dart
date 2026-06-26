import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tagselector/model/author_model.dart';
import 'package:tagselector/model/system_summary_model.dart';
import 'package:tagselector/model/tag_model.dart';
import 'package:tagselector/components/app_avatar.dart';
import 'package:tagselector/pages/following_authors_page.dart';
import 'package:tagselector/service/api_service.dart';
import 'package:tagselector/service/app_user_session.dart';
import 'package:tagselector/service/detail_visit_stats.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  final ApiService _api = ApiService.instance;
  final AppUserSession _session = AppUserSession.instance;
  final DetailVisitStats _visitStats = DetailVisitStats.instance;
  final TextEditingController _cookieController = TextEditingController();

  SystemSummaryModel? _summary;
  List<ExtendedTag> _topTags = const [];
  List<DetailVisitRecord> _visitRecords = const [];
  Author? _activeAuthor;
  bool _dashboardLoading = false;
  bool _visitStatsLoading = false;
  Object? _dashboardError;
  int _dashboardLoadToken = 0;
  bool _submitting = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _session.addListener(_handleSessionChanged);
    _visitStats.addListener(_handleVisitStatsChanged);
    _loadDashboard();
  }

  @override
  void dispose() {
    _session.removeListener(_handleSessionChanged);
    _visitStats.removeListener(_handleVisitStatsChanged);
    _cookieController.dispose();
    super.dispose();
  }

  void _handleSessionChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _summary = null;
      _topTags = const [];
      _visitRecords = const [];
      _activeAuthor = null;
      _dashboardError = null;
    });
    _loadDashboard();
  }

  void _handleVisitStatsChanged() {
    if (!mounted) {
      return;
    }
    setState(() => _visitRecords = _visitStats.records);
    unawaited(_loadVisitStats(_dashboardLoadToken));
  }

  Future<void> _loadDashboard() async {
    final token = ++_dashboardLoadToken;
    final activeUser = _session.activeUser;
    setState(() {
      _dashboardLoading = true;
      _dashboardError = null;
    });

    unawaited(_loadCookie(token));
    unawaited(_loadActiveAuthorIntoState(token, activeUser?.pixivUserId ?? ''));
    unawaited(_loadVisitStats(token));

    try {
      final summary = await _api.fetchSystemSummary();
      if (!mounted || token != _dashboardLoadToken) {
        return;
      }
      setState(() => _summary = summary);
    } catch (error) {
      if (!mounted || token != _dashboardLoadToken) {
        return;
      }
      setState(() => _dashboardError = error);
    } finally {
      if (mounted && token == _dashboardLoadToken) {
        setState(() => _dashboardLoading = false);
      }
    }

    unawaited(_loadTopTags(token));
  }

  Future<void> _loadVisitStats(int token) async {
    if (mounted && token == _dashboardLoadToken) {
      setState(() => _visitStatsLoading = true);
    }
    try {
      final records = await _visitStats.loadRecords();
      if (!mounted || token != _dashboardLoadToken) {
        return;
      }
      setState(() {
        _visitRecords = records;
      });
    } catch (_) {
      // Local analytics are optional.
    } finally {
      if (mounted && token == _dashboardLoadToken) {
        setState(() => _visitStatsLoading = false);
      }
    }
  }

  Future<void> _loadCookie(int token) async {
    try {
      final connection = await _api.fetchPixivConnectionInfo();
      if (!mounted || token != _dashboardLoadToken) {
        return;
      }
      _cookieController.text = connection.cookie;
    } catch (_) {
      // Keep the session text field editable even if this request fails.
    }
  }

  Future<void> _loadTopTags(int token) async {
    try {
      final tags = await _api.fetchTagStatistics();
      tags.sort((a, b) => b.count.compareTo(a.count));
      if (!mounted || token != _dashboardLoadToken) {
        return;
      }
      setState(() => _topTags = tags.take(8).toList());
    } catch (_) {
      // Top tags are non-critical for opening the page.
    }
  }

  Future<void> _loadActiveAuthorIntoState(int token, String uid) async {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) {
      return;
    }
    try {
      final profile = await _api.fetchAuthorProfile(trimmedUid);
      if (!mounted || token != _dashboardLoadToken) {
        return;
      }
      setState(() => _activeAuthor = profile.author);
    } catch (_) {
      // Avatar refresh is non-critical for opening the page.
    }
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      await action();
      if (!mounted) {
        return;
      }
      setState(() {
        _message = successMessage;
      });
      _loadDashboard();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _openFollowingAuthors() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FollowingAuthorsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _session,
      builder: (context, _) {
        final activeUser = _session.activeUser;
        final activeAuthor = _activeAuthor;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_dashboardLoading) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 12),
            ],
            _SectionCard(
              child: Row(
                children: [
                  AppAvatar(
                    name: activeUser?.name ?? '用户',
                    avatarUrl: activeAuthor?.avatarUrl ?? '',
                    uid: activeAuthor?.uid ?? activeUser?.pixivUserId ?? '',
                    radius: 30,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeUser?.name ?? '未登录用户',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeUser?.pixivUserId.isNotEmpty == true
                              ? 'Pixiv UID ${activeUser!.pixivUserId}'
                              : '未绑定 Pixiv 用户',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _submitting
                        ? null
                        : () => _runAction(_session.logout, '已退出当前用户'),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('退出'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const _HelpCard(),
            const SizedBox(height: 12),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('切换用户', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _session.users.map((user) {
                      final selected = user.id == _session.activeUserId;
                      return ChoiceChip(
                        label: Text(
                          user.pixivUserId.trim().isEmpty
                              ? user.name
                              : '${user.name} · ${user.pixivUserId}',
                        ),
                        selected: selected,
                        onSelected: _submitting
                            ? null
                            : (_) => _runAction(
                                  () => _session.switchUser(user.id),
                                  '已切换到 ${user.name}',
                                ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.groups_2_outlined),
                title: const Text('关注作者'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _openFollowingAuthors,
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('总览', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (_dashboardError != null && _summary == null)
                    Text(
                      _dashboardError.toString(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFDC2626),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _StatBox(
                          label: '作者',
                          value: _summary == null
                              ? '...'
                              : '${_summary!.authorTotal}',
                        ),
                        _StatBox(
                          label: '图片',
                          value: _summary == null
                              ? '...'
                              : '${_summary!.imageTotal}',
                        ),
                        _StatBox(
                          label: '24h',
                          value: _summary == null
                              ? '...'
                              : '${_summary!.recent24hAdded}',
                        ),
                      ],
                    ),
                  const SizedBox(height: 14),
                  _VisitStatsPanel(
                    records: _visitRecords,
                    loading: _visitStatsLoading,
                  ),
                  if (_topTags.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _TopTagCloud(tags: _topTags),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Session', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _cookieController,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: '输入当前用户的 Pixiv session 或 PHPSESSID',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _submitting
                            ? null
                            : () => _runAction(
                                  () => _api.updatePixivCookie(
                                    _cookieController.text.trim(),
                                  ),
                                  '已更新当前用户 Session',
                                ),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('保存'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _submitting
                            ? null
                            : () {
                                setState(() {
                                  _message = null;
                                });
                                _loadDashboard();
                              },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('刷新'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF2563EB),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 20),
          ),
        ],
      ),
    );
  }
}

class _VisitStatsPanel extends StatelessWidget {
  final List<DetailVisitRecord> records;
  final bool loading;

  const _VisitStatsPanel({
    required this.records,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final recent24h = _withinHours(records, 24);
    final recent7d = _withinHours(records, 24 * 7);
    final topTags = _topTags(recent24h);
    final topAuthors = _topAuthors(recent24h);
    final hourBuckets = _hourBuckets(recent24h);
    final dayBuckets = _dayBuckets(recent7d);
    final tagTotal = _tagMentionCount(recent24h);

    if (loading && records.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(
              5,
              (_) => const _MetricSkeleton(),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 760;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: narrow ? double.infinity : 360,
                    child: const _ChartSkeleton(height: 156),
                  ),
                  SizedBox(
                    width: narrow ? double.infinity : 360,
                    child: const _ChartSkeleton(height: 156),
                  ),
                  SizedBox(
                    width: narrow ? double.infinity : 360,
                    child: const _ChartSkeleton(height: 156),
                  ),
                ],
              );
            },
          ),
        ],
      );
    }

    if (records.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text(
              '本地还没有详情页访问记录，打开任意作品详情后这里会自动开始统计。',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _FunStatCard(
              icon: Icons.visibility_rounded,
              label: '24h 打开',
              value: '${recent24h.length}',
              hint: '最近一天点过的详情页',
            ),
            _FunStatCard(
              icon: Icons.calendar_view_week_rounded,
              label: '7d 打开',
              value: '${recent7d.length}',
              hint: '最近一周的访问量',
            ),
            _FunStatCard(
              icon: Icons.local_offer_rounded,
              label: '24h tag',
              value: '${_distinctTagCount(recent24h)}',
              hint: '出现过的不同 tag',
            ),
            _FunStatCard(
              icon: Icons.person_rounded,
              label: '24h 作者',
              value: '${_distinctAuthorCount(recent24h)}',
              hint: '点开的作者数量',
            ),
            _FunStatCard(
              icon: Icons.all_inclusive_rounded,
              label: '累计',
              value: '${records.length}',
              hint: '全部记录数',
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 760;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: narrow ? double.infinity : 360,
                  child: _MiniChartCard(
                    title: '24h 时段',
                    child: _BarChart(buckets: hourBuckets),
                  ),
                ),
                SizedBox(
                  width: narrow ? double.infinity : 360,
                  child: _MiniChartCard(
                    title: '7d 走势',
                    child: _TrendBars(buckets: dayBuckets),
                  ),
                ),
                SizedBox(
                  width: narrow ? double.infinity : 360,
                  child: _MiniChartCard(
                    title: 'Tag 构成',
                    child: _DonutChart(
                      segments: topTags
                          .take(4)
                          .toList()
                          .asMap()
                          .entries
                          .map(
                            (entry) => _DonutSegment(
                              label: entry.value.label,
                              value: entry.value.count,
                              color: _segmentColorForIndex(entry.key),
                            ),
                          )
                          .toList(),
                      total: tagTotal,
                    ),
                  ),
                ),
                SizedBox(
                  width: narrow ? double.infinity : 360,
                  child: _MiniChartCard(
                    title: 'Top tag',
                    child: _RankingBars(
                      items: topTags,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ),
                SizedBox(
                  width: narrow ? double.infinity : 360,
                  child: _MiniChartCard(
                    title: 'Top 作者',
                    child: _RankingBars(
                      items: topAuthors,
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  List<DetailVisitRecord> _withinHours(
      List<DetailVisitRecord> records, int hours) {
    final cutoff = DateTime.now()
            .subtract(Duration(hours: hours))
            .millisecondsSinceEpoch ~/
        1000;
    return records.where((record) => record.visitedAt >= cutoff).toList();
  }

  List<_CountItem> _topTags(List<DetailVisitRecord> records) {
    final counts = <String, int>{};
    for (final record in records) {
      for (final tag in record.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final items = counts.entries
        .map((entry) => _CountItem(entry.key, entry.value))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return items.take(8).toList();
  }

  int _distinctTagCount(List<DetailVisitRecord> records) {
    final tags = <String>{};
    for (final record in records) {
      for (final tag in record.tags) {
        final trimmed = tag.trim();
        if (trimmed.isNotEmpty) {
          tags.add(trimmed);
        }
      }
    }
    return tags.length;
  }

  List<_CountItem> _topAuthors(List<DetailVisitRecord> records) {
    final counts = <String, int>{};
    for (final record in records) {
      final name = record.authorName.isEmpty ? '未知作者' : record.authorName;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final items = counts.entries
        .map((entry) => _CountItem(entry.key, entry.value))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return items.take(8).toList();
  }

  int _distinctAuthorCount(List<DetailVisitRecord> records) {
    final authors = <String>{};
    for (final record in records) {
      final name = record.authorName.trim();
      if (name.isNotEmpty) {
        authors.add(name);
      }
    }
    return authors.length;
  }

  int _tagMentionCount(List<DetailVisitRecord> records) {
    var total = 0;
    for (final record in records) {
      total += record.tags.where((tag) => tag.trim().isNotEmpty).length;
    }
    return total;
  }

  List<int> _hourBuckets(List<DetailVisitRecord> records) {
    final buckets = List<int>.filled(24, 0);
    for (final record in records) {
      final hour =
          DateTime.fromMillisecondsSinceEpoch(record.visitedAt * 1000).hour;
      buckets[hour]++;
    }
    return buckets;
  }

  List<int> _dayBuckets(List<DetailVisitRecord> records) {
    final buckets = List<int>.filled(7, 0);
    final now = DateTime.now();
    for (final record in records) {
      final visited =
          DateTime.fromMillisecondsSinceEpoch(record.visitedAt * 1000);
      final delta = now.difference(visited).inDays;
      if (delta >= 0 && delta < 7) {
        buckets[6 - delta]++;
      }
    }
    return buckets;
  }
}

class _CountItem {
  final String label;
  final int count;

  const _CountItem(this.label, this.count);
}

class _MetricSkeleton extends StatelessWidget {
  const _MetricSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      height: 84,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  static const _helpItems = [
    _HelpItem(
      icon: Icons.touch_app_rounded,
      title: '打开详情',
      text: '点击任意图片进入详情页，可查看作者、标签、多图分页和相关推荐。',
    ),
    _HelpItem(
      icon: Icons.download_rounded,
      title: '保存原图',
      text: '在首页、关注页或网格卡片长按图片，会开始保存该作品的 origin 原图。',
    ),
    _HelpItem(
      icon: Icons.downloading_rounded,
      title: '查看下载',
      text: '右下角悬浮按钮可查看下载进度、失败任务，并可取消卡住的任务。',
    ),
    _HelpItem(
      icon: Icons.favorite_rounded,
      title: '收藏作品',
      text: '点击图片卡片右上角爱心即可收藏或取消收藏，收藏后会尝试加载相似推荐。',
    ),
    _HelpItem(
      icon: Icons.filter_alt_rounded,
      title: '筛选图库',
      text: '图库页可按 tag、作者、收藏状态、本地/远程和时间区间筛选，也能保存预设。',
    ),
  ];

  const _HelpCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Icon(
                  Icons.help_outline_rounded,
                  color: Color(0xFF2563EB),
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('快速帮助',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    const Text(
                      '一些不太显眼但很常用的操作。',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _helpItems
                .map(
                  (item) => _HelpTip(item: item),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _HelpItem {
  final IconData icon;
  final String title;
  final String text;

  const _HelpItem({
    required this.icon,
    required this.title,
    required this.text,
  });
}

class _HelpTip extends StatelessWidget {
  final _HelpItem item;

  const _HelpTip({required this.item});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    return Container(
      width: narrow ? double.infinity : 280,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 18, color: const Color(0xFF3B82F6)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF243B53),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.text,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _MiniChartCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  final double height;

  const _ChartSkeleton({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<int> buckets;

  const _BarChart({required this.buckets});

  @override
  Widget build(BuildContext context) {
    final maxValue =
        buckets.isEmpty ? 0 : buckets.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 156,
      child: Column(
        children: [
          Expanded(
            child: _ChartWithYAxis(
              maxValue: maxValue,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(buckets.length, (index) {
                  final value = buckets[index];
                  final height = maxValue <= 0 ? 2.0 : (value / maxValue) * 108;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Tooltip(
                            message: '$index 点：$value 次',
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              height: height.clamp(2, 108),
                              decoration: BoxDecoration(
                                color: value == 0
                                    ? const Color(0xFFE2E8F0)
                                    : const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0',
                  style: TextStyle(fontSize: 9, color: Color(0xFF64748B))),
              Text('6',
                  style: TextStyle(fontSize: 9, color: Color(0xFF64748B))),
              Text('12',
                  style: TextStyle(fontSize: 9, color: Color(0xFF64748B))),
              Text('18',
                  style: TextStyle(fontSize: 9, color: Color(0xFF64748B))),
              Text('23',
                  style: TextStyle(fontSize: 9, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendBars extends StatelessWidget {
  final List<int> buckets;

  const _TrendBars({required this.buckets});

  @override
  Widget build(BuildContext context) {
    final maxValue =
        buckets.isEmpty ? 0 : buckets.reduce((a, b) => a > b ? a : b);
    const labels = ['-6', '-5', '-4', '-3', '-2', '-1', '0'];
    return SizedBox(
      height: 156,
      child: _ChartWithYAxis(
        maxValue: maxValue,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(buckets.length, (index) {
            final value = buckets[index];
            final height = maxValue <= 0 ? 2.0 : (value / maxValue) * 108;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: '${labels[index]} 天：$value 次',
                      child: Container(
                        height: height.clamp(2, 108),
                        decoration: BoxDecoration(
                          color: value == 0
                              ? const Color(0xFFD6E4F7)
                              : const Color(0xFF0F766E),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[index],
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _ChartWithYAxis extends StatelessWidget {
  final int maxValue;
  final Widget child;

  const _ChartWithYAxis({
    required this.maxValue,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final top = maxValue <= 0 ? 1 : maxValue;
    final middle = (top / 2).round();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '次数',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              _AxisLabel('$top'),
              const Spacer(),
              _AxisLabel('$middle'),
              const Spacer(),
              const _AxisLabel('0'),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Stack(
            children: [
              const Positioned.fill(child: _ChartGridLines()),
              Positioned.fill(child: child),
            ],
          ),
        ),
      ],
    );
  }
}

class _AxisLabel extends StatelessWidget {
  final String label;

  const _AxisLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 9,
        height: 1,
        color: Color(0xFF94A3B8),
      ),
    );
  }
}

class _ChartGridLines extends StatelessWidget {
  const _ChartGridLines();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(
        3,
        (_) => const Divider(
          height: 1,
          thickness: 1,
          color: Color(0xFFE5EAF2),
        ),
      ),
    );
  }
}

class _DonutSegment {
  final String label;
  final int value;
  final Color color;

  const _DonutSegment({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _DonutChart extends StatelessWidget {
  final List<_DonutSegment> segments;
  final int total;

  const _DonutChart({
    required this.segments,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final safeTotal = total <= 0 ? 1 : total;
    return SizedBox(
      height: 156,
      child: Row(
        children: [
          SizedBox(
            width: 118,
            height: 118,
            child: CustomPaint(
              painter: _DonutChartPainter(segments: segments, total: safeTotal),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const Text(
                      'events',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final segment in segments.take(3)) ...[
                  _LegendRow(
                    color: segment.color,
                    label: segment.label,
                    value: segment.value,
                    total: safeTotal,
                  ),
                  const SizedBox(height: 8),
                ],
                _LegendRow(
                  color: const Color(0xFFD6E4F7),
                  label: 'other',
                  value: math.max(
                    0,
                    safeTotal -
                        segments.fold<int>(0, (sum, s) => sum + s.value),
                  ),
                  total: safeTotal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  final int total;

  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final percent = total <= 0 ? 0 : (value / total * 100).round();
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '$value  $percent%',
          style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final int total;

  const _DonutChartPainter({
    required this.segments,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..color = const Color(0xFFE2E8F0)
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, basePaint);

    if (segments.isEmpty || total <= 0) {
      return;
    }

    var start = -math.pi / 2;
    for (final segment in segments) {
      final sweep = math.pi * 2 * (segment.value / total);
      if (sweep <= 0) {
        continue;
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = segment.color
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep + 0.03;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.total != total || oldDelegate.segments != segments;
  }
}

class _RankingBars extends StatelessWidget {
  final List<_CountItem> items;
  final Color color;

  const _RankingBars({
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 112,
        child: Center(
          child: Text(
            '暂无数据',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }
    final maxValue = items.first.count <= 0 ? 1 : items.first.count;
    return Column(
      children: [
        for (final item in items.take(5)) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 8,
                      color: const Color(0xFFE2E8F0),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: (item.count / maxValue).clamp(0.05, 1.0),
                        child: Container(color: color),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 26,
                  child: Text(
                    '${item.count}',
                    textAlign: TextAlign.right,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

Color _segmentColorForIndex(int index) {
  const colors = [
    Color(0xFF2563EB),
    Color(0xFF0F766E),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
  ];
  return colors[index.clamp(0, colors.length - 1)];
}

class _FunStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String hint;

  const _FunStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF2563EB)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopTagCloud extends StatelessWidget {
  final List<ExtendedTag> tags;

  const _TopTagCloud({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags
          .take(10)
          .map(
            (tag) => _TagPill(
              label: tag.name,
              count: tag.count,
            ),
          )
          .toList(),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String label;
  final int count;

  const _TagPill({
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        '$label · $count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
      ),
    );
  }
}
