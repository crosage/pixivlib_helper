import 'package:flutter/material.dart';
import 'package:tagselector/service/api_service.dart';
import 'package:tagselector/service/cache_proxy_manager.dart';

class TokenSetting extends StatefulWidget {
  const TokenSetting({super.key});

  @override
  State<TokenSetting> createState() => _TokenSettingState();
}

class _TokenSettingState extends State<TokenSetting> {
  final ApiService _api = ApiService.instance;
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
  }

  @override
  void dispose() {
    _cookieController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              'Pixiv 连接',
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 10),
            Text(
              '这里可以直接更新 Pixiv cookie，也可以查看图片缓存目录。缓存现在会持久化到应用目录，不再放在系统临时目录里。',
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
                  title: '当前用户',
                  value: username,
                  icon: Icons.person_outline_rounded,
                ),
                _StatusCard(
                  title: 'Cookie 长度',
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
                    'Cookie',
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
                      hintText: '把新的 Pixiv cookie 粘贴到这里',
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
                                  'Cookie 已更新。',
                                ),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('保存 Cookie'),
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
                    description: '重新抓取库里已有作品的数据，适合大范围修复收藏数等字段。',
                    actionLabel: '启动',
                    onPressed: _isSubmitting
                        ? null
                        : () => _runAction(
                              _api.triggerFullRefresh,
                              '全量更新任务已启动，请查看后端日志。',
                            ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ActionCard(
                    title: '0 收藏重试',
                    description: '优先刷新收藏数为 0 的作品，先修复最值得关注的脏数据。',
                    actionLabel: '启动',
                    onPressed: _isSubmitting
                        ? null
                        : () => _runAction(
                              _api.triggerZeroBookmarkRefresh,
                              '0 收藏重试任务已启动，请查看后端日志。',
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
                      Text(
                        '缓存会保存在应用支持目录，正常情况下不会被系统按临时文件自动清掉。你也可以直接打开目录查看具体文件。',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (cacheSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          stats == null)
                        const Center(child: CircularProgressIndicator())
                      else if (cacheSnapshot.hasError)
                        Text(
                          cacheSnapshot.error.toString(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.red.shade600,
                          ),
                        )
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
                        const SizedBox(height: 14),
                        _CacheStatTile(
                          label: '缓存路径',
                          value: stats.path,
                        ),
                        const SizedBox(height: 8),
                        _CacheStatTile(
                          label: '最近文件',
                          value: stats.recentFiles.isEmpty
                              ? '当前还没有缓存文件'
                              : '当前展示最近 ${stats.recentFiles.length} 个文件',
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
                                        '缓存目录已打开。',
                                      ),
                              icon: const Icon(Icons.folder_open_rounded),
                              label: const Text('打开目录'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _runCacheAction(
                                        clearImageCache,
                                        '缓存已清空。',
                                      ),
                              icon: const Icon(Icons.delete_sweep_rounded),
                              label: const Text('清空缓存'),
                            ),
                          ],
                        ),
                        if (stats.recentFiles.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 260),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.18),
                              ),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: stats.recentFiles.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final file = stats.recentFiles[index];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.image_outlined,
                                    size: 18,
                                  ),
                                  title: Text(
                                    file.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${_formatBytes(file.sizeBytes)} | ${_formatDateTime(file.modifiedAt)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
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

String _formatDateTime(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$month-$day $hour:$minute';
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

class _CacheStatTile extends StatelessWidget {
  final String label;
  final String value;

  const _CacheStatTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
