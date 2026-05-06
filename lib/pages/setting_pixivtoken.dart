import 'package:flutter/material.dart';
import 'package:tagselector/model/app_user_model.dart';
import 'package:tagselector/service/api_service.dart';
import 'package:tagselector/service/app_user_session.dart';
import 'package:tagselector/service/cache_proxy_manager.dart';

class TokenSetting extends StatefulWidget {
  const TokenSetting({super.key});

  @override
  State<TokenSetting> createState() => _TokenSettingState();
}

class _TokenSettingState extends State<TokenSetting> {
  final ApiService _api = ApiService.instance;
  final AppUserSession _session = AppUserSession.instance;
  final TextEditingController _cookieController = TextEditingController();

  late Future<PixivConnectionInfo> _connectionFuture;
  late Future<CacheDirectoryStats> _cacheStatsFuture;
  bool _isSubmitting = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _connectionFuture = _loadConnection();
    _cacheStatsFuture = _loadCacheStats();
    _session.addListener(_handleUserSessionChanged);
  }

  @override
  void dispose() {
    _session.removeListener(_handleUserSessionChanged);
    _cookieController.dispose();
    super.dispose();
  }

  void _handleUserSessionChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _connectionFuture = _loadConnection();
    });
  }

  Future<PixivConnectionInfo> _loadConnection() async {
    final info = await _api.fetchPixivConnectionInfo();
    _cookieController.text = info.cookie;
    return info;
  }

  Future<CacheDirectoryStats> _loadCacheStats() => collectImageCacheStats();

  Future<void> _runAction(
    Future<void> Function() action,
    String successText,
  ) async {
    setState(() {
      _isSubmitting = true;
      _message = null;
    });

    try {
      await action();
      setState(() {
        _message = successText;
        _connectionFuture = _loadConnection();
        _cacheStatsFuture = _loadCacheStats();
      });
    } catch (error) {
      setState(() {
        _message = error.toString();
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _runCacheAction(
    Future<void> Function() action,
    String successText,
  ) async {
    setState(() {
      _isSubmitting = true;
      _message = null;
    });

    try {
      await action();
      setState(() {
        _message = successText;
        _cacheStatsFuture = _loadCacheStats();
      });
    } catch (error) {
      setState(() {
        _message = error.toString();
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _switchUser(AppUserModel user) async {
    if (_session.activeUserId == user.id) {
      return;
    }
    await _runAction(() => _session.switchUser(user.id), '已切换当前用户');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _session,
      builder: (context, _) {
        final activeUser = _session.activeUser;
        final authenticatedUsers = _session.users
            .where((user) => user.pixivUserId.trim().isNotEmpty)
            .toList();

        return FutureBuilder<PixivConnectionInfo>(
          future: _connectionFuture,
          builder: (context, snapshot) {
            final info = snapshot.data;
            final username =
                info?.username.isNotEmpty == true ? info!.username : '未识别';

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '多用户设置',
                  style: theme.textTheme.headlineMedium?.copyWith(fontSize: 28),
                ),
                const SizedBox(height: 10),
                Text(
                  '前端和后端现在都以应用用户为边界隔离数据。进入应用依赖有效 session，这里只管理已经认证过的用户和当前用户的 Pixiv session。',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _StatusCard(
                      title: '当前应用用户',
                      value: activeUser?.name ?? '未加载',
                      icon: Icons.person_outline_rounded,
                    ),
                    _StatusCard(
                      title: 'Pixiv 用户 ID',
                      value: username,
                      icon: Icons.badge_outlined,
                    ),
                    _StatusCard(
                      title: 'Session 长度',
                      value: '${_cookieController.text.length} 字符',
                      icon: Icons.cookie_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: _cardDecoration(theme),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '已认证用户',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (authenticatedUsers.isEmpty)
                        Text(
                          '当前没有可切换的已认证用户，请先在登录页或下方更新有效 session。',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: authenticatedUsers.map((user) {
                            final selected = user.id == _session.activeUserId;
                            return ChoiceChip(
                              label: Text('${user.name} · ${user.pixivUserId}'),
                              selected: selected,
                              onSelected: _isSubmitting
                                  ? null
                                  : (_) => _switchUser(user),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: _cardDecoration(theme),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前用户 Session',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cookieController,
                        minLines: 5,
                        maxLines: 9,
                        decoration: InputDecoration(
                          hintText: '把当前用户对应的 Pixiv session 或 PHPSESSID 粘贴到这里',
                          filled: true,
                          fillColor: const Color(0xFFF6F7F8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: _isSubmitting
                                ? null
                                : () => _runAction(
                                      () => _api.updatePixivCookie(
                                        _cookieController.text.trim(),
                                      ),
                                      '当前用户 Session 已更新',
                                    ),
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('保存 Session'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isSubmitting
                                ? null
                                : () {
                                    setState(() {
                                      _connectionFuture = _loadConnection();
                                      _message = null;
                                    });
                                  },
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: const Text('重新读取'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        title: '全量更新',
                        description: '基于当前激活用户的数据重新刷新图库内容。',
                        actionLabel: '启动',
                        onPressed: _isSubmitting
                            ? null
                            : () => _runAction(
                                  _api.triggerFullRefresh,
                                  '全量更新任务已启动',
                                ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ActionCard(
                        title: '0 收藏重试',
                        description: '优先补刷收藏数异常的作品。',
                        actionLabel: '启动',
                        onPressed: _isSubmitting
                            ? null
                            : () => _runAction(
                                  _api.triggerZeroBookmarkRefresh,
                                  '0 收藏重试任务已启动',
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FutureBuilder<CacheDirectoryStats>(
                  future: _cacheStatsFuture,
                  builder: (context, cacheSnapshot) {
                    final stats = cacheSnapshot.data;

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: _cardDecoration(theme),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '图片缓存',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : () {
                                        setState(() {
                                          _cacheStatsFuture = _loadCacheStats();
                                        });
                                      },
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('刷新'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (cacheSnapshot.connectionState ==
                                  ConnectionState.waiting &&
                              stats == null)
                            const Center(child: CircularProgressIndicator())
                          else if (cacheSnapshot.hasError)
                            Text(cacheSnapshot.error.toString())
                          else if (stats != null) ...[
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                _StatusCard(
                                  title: '文件数',
                                  value: '${stats.fileCount}',
                                  icon: Icons.folder_copy_outlined,
                                ),
                                _StatusCard(
                                  title: '总大小',
                                  value: _formatBytes(stats.totalBytes),
                                  icon: Icons.storage_rounded,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: _isSubmitting
                                      ? null
                                      : () => _runCacheAction(
                                            openImageCacheDirectory,
                                            '缓存目录已打开',
                                          ),
                                  icon: const Icon(Icons.folder_open_rounded),
                                  label: const Text('打开目录'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _isSubmitting
                                      ? null
                                      : () => _runCacheAction(
                                            clearImageCache,
                                            '缓存已清空',
                                          ),
                                  icon: const Icon(Icons.delete_sweep_rounded),
                                  label: const Text('清空缓存'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _message!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.primary,
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

BoxDecoration _cardDecoration(ThemeData theme) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.18),
    ),
  );
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }

  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = -1;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  return '${value.toStringAsFixed(value >= 10 ? 1 : 2)} ${units[unitIndex]}';
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatusCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 260,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(theme).copyWith(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
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

class _ActionCard extends StatelessWidget {
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback? onPressed;

  const _ActionCard({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.tonal(
            onPressed: onPressed,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
