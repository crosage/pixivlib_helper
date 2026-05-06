import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tagselector/model/author_model.dart';
import 'package:tagselector/model/author_profile_model.dart';
import 'package:tagselector/model/followed_author_model.dart';
import 'package:tagselector/model/image_model.dart';
import 'package:tagselector/model/image_url_model.dart';
import 'package:tagselector/pages/full_image_page.dart';
import 'package:tagselector/service/api_service.dart';
import 'package:tagselector/service/cache_proxy_manager.dart';
import 'package:tagselector/service/remote_image_url.dart';
import 'package:tagselector/utils.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthorPage extends StatefulWidget {
  final Author author;

  const AuthorPage({
    super.key,
    required this.author,
  });

  @override
  State<AuthorPage> createState() => _AuthorPageState();
}

enum _AuthorWorksDisplayMode { list, grid }

class _AuthorPageState extends State<AuthorPage> {
  final ApiService _api = ApiService.instance;

  AuthorProfileModel? _profile;
  Object? _error;
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  Timer? _pollTimer;
  _AuthorWorksDisplayMode _worksDisplayMode = _AuthorWorksDisplayMode.grid;

  @override
  void initState() {
    super.initState();
    _profile = _buildPlaceholderProfile(widget.author);
    _fetchProfile();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchProfile({bool silent = false}) async {
    _pollTimer?.cancel();
    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final profile = await _api.fetchAuthorProfile(widget.author.uid);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _error = null;
        _isLoading = false;
        _hasLoadedOnce = true;
      });
      _schedulePoll(profile);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  void _schedulePoll(AuthorProfileModel profile) {
    final shouldPoll =
        profile.syncSummary.inProgress || profile.syncSummary.queued > 0;
    if (!shouldPoll) {
      return;
    }

    _pollTimer = Timer(
      const Duration(seconds: 2),
      () => _fetchProfile(silent: true),
    );
  }

  void _refresh() {
    _fetchProfile();
  }

  bool _shouldShowSyncBanner(AuthorProfileModel profile) {
    return false;
  }

  Future<void> _openPreview(
    AuthorProfileModel profile,
    FollowedAuthorWorkPreview preview,
  ) async {
    final image = ImageModel(
      id: 0,
      pid: preview.pid,
      author: profile.author,
      tags: const [],
      name: preview.title,
      pages: const [],
      bookmarkCount: preview.bookmarkCount,
      isBookmarked: false,
      publishedAt: preview.publishedAt,
      updatedAt: 0,
      needsRefresh: false,
      urls: ImageUrlsModel(
        original: '',
        mini: '',
        thumb: preview.thumbUrl,
        small: preview.thumbUrl,
        regular: preview.thumbUrl,
      ),
    );

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FullImagePage(image: image)),
    );
  }

  AuthorProfileModel _buildPlaceholderProfile(Author author) {
    return AuthorProfileModel(
      author: author,
      profile: const AuthorProfileDetails(
        comment: '',
        webpage: '',
        twitterUrl: '',
        backgroundUrl: '',
        isFollowed: false,
        followers: 0,
        following: 0,
        illusts: 0,
        manga: 0,
        works: 0,
      ),
      pixivRecentIds: const [],
      pixivPreviewCount: 0,
      recentWorks: const [],
      syncSummary: const AuthorSyncSummary(
        checked: 0,
        existing: 0,
        queued: 0,
        imported: 0,
        failed: 0,
        inProgress: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile ?? _buildPlaceholderProfile(widget.author);
    final showBlockingError = _error != null && !_hasLoadedOnce;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.author.name.isEmpty ? '作者详情' : widget.author.name),
      ),
      body: Stack(
        children: [
          if (showBlockingError)
            _BlockingError(error: _error!, onRetry: _refresh)
          else
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 22),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null) ...[
                        _StatusBanner(
                          icon: Icons.cloud_off_rounded,
                          text: '这次刷新失败了，先展示上一次加载到的作者信息。',
                          actionLabel: '重试',
                          onAction: _refresh,
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_shouldShowSyncBanner(profile) &&
                          (profile.syncSummary.inProgress ||
                              profile.syncSummary.queued > 0)) ...[
                        _StatusBanner(
                          icon: Icons.sync_rounded,
                          text:
                              '作者同步仍在进行中，页面会自动刷新。当前待入库 ${profile.syncSummary.queued} 张。',
                        ),
                        const SizedBox(height: 14),
                      ],
                      _AuthorHero(
                        profile: profile,
                        isLoading: _isLoading && !_hasLoadedOnce,
                        onRefresh: _refresh,
                      ),
                      const SizedBox(height: 14),
                      _Surface(
                        child: _AboutSection(
                          profile: profile,
                          isLoading: _isLoading && !_hasLoadedOnce,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _Surface(
                        child: _InfoSection(
                          title: '最近作品',
                          trailing: _WorksHeaderTrailing(
                            count:
                                '${profile.recentWorks.length} / ${profile.pixivPreviewCount}',
                            mode: _worksDisplayMode,
                            onModeChanged: (mode) {
                              setState(() => _worksDisplayMode = mode);
                            },
                          ),
                          child: _buildRecentWorks(profile),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentWorks(AuthorProfileModel profile) {
    if (_isLoading && !_hasLoadedOnce) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final columns = _gridColumnCount(constraints.maxWidth);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: columns * 2,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.76,
            ),
            itemBuilder: (_, __) => const _RecentWorkPlaceholder(),
          );
        },
      );
    }

    if (profile.recentWorks.isEmpty) {
      if (profile.syncSummary.checked > 0) {
        return const Text(
          '最近作品已经识别到了，正在等待入库或缩略图生成。',
          style: TextStyle(color: Color(0xFF64748B)),
        );
      }
      return const Text(
        '当前还没有可展示的最近作品。',
        style: TextStyle(color: Color(0xFF64748B)),
      );
    }

    if (_worksDisplayMode == _AuthorWorksDisplayMode.list) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: profile.recentWorks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final preview = profile.recentWorks[index];
          return _RecentWorkListTile(
            preview: preview,
            onTap: () => _openPreview(profile, preview),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _gridColumnCount(constraints.maxWidth);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: profile.recentWorks.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (context, index) {
            final preview = profile.recentWorks[index];
            return _RecentWorkCard(
              preview: preview,
              onTap: () => _openPreview(profile, preview),
            );
          },
        );
      },
    );
  }

  int _gridColumnCount(double width) {
    if (width >= 1160) {
      return 5;
    }
    if (width >= 900) {
      return 4;
    }
    if (width >= 640) {
      return 3;
    }
    if (width >= 360) {
      return 2;
    }
    return 1;
  }
}

