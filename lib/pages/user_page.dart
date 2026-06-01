import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tagselector/model/author_model.dart';
import 'package:tagselector/model/system_summary_model.dart';
import 'package:tagselector/model/tag_model.dart';
import 'package:tagselector/pages/following_authors_page.dart';
import 'package:tagselector/service/api_service.dart';
import 'package:tagselector/service/app_user_session.dart';
import 'package:tagselector/service/cache_proxy_manager.dart';
import 'package:tagselector/service/remote_image_url.dart';
import 'package:tagselector/utils.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  final ApiService _api = ApiService.instance;
  final AppUserSession _session = AppUserSession.instance;
  final TextEditingController _cookieController = TextEditingController();

  late Future<_UserDashboardData> _dashboardFuture;
  bool _submitting = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _session.addListener(_handleSessionChanged);
    _dashboardFuture = _loadDashboard();
  }

  @override
  void dispose() {
    _session.removeListener(_handleSessionChanged);
    _cookieController.dispose();
    super.dispose();
  }

  void _handleSessionChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _dashboardFuture = _loadDashboard();
    });
  }

  Future<_UserDashboardData> _loadDashboard() async {
    final activeUser = _session.activeUser;
    final results = await Future.wait([
      _api.fetchPixivConnectionInfo(),
      _api.fetchSystemSummary(),
      _api.fetchTagStatistics(),
      if (activeUser != null && activeUser.pixivUserId.trim().isNotEmpty)
        _loadActiveAuthor(activeUser.pixivUserId.trim())
      else
        Future<Author?>.value(null),
    ]);

    final connection = results[0] as PixivConnectionInfo;
    _cookieController.text = connection.cookie;

    final tags = (results[2] as List<ExtendedTag>)
      ..sort((a, b) => b.count.compareTo(a.count));

    return _UserDashboardData(
      summary: results[1] as SystemSummaryModel,
      topTags: tags.take(8).toList(),
      activeAuthor: results[3] as Author?,
    );
  }

  Future<Author?> _loadActiveAuthor(String uid) async {
    try {
      final profile = await _api.fetchAuthorProfile(uid);
      return profile.author;
    } catch (_) {
      return null;
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
        _dashboardFuture = _loadDashboard();
      });
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
        return FutureBuilder<_UserDashboardData>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                snapshot.data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError && snapshot.data == null) {
              return Center(child: Text(snapshot.error.toString()));
            }

            final data = snapshot.data;
            final activeUser = _session.activeUser;
            final activeAuthor = data?.activeAuthor;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionCard(
                  child: Row(
                    children: [
                      _UserAvatar(
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
                if (data != null) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('总览', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _StatBox(
                              label: '作者',
                              value: '${data.summary.authorTotal}',
                            ),
                            _StatBox(
                              label: '图片',
                              value: '${data.summary.imageTotal}',
                            ),
                            _StatBox(
                              label: '24h',
                              value: '${data.summary.recent24hAdded}',
                            ),
                          ],
                        ),
                        if (data.topTags.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: data.topTags
                                .map((tag) => Chip(label: Text(tag.name)))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
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
                                      _dashboardFuture = _loadDashboard();
                                    });
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
      },
    );
  }
}

class _UserDashboardData {
  final SystemSummaryModel summary;
  final List<ExtendedTag> topTags;
  final Author? activeAuthor;

  const _UserDashboardData({
    required this.summary,
    required this.topTags,
    required this.activeAuthor,
  });
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

class _UserAvatar extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final String uid;
  final double radius;

  const _UserAvatar({
    required this.name,
    required this.avatarUrl,
    required this.uid,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarUrl.trim().isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(
          proxiedImageUrl(avatarUrl),
          cacheManager: imageProxyCacheManager,
          headers: imageRequestHeaders(avatarUrl),
        ),
      );
    }

    final color = getRandomColor(uid.hashCode);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.18),
      child: Text(
        name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1D4ED8),
        ),
      ),
    );
  }
}
