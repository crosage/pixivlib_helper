import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tagselector/components/mobile_chrome.dart';
import 'package:tagselector/components/page_bottombar.dart';
import 'package:tagselector/model/followed_author_model.dart';
import 'package:tagselector/model/image_model.dart';
import 'package:tagselector/model/image_url_model.dart';
import 'package:tagselector/pages/author_page.dart';
import 'package:tagselector/pages/full_image_page.dart';
import 'package:tagselector/service/api_service.dart';
import 'package:tagselector/service/app_user_session.dart';
import 'package:tagselector/service/cache_proxy_manager.dart';
import 'package:tagselector/service/remote_image_url.dart';
import 'package:tagselector/utils.dart';

enum FollowedAuthorSortMode {
  recentWork,
  name,
}

extension on FollowedAuthorSortMode {
  String toApiValue() {
    switch (this) {
      case FollowedAuthorSortMode.recentWork:
        return 'recent_work';
      case FollowedAuthorSortMode.name:
        return 'name';
    }
  }
}

class FollowingAuthorsPage extends StatefulWidget {
  const FollowingAuthorsPage({super.key});

  @override
  State<FollowingAuthorsPage> createState() => _FollowingAuthorsPageState();
}

class _FollowingAuthorsPageState extends State<FollowingAuthorsPage> {
  static const int _pageSize = 48;

  final ApiService _api = ApiService.instance;
  final AppUserSession _session = AppUserSession.instance;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late Future<FollowedAuthorListResponse> _future;
  Timer? _searchDebounce;
  int _page = 1;
  String _query = '';
  FollowedAuthorSortMode _sortMode = FollowedAuthorSortMode.recentWork;
  bool _forceRefresh = false;

  @override
  void initState() {
    super.initState();
    _session.addListener(_handleUserChanged);
    _future = _loadAuthors();
  }