class _AuthorHero extends StatelessWidget {
  final AuthorProfileModel profile;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _AuthorHero({
    required this.profile,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final authorUrl = 'https://www.pixiv.net/users/${profile.author.uid}';

    return _Surface(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(author: profile.author, radius: compact ? 24 : 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.author.name.isEmpty
                              ? 'Pixiv 作者'
                              : profile.author.name,
                          style: TextStyle(
                            fontSize: compact ? 18 : 24,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _PlainBadge(
                              icon: Icons.badge_outlined,
                              label: 'UID ${profile.author.uid}',
                            ),
                            _PlainBadge(
                              icon: profile.profile.isFollowed
                                  ? Icons.favorite_rounded
                                  : Icons.person_outline_rounded,
                              label: profile.profile.isFollowed ? '已关注' : '未关注',
                              foregroundColor: profile.profile.isFollowed
                                  ? const Color(0xFFBE123C)
                                  : const Color(0xFF475569),
                              backgroundColor: profile.profile.isFollowed
                                  ? const Color(0xFFFDECEF)
                                  : const Color(0xFFF8FAFC),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _StatChip(
                    label: '作品',
                    value: profile.profile.works,
                    isLoading: isLoading,
                  ),
                  _StatChip(
                    label: '插画',
                    value: profile.profile.illusts,
                    isLoading: isLoading,
                  ),
                  _StatChip(
                    label: '漫画',
                    value: profile.profile.manga,
                    isLoading: isLoading,
                  ),
                  _StatChip(
                    label: '粉丝',
                    value: profile.profile.followers,
                    isLoading: isLoading,
                  ),
                  _StatChip(
                    label: '关注中',
                    value: profile.profile.following,
                    isLoading: isLoading,
                  ),
                ],
              ),
            ],
          );

          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => launchUrl(
                  Uri.parse(authorUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('打开 Pixiv'),
              ),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('刷新'),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                info,
                const SizedBox(height: 10),
                actions,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: info),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final AuthorProfileModel profile;
  final bool isLoading;

  const _AboutSection({
    required this.profile,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final authorUrl = 'https://www.pixiv.net/users/${profile.author.uid}';
    final links = <Widget>[
      _TinyLinkChip(
        label: 'Pixiv 主页',
        icon: Icons.open_in_new_rounded,
        url: authorUrl,
      ),
      if (profile.profile.webpage.isNotEmpty)
        _TinyLinkChip(
          label: '外部链接',
          icon: Icons.language_rounded,
          url: profile.profile.webpage,
        ),
      if (profile.profile.twitterUrl.isNotEmpty)
        _TinyLinkChip(
          label: 'Twitter / X',
          icon: Icons.alternate_email_rounded,
          url: profile.profile.twitterUrl,
        ),
    ];

    return _InfoSection(
      title: '作者简介',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading && profile.profile.comment.isEmpty)
            const _LoadingParagraph(lines: 3)
          else
            Text(
              profile.profile.comment.isEmpty
                  ? 'Pixiv 没有返回作者简介。'
                  : profile.profile.comment,
              style: const TextStyle(
                height: 1.65,
                color: Color(0xFF334155),
              ),
            ),
          const SizedBox(height: 14),
          if (isLoading && links.isEmpty)
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _LoadingPill(width: 98),
                _LoadingPill(width: 118),
              ],
            )
          else if (links.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: links,
            ),
        ],
      ),
    );
  }
}

