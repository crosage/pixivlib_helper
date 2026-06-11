import 'dart:async';

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

  SystemSummaryModel? _summary;
  List<ExtendedTag> _topTags = const [];
  Author? _activeAuthor;
  bool _dashboardLoading = false;
  Object? _dashboardError;
  int _dashboardLoadToken = 0;
  bool _submitting = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _session.addListener(_handleSessionChanged);
    _loadDashboard();
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
      _summary = null;
      _topTags = const [];
      _activeAuthor = null;
      _dashboardError = null;
    });
    _loadDashboard();
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
                  if (_topTags.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _topTags
                          .map((tag) => Chip(label: Text(tag.name)))
                          .toList(),
                    ),
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