  @override
  void dispose() {
    _session.removeListener(_handleUserChanged);
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleUserChanged() {
    if (!mounted) {
      return;
    }
    _page = 1;
    _forceRefresh = true;
    setState(() {
      _future = _loadAuthors();
    });
  }

  Future<FollowedAuthorListResponse> _loadAuthors() {
    final forceRefresh = _forceRefresh;
    _forceRefresh = false;
    return _api.fetchFollowingAuthors(
      offset: (_page - 1) * _pageSize,
      limit: _pageSize,
      sortMode: _sortMode.toApiValue(),
      forceRefresh: forceRefresh,
      query: _query,
    );
  }

  Future<void> _refreshAuthors() async {
    _forceRefresh = true;
    final future = _loadAuthors();
    setState(() {
      _future = future;
    });
    await future;
  }

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _page = 1;
        _future = _loadAuthors();
      });
    });
  }

  void _changePage(int nextPage) {
    if (nextPage < 1) {
      return;
    }
    setState(() {
      _page = nextPage;
      _future = _loadAuthors();
    });
  }

  int get _activeFilterCount {
    var count = 0;
    if (_query.trim().isNotEmpty) count++;
    if (_sortMode != FollowedAuthorSortMode.recentWork) count++;
    return count;
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MobileSheetFrame(
          padding: EdgeInsets.fromLTRB(
            12,
            4,
            12,
            MediaQuery.viewInsetsOf(context).bottom + 12,
          ),
          child: MobileSheetSection(
            child: _MobileFilterPanel(
              queryController: _searchController,
              sortMode: _sortMode,
              onQueryChanged: _onQueryChanged,
              onSortChanged: (value) {
                setState(() {
                  _sortMode = value;
                  _page = 1;
                  _future = _loadAuthors();
                });
              },
              onDone: () => Navigator.of(context).pop(),
              onRefresh: () async {
                Navigator.of(context).pop();
                await _refreshAuthors();
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAuthorPage(FollowedAuthorModel author) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AuthorPage(author: author.author)),
    );
  }

  Future<void> _openPreview(
    FollowedAuthorModel author,
    FollowedAuthorWorkPreview preview,
  ) async {
    final image = ImageModel(
      id: 0,
      pid: preview.pid,
      author: author.author,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: FutureBuilder<FollowedAuthorListResponse>(
          future: _future,
          builder: (context, snapshot) {
            final response = snapshot.data;
            final authors = response?.authors ?? const <FollowedAuthorModel>[];
            final totalPages = response == null || response.total == 0
                ? 1
                : (response.total / _pageSize).ceil();

            return LayoutBuilder(
              builder: (context, constraints) {
                final phone = constraints.maxWidth < 720;

                final content = Column(
                  children: [
                    if (phone)
                      MobileScrollHideToolbar(
                        enabled: true,
                        scrollController: _scrollController,
                        child: _HeaderPanel(
                          phone: true,
                          queryController: _searchController,
                          sortMode: _sortMode,
                          resultCount: authors.length,
                          totalCount: response?.total ?? 0,
                          overallTotal: response?.overallTotal ?? 0,
                          userId: response?.userId ?? '',
                          activeFilterCount: _activeFilterCount,
                          onQueryChanged: _onQueryChanged,
                          onSortChanged: (value) {
                            setState(() {
                              _sortMode = value;
                              _page = 1;
                              _future = _loadAuthors();
                            });
                          },
                          onRefresh: _refreshAuthors,
                          onOpenFilters: _openFilterSheet,
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: _Surface(
                          child: _HeaderPanel(
                            phone: false,
                            queryController: _searchController,
                            sortMode: _sortMode,
                            resultCount: authors.length,
                            totalCount: response?.total ?? 0,
                            overallTotal: response?.overallTotal ?? 0,
                            userId: response?.userId ?? '',
                            activeFilterCount: _activeFilterCount,
                            onQueryChanged: _onQueryChanged,
                            onSortChanged: (value) {
                              setState(() {
                                _sortMode = value;
                                _page = 1;
                                _future = _loadAuthors();
                              });
                            },
                            onRefresh: _refreshAuthors,
                            onOpenFilters: _openFilterSheet,
                          ),
                        ),
                      ),
                    SizedBox(height: phone ? 4 : 12),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: phone ? 0 : 12),
                        child: phone
                            ? _buildBody(snapshot, authors, phone: true)
                            : _Surface(
                                padding: EdgeInsets.zero,
                                child: _buildBody(
                                  snapshot,
                                  authors,
                                  phone: false,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: phone ? 4 : 12),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        phone ? 0 : 12,
                        0,
                        phone ? 0 : 12,
                        phone ? 0 : 12,
                      ),
                      child: phone
                          ? PageBottomBar(
                              currentPage: _page,
                              totalPages: totalPages,
                              onPageChange: _changePage,
                            )
                          : _Surface(
                              padding: EdgeInsets.zero,
                              child: PageBottomBar(
                                currentPage: _page,
                                totalPages: totalPages,
                                summary: response == null
                                    ? 'Loading followed authors'
                                    : 'Page ${authors.length} authors, total ${response.total}',
                                onPageChange: _changePage,
                              ),
                            ),
                    ),
                  ],
                );

                return phone
                    ? ColoredBox(
                        color: const Color(0xFFF2F2F7),
                        child: content,
                      )
                    : content;
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(
    AsyncSnapshot<FollowedAuthorListResponse> snapshot,
    List<FollowedAuthorModel> authors, {
    required bool phone,
  }) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        snapshot.data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError && snapshot.data == null) {
      return _EmptyState(
        title: '关注作者列表加载失败',
        description: snapshot.error.toString(),
        actionLabel: '重试',
        onAction: _refreshAuthors,
      );
    }

    if (authors.isEmpty) {
      return _EmptyState(
        title: _query.trim().isEmpty ? '这一页没有作者' : '没有匹配到作者',
        description: _query.trim().isEmpty
            ? '可以切换页码，或者刷新后重新拉取关注作者摘要。'
            : '试试缩短关键词，或者换一种排序方式。',
        actionLabel: '刷新',
        onAction: _refreshAuthors,
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshAuthors,
      child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(phone ? 6 : 12, 0, phone ? 6 : 12, 0),
        itemCount: authors.length,
        separatorBuilder: (_, __) => SizedBox(height: phone ? 6 : 10),
        itemBuilder: (context, index) {
          final author = authors[index];
          return _AuthorCard(
            phone: phone,
            author: author,
            onTap: () => _openAuthorPage(author),
            onPreviewTap: (preview) => _openPreview(author, preview),
          );
        },
      ),
    );
  }
}

class _HeaderPanel extends StatelessWidget {
  final bool phone;
  final TextEditingController queryController;
  final FollowedAuthorSortMode sortMode;
  final int resultCount;
  final int totalCount;
  final int overallTotal;
  final String userId;
  final int activeFilterCount;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<FollowedAuthorSortMode> onSortChanged;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenFilters;

  const _HeaderPanel({
    required this.phone,
    required this.queryController,
    required this.sortMode,
    required this.resultCount,
    required this.totalCount,
    required this.overallTotal,
    required this.userId,
    required this.activeFilterCount,
    required this.onQueryChanged,
    required this.onSortChanged,
    required this.onRefresh,
    required this.onOpenFilters,
  });

  @override
  Widget build(BuildContext context) {
    if (phone) {
      return MobileToolbar(
        topCenter: const MobileBrandMark(label: 'Creators'),
        actions: [
          MobilePill(
            icon: Icons.tune_rounded,
            label: activeFilterCount > 0 ? '筛选 $activeFilterCount' : '筛选',
            selected: activeFilterCount > 0,
            onTap: onOpenFilters,
          ),
          MobileIconButton(
            icon: Icons.refresh_rounded,
            tooltip: '刷新',
            onTap: () {
              onRefresh();
            },
          ),
        ],
        chips: [
          MobilePill(label: '$totalCount 关注'),
          MobilePill(label: '本页 $resultCount'),
          if (queryController.text.trim().isNotEmpty)
            MobilePill(
              label: queryController.text.trim(),
              selected: true,
            ),
        ],
        bottom: MobileSegmentedControl<FollowedAuthorSortMode>(
          selected: sortMode,
          segments: const [
            MobileSegment(
              value: FollowedAuthorSortMode.recentWork,
              label: '最近更新',
              icon: Icons.bolt_rounded,
            ),
            MobileSegment(
              value: FollowedAuthorSortMode.name,
              label: '名称',
              icon: Icons.sort_by_alpha_rounded,
            ),
          ],
          onChanged: onSortChanged,
        ),
      );
    }

    if (phone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '关注作者',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              _FlatMetaChip(label: '$totalCount 关注'),
              const SizedBox(width: 6),
              _FlatActionButton(
                icon: Icons.tune_rounded,
                label: activeFilterCount > 0 ? '筛选 $activeFilterCount' : '筛选',
                onTap: onOpenFilters,
              ),
              const SizedBox(width: 4),
              _IconActionButton(
                icon: Icons.refresh_rounded,
                onTap: () {
                  onRefresh();
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _FlatMetaChip(label: '当前 $resultCount'),
              if (sortMode != FollowedAuthorSortMode.recentWork)
                const _FlatMetaChip(label: '按名称排序'),
              if (queryController.text.trim().isNotEmpty)
                _FlatMetaChip(label: queryController.text.trim()),
            ],
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 920;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: narrow ? constraints.maxWidth : 460,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '关注作者',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '按作者查看最近更新和最近几张作品，比单纯刷关注作品流更适合追踪作者动态。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF64748B),
                              height: 1.45,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('刷新'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatPill(label: '总关注', value: '$totalCount'),
                _StatPill(label: '筛选后', value: '$resultCount'),
                if (overallTotal > 0)
                  _StatPill(label: '总体缓存', value: '$overallTotal'),
                if (userId.isNotEmpty)
                  _StatPill(label: '当前 UID', value: userId),
              ],
            ),
            const SizedBox(height: 14),
            if (narrow) ...[
              TextField(
                controller: queryController,
                onChanged: onQueryChanged,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: '搜索作者名 / UID / 简介 / 最近作品',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<FollowedAuthorSortMode>(
                value: sortMode,
                decoration: const InputDecoration(labelText: '排序方式'),
                items: _sortItems,
                onChanged: (value) {
                  if (value != null) {
                    onSortChanged(value);
                  }
                },
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: queryController,
                      onChanged: onQueryChanged,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: '搜索作者名 / UID / 简介 / 最近作品',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<FollowedAuthorSortMode>(
                      value: sortMode,
                      decoration: const InputDecoration(labelText: '排序方式'),
                      items: _sortItems,
                      onChanged: (value) {
                        if (value != null) {
                          onSortChanged(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  static const List<DropdownMenuItem<FollowedAuthorSortMode>> _sortItems = [
    DropdownMenuItem(
      value: FollowedAuthorSortMode.recentWork,
      child: Text('按最近更新'),
    ),
    DropdownMenuItem(
      value: FollowedAuthorSortMode.name,
      child: Text('按作者名'),
    ),
  ];
}

class _AuthorCard extends StatelessWidget {
  final bool phone;
  final FollowedAuthorModel author;
  final VoidCallback onTap;
  final ValueChanged<FollowedAuthorWorkPreview> onPreviewTap;

  const _AuthorCard({
    required this.phone,
    required this.author,
    required this.onTap,
    required this.onPreviewTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Ink(
        padding: EdgeInsets.fromLTRB(
          phone ? 9 : 14,
          phone ? 8 : 14,
          phone ? 9 : 14,
          phone ? 9 : 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: phone ? null : Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(phone ? 18 : 18),
          boxShadow: phone
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.035),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = phone || constraints.maxWidth < 860;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                narrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CardTop(author: author, phone: phone),
                          SizedBox(height: phone ? 6 : 12),
                          _CardMeta(author: author, phone: phone),
                          SizedBox(height: phone ? 6 : 12),
                          if (!phone)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: phone
                                  ? _FlatActionButton(
                                      icon: Icons.arrow_forward_rounded,
                                      label: '作者页',
                                      onTap: onTap,
                                    )
                                  : FilledButton.tonalIcon(
                                      onPressed: onTap,
                                      icon: const Icon(
                                          Icons.arrow_forward_rounded),
                                      label: const Text('进入作者页'),
                                    ),
                            ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _CardTop(author: author, phone: phone),
                                const SizedBox(height: 12),
                                _CardMeta(author: author, phone: phone),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonalIcon(
                            onPressed: onTap,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('作者页'),
                          ),
                        ],
                      ),
                if (author.recentWorks.isNotEmpty) ...[
                  SizedBox(height: phone ? 7 : 14),
                  _PreviewStrip(
                    phone: phone,
                    author: author,
                    onPreviewTap: onPreviewTap,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CardTop extends StatelessWidget {
  final FollowedAuthorModel author;
  final bool phone;

  const _CardTop({
    required this.author,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarSize = phone ? 42.0 : 58.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        author.author.avatarUrl.isEmpty
            ? Container(
                width: avatarSize,
                height: avatarSize,
                color: const Color(0xFFE2E8F0),
                alignment: Alignment.center,
                child: const Icon(Icons.person_outline_rounded),
              )
            : CachedNetworkImage(
                imageUrl: proxiedImageUrl(author.author.avatarUrl),
                cacheManager: imageProxyCacheManager,
                httpHeaders: imageRequestHeaders(author.author.avatarUrl),
                width: avatarSize,
                height: avatarSize,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: avatarSize,
                  height: avatarSize,
                  color: const Color(0xFFE2E8F0),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: avatarSize,
                  height: avatarSize,
                  color: const Color(0xFFE2E8F0),
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
        SizedBox(width: phone ? 8 : 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    author.author.name.isEmpty ? '未命名作者' : author.author.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: phone ? 14 : 18,
                    ),
                  ),
                  if (author.premium) const _Badge(label: 'Premium'),
                  if (author.followedBack) const _Badge(label: '互相关注'),
                  if (author.acceptingCommission) const _Badge(label: '可接稿'),
                ],
              ),
              SizedBox(height: phone ? 1 : 4),
              Text(
                'UID ${author.author.uid}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: phone ? 11 : null,
                  color: const Color(0xFF64748B),
                ),
              ),
              if (author.comment.isNotEmpty) ...[
                SizedBox(height: phone ? 4 : 8),
                Text(
                  author.comment,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CardMeta extends StatelessWidget {
  final FollowedAuthorModel author;
  final bool phone;

  const _CardMeta({
    required this.author,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    if (phone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _InfoChip(
                phone: true,
                label: '最近更新',
                value: _formatRelativeTime(author.recentWorkAt),
              ),
              _InfoChip(
                phone: true,
                label: '预览',
                value: '${author.pixivPreviewCount}',
              ),
            ],
          ),
          if (author.recentWorkTitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              author.recentWorkTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
            ),
          ],
          if (author.recentWorkAt > 0) ...[
            const SizedBox(height: 4),
            Text(
              formatUnixTimestamp(author.recentWorkAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
            ),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _InfoChip(
          phone: false,
          label: '最近更新',
          value: _formatRelativeTime(author.recentWorkAt),
        ),
        _InfoChip(
          phone: false,
          label: 'Pixiv 预览',
          value: '${author.pixivPreviewCount}',
        ),
        if (author.recentWorkPid > 0)
          _InfoChip(
            phone: false,
            label: '最新 PID',
            value: '${author.recentWorkPid}',
          ),
        if (author.recentWorkTitle.isNotEmpty)
          _InfoChip(
            phone: false,
            label: '最新作品',
            value: author.recentWorkTitle,
          ),
        if (author.recentWorkAt > 0)
          _InfoChip(
            phone: false,
            label: '更新时间',
            value: formatUnixTimestamp(author.recentWorkAt),
          ),
      ],
    );
  }
}

class _PreviewStrip extends StatelessWidget {
  final bool phone;
  final FollowedAuthorModel author;
  final ValueChanged<FollowedAuthorWorkPreview> onPreviewTap;

  const _PreviewStrip({
    required this.phone,
    required this.author,
    required this.onPreviewTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '最近作品预览',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(width: 8),
            Text(
              '${author.recentWorks.length} / ${author.pixivPreviewCount}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
            ),
          ],
        ),
        SizedBox(height: phone ? 6 : 10),
        SizedBox(
          height: phone ? 118 : 162,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: author.recentWorks.length,
            separatorBuilder: (_, __) => SizedBox(width: phone ? 4 : 10),
            itemBuilder: (context, index) {
              final preview = author.recentWorks[index];
              return _PreviewCard(
                phone: phone,
                preview: preview,
                onTap: () => onPreviewTap(preview),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final bool phone;
  final FollowedAuthorWorkPreview preview;
  final VoidCallback onTap;

  const _PreviewCard({
    required this.phone,
    required this.preview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: phone ? 86 : 120,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(phone ? 0 : 14),
        clipBehavior: Clip.none,
        child: InkWell(
          borderRadius: BorderRadius.circular(phone ? 0 : 14),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(phone ? 0 : 14),
              border: phone ? null : Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
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
                          width: double.infinity,
                          placeholder: (_, __) => const ColoredBox(
                            color: Color(0xFFF1F5F9),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, __, ___) => const ColoredBox(
                            color: Color(0xFFF1F5F9),
                            child: Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    phone ? 5 : 8,
                    phone ? 4 : 6,
                    phone ? 5 : 8,
                    phone ? 5 : 10,
                  ),
                  child: Text(
                    preview.title.isEmpty ? '未命名作品' : preview.title,
                    maxLines: phone ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: phone ? 10 : 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF243B53),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1D4ED8),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final bool phone;
  final String label;
  final String value;

  const _InfoChip({
    required this.phone,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: phone ? 7 : 10,
        vertical: phone ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(phone ? 999 : 14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        '$label  $value',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: phone ? 11 : null,
              color: const Color(0xFF334155),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        '$label  $value',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _MobileFilterPanel extends StatelessWidget {
  final TextEditingController queryController;
  final FollowedAuthorSortMode sortMode;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<FollowedAuthorSortMode> onSortChanged;
  final VoidCallback onDone;
  final Future<void> Function() onRefresh;

  const _MobileFilterPanel({
    required this.queryController,
    required this.sortMode,
    required this.onQueryChanged,
    required this.onSortChanged,
    required this.onDone,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '筛选关注作者',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: queryController,
          onChanged: onQueryChanged,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: '搜索作者名 / UID / 简介 / 作品',
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<FollowedAuthorSortMode>(
          value: sortMode,
          decoration: const InputDecoration(labelText: '排序方式'),
          items: _HeaderPanel._sortItems,
          onChanged: (value) {
            if (value != null) {
              onSortChanged(value);
            }
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: onDone,
                child: const Text('完成'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('刷新'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FlatMetaChip extends StatelessWidget {
  final String label;

  const _FlatMetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
      ),
    );
  }
}

class _FlatActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FlatActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconActionButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String description;
  final String actionLabel;
  final Future<void> Function() onAction;

  const _EmptyState({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: child,
      ),
    );
  }
}

String _formatRelativeTime(int seconds) {
  if (seconds <= 0) {
    return '暂无';
  }

  final now = DateTime.now();
  final target = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  final diff = now.difference(target);

  if (diff.inDays >= 1) {
    return '${diff.inDays} 天前';
  }
  if (diff.inHours >= 1) {
    return '${diff.inHours} 小时前';
  }
  if (diff.inMinutes >= 1) {
    return '${diff.inMinutes} 分钟前';
  }
  return '刚刚';
}