class SyncSummarySection extends StatelessWidget {
  final AuthorSyncSummary summary;
  final bool isLoading;

  const SyncSummarySection({
    super.key,
    required this.summary,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return _InfoSection(
      title: '同步状态',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _SummaryBox(
            label: '已检查',
            value: summary.checked,
            isLoading: isLoading,
          ),
          _SummaryBox(
            label: '已存在',
            value: summary.existing,
            isLoading: isLoading,
          ),
          _SummaryBox(
            label: '待入库',
            value: summary.queued,
            isLoading: isLoading,
          ),
          _SummaryBox(
            label: '新入库',
            value: summary.imported,
            isLoading: isLoading,
          ),
          _SummaryBox(
            label: '失败',
            value: summary.failed,
            isLoading: isLoading,
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _InfoSection({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _WorksHeaderTrailing extends StatelessWidget {
  final String count;
  final _AuthorWorksDisplayMode mode;
  final ValueChanged<_AuthorWorksDisplayMode> onModeChanged;

  const _WorksHeaderTrailing({
    required this.count,
    required this.mode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 8),
        SegmentedButton<_AuthorWorksDisplayMode>(
          showSelectedIcon: false,
          selected: {mode},
          segments: const [
            ButtonSegment(
              value: _AuthorWorksDisplayMode.list,
              icon: Icon(Icons.view_agenda_rounded, size: 16),
              label: Text('列表'),
            ),
            ButtonSegment(
              value: _AuthorWorksDisplayMode.grid,
              icon: Icon(Icons.grid_view_rounded, size: 16),
              label: Text('Grid'),
            ),
          ],
          onSelectionChanged: (values) => onModeChanged(values.first),
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}

class _Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Surface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}

class _Avatar extends StatelessWidget {
  final Author author;
  final double radius;

  const _Avatar({
    required this.author,
    this.radius = 28,
  });

  @override
  Widget build(BuildContext context) {
    if (author.avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(
          proxiedImageUrl(author.avatarUrl),
          cacheManager: imageProxyCacheManager,
          headers: imageRequestHeaders(author.avatarUrl),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor:
          getRandomColor(author.uid.hashCode).withValues(alpha: 0.18),
      child: Text(
        author.name.isEmpty ? '?' : author.name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontSize: radius * 0.68,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1D4ED8),
        ),
      ),
    );
  }
}

class _PlainBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  const _PlainBadge({
    required this.icon,
    required this.label,
    this.foregroundColor = const Color(0xFF475569),
    this.backgroundColor = const Color(0xFFF8FAFC),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: foregroundColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final bool isLoading;

  const _StatChip({
    required this.label,
    required this.value,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: isLoading
          ? const _LoadingPill(width: 62, height: 14)
          : RichText(
              text: TextSpan(
                style: const TextStyle(color: Color(0xFF111827)),
                children: [
                  TextSpan(
                    text: '$value',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: '  $label',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String label;
  final int value;
  final bool isLoading;

  const _SummaryBox({
    required this.label,
    required this.value,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 5),
          if (isLoading)
            const _LoadingPill(width: 48, height: 20)
          else
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentWorkListTile extends StatelessWidget {
  final FollowedAuthorWorkPreview preview;
  final VoidCallback onTap;

  const _RecentWorkListTile({
    required this.preview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final publishedAt = formatUnixTimestamp(preview.publishedAt);

    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 86,
              height: 112,
              child: preview.thumbUrl.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFFF1F5F9),
                      child: Center(
                        child: Icon(Icons.image_not_supported_outlined),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: proxiedImageUrl(preview.thumbUrl),
                      cacheManager: imageProxyCacheManager,
                      httpHeaders: imageRequestHeaders(preview.thumbUrl),
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const ColoredBox(color: Color(0xFFF1F5F9)),
                      errorWidget: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFF1F5F9),
                        child: Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.title.isEmpty ? '未命名作品' : preview.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _TinyMetaPill(
                          icon: Icons.favorite_rounded,
                          label: '${preview.bookmarkCount}',
                          color: const Color(0xFFBE123C),
                        ),
                        _TinyMetaPill(
                          icon: Icons.schedule_rounded,
                          label: publishedAt.isEmpty ? '时间未知' : publishedAt,
                          color: const Color(0xFF64748B),
                        ),
                        _TinyMetaPill(
                          icon: Icons.tag_rounded,
                          label: 'PID ${preview.pid}',
                          color: const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _TinyMetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentWorkCard extends StatelessWidget {
  final FollowedAuthorWorkPreview preview;
  final VoidCallback onTap;

  const _RecentWorkCard({
    required this.preview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final publishedAt = formatUnixTimestamp(preview.publishedAt);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.none,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: const Color(0xFFF1F5F9),
                child: preview.thumbUrl.isEmpty
                    ? const Center(
                        child: Icon(Icons.image_not_supported_outlined),
                      )
                    : CachedNetworkImage(
                        imageUrl: proxiedImageUrl(preview.thumbUrl),
                        cacheManager: imageProxyCacheManager,
                        httpHeaders: imageRequestHeaders(preview.thumbUrl),
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          size: 13,
                          color: Color(0xFFBE123C),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${preview.bookmarkCount}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      publishedAt.isEmpty ? '时间未知' : publishedAt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentWorkPlaceholder extends StatelessWidget {
  const _RecentWorkPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(12),
      child: const Column(
        children: [
          Expanded(child: _LoadingBlock()),
          SizedBox(height: 10),
          Row(
            children: [
              _LoadingPill(width: 54),
              SizedBox(width: 10),
              Expanded(child: _LoadingPill(width: 92)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TinyLinkChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? url;

  const _TinyLinkChip({
    required this.label,
    required this.icon,
    this.url,
  });

  Future<void> _openLink() async {
    if (url == null) return;
    final normalized = _normalizeUrl(url!);
    if (normalized == null) return;
    await launchUrl(normalized, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = url != null && _normalizeUrl(url!) != null;

    return InkWell(
      onTap: enabled ? _openLink : null,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF526176)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    enabled ? const Color(0xFF2563EB) : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatusBanner({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF526176)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF334155),
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _BlockingError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _BlockingError({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Color(0xFF64748B),
            ),
            const SizedBox(height: 12),
            const Text(
              '作者页加载失败',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingParagraph extends StatelessWidget {
  final int lines;

  const _LoadingParagraph({this.lines = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(lines, (index) {
        final width = index == lines - 1 ? 0.72 : 1.0;
        return Padding(
          padding: EdgeInsets.only(bottom: index == lines - 1 ? 0 : 8),
          child: FractionallySizedBox(
            widthFactor: width,
            alignment: Alignment.centerLeft,
            child: const _LoadingBlock(height: 12),
          ),
        );
      }),
    );
  }
}

class _LoadingPill extends StatelessWidget {
  final double width;
  final double height;

  const _LoadingPill({
    required this.width,
    this.height = 12,
  });

  @override
  Widget build(BuildContext context) {
    return _LoadingBlock(
      width: width,
      height: height,
      radius: 999,
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const _LoadingBlock({
    this.width,
    this.height = double.infinity,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2F6),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

Uri? _normalizeUrl(String raw) {
  if (raw.trim().isEmpty) {
    return null;
  }
  final value = raw.startsWith('http://') || raw.startsWith('https://')
      ? raw
      : 'https://$raw';
  return Uri.tryParse(value);
}
