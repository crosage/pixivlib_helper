import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:tagselector/components/image_with_info.dart';
import 'package:tagselector/components/app_ui.dart';
import 'package:tagselector/components/masonry_image_tile.dart';
import 'package:tagselector/components/mobile_chrome.dart';
import 'package:tagselector/components/page_bottombar.dart';
import 'package:tagselector/model/author_model.dart';
import 'package:tagselector/model/image_model.dart';
import 'package:tagselector/pages/author_page.dart';
import 'package:tagselector/pages/full_image_page.dart';
import 'package:tagselector/service/api_service.dart';
import 'package:tagselector/service/app_user_session.dart';
import 'package:tagselector/service/image_prefetcher.dart';

enum FollowingDisplayMode { list, grid }

enum FollowingFeedMode { all, safe, r18 }

enum FollowingSourceMode { following, bookmarks }

enum BookmarkRestMode { hide, show }

class FollowingPage extends StatefulWidget {
  final FollowingSourceMode initialSourceMode;
  final BookmarkRestMode initialBookmarkRestMode;

  const FollowingPage({
    super.key,
    this.initialSourceMode = FollowingSourceMode.following,
    this.initialBookmarkRestMode = BookmarkRestMode.hide,
  });

  @override
  State<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage> {
  final ApiService _api = ApiService.instance;
  final ScrollController _scrollController = ScrollController();
  final AppUserSession _session = AppUserSession.instance;

  Future<List<ImageModel>>? _followingFuture;
  final ImagePrefetcher _prefetcher = ImagePrefetcher.instance;
  final Set<int> _bookmarkHydrationInFlight = <int>{};
  Timer? _scrollPrefetchTimer;
  List<ImageModel> _visibleImagesForPrefetch = const [];

  int _page = 1;
  String _selectedAuthor = '';
  final List<String> _selectedTags = [];
  final Map<int, ImageModel> _imageOverrides = <int, ImageModel>{};
  FollowingDisplayMode _displayMode = FollowingDisplayMode.grid;
  FollowingFeedMode _feedMode = FollowingFeedMode.all;
  FollowingSourceMode _sourceMode = FollowingSourceMode.following;
  BookmarkRestMode _bookmarkRestMode = BookmarkRestMode.hide;

  @override
  void initState() {
    super.initState();
    _session.addListener(_handleUserChanged);
    _scrollController.addListener(_scheduleScrollPrefetch);
    _sourceMode = widget.initialSourceMode;
    _bookmarkRestMode = widget.initialBookmarkRestMode;
    _refreshFollowing();
  }

  @override
  void dispose() {
    _session.removeListener(_handleUserChanged);
    _scrollPrefetchTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleUserChanged() {
    if (!mounted) {
      return;
    }
    _page = 1;
    _imageOverrides.clear();
    _refreshFollowing();
  }

  void _refreshFollowing({bool force = false}) {
    setState(() {
      if (_sourceMode == FollowingSourceMode.bookmarks) {
        _followingFuture = _fetchBookmarkImages(
          page: _page,
          rest: _bookmarkRestMode.name,
          mode: _feedMode.name,
        );
      } else {
        _followingFuture = _fetchFollowingImages(
          page: _page,
          mode: _feedMode.name,
          forceRefresh: force,
        );
      }
    });
  }

  Future<List<ImageModel>> _fetchBookmarkImages({
    required int page,
    required String rest,
    required String mode,
  }) async {
    final images = await _api.fetchBookmarkImages(
      page: page,
      rest: rest,
      mode: mode,
    );
    _prepareImages(images);
    return images;
  }

  Future<List<ImageModel>> _fetchFollowingImages({
    required int page,
    required String mode,
    bool forceRefresh = false,
  }) async {
    final images = await _api.fetchFollowingImages(
      page: page,
      mode: mode,
      forceRefresh: forceRefresh,
    );
    _prepareImages(images);
    return images;
  }

  void _prepareImages(List<ImageModel> images) {
    _prefetcher.prefetchImageModels(
      images.take(_displayMode == FollowingDisplayMode.grid ? 8 : 12),
      highQuality: _displayMode == FollowingDisplayMode.list,
      limit: _displayMode == FollowingDisplayMode.grid ? 8 : 12,
    );
    _hydrateBookmarkCounts(images);
  }

  void _updateImage(ImageModel image) {
    setState(() {
      final currentImage = _imageOverrides[image.pid];
      _imageOverrides[image.pid] = currentImage == null
          ? image
          : currentImage.copyWith(
              bookmarkCount: image.bookmarkCount,
              isBookmarked: image.isBookmarked,
            );
    });
  }

  void _hydrateBookmarkCounts(List<ImageModel> images) {
    final targets = images
        .where((image) =>
            image.pid > 0 &&
            image.bookmarkCount <= 0 &&
            !_bookmarkHydrationInFlight.contains(image.pid))
        .take(18)
        .toList();
    if (targets.isEmpty) {
      return;
    }

    _bookmarkHydrationInFlight.addAll(targets.map((image) => image.pid));
    unawaited(() async {
      try {
        final hydrated = await _api.hydrateImageBookmarkCounts(
          targets,
          maxItems: targets.length,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          for (final image in hydrated) {
            if (image.pid <= 0) {
              continue;
            }
            final current = _imageOverrides[image.pid];
            _imageOverrides[image.pid] = (current ?? image).copyWith(
              bookmarkCount: image.bookmarkCount,
              isBookmarked: image.isBookmarked,
            );
          }
        });
      } finally {
        _bookmarkHydrationInFlight.removeAll(targets.map((image) => image.pid));
      }
    }());
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else if (tag.isNotEmpty) {
        _selectedTags.add(tag);
      }
    });
  }

  void _toggleAuthor(String author) {
    setState(() {
      _selectedAuthor = _selectedAuthor == author ? '' : author;
    });
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty || _selectedTags.contains(trimmed)) {
      return;
    }
    setState(() {
      _selectedTags.add(trimmed);
    });
  }

  void _clearSelectedAuthor() {
    setState(() => _selectedAuthor = '');
  }

  void _clearMobileFilters() {
    setState(() {
      _selectedAuthor = '';
      _selectedTags.clear();
    });
  }

  void _changePage(int page) {
    setState(() => _page = page);
    _refreshFollowing();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  List<ImageModel> _filterImages(List<ImageModel> source) {
    return source.map((image) => _imageOverrides[image.pid] ?? image).where(
      (image) {
        final authorMatches =
            _selectedAuthor.isEmpty || image.author.name == _selectedAuthor;
        final tagsMatch = _selectedTags.isEmpty ||
            _selectedTags.every(
              (selected) => image.tags.any((tag) => tag.name == selected),
            );
        return authorMatches && tagsMatch;
      },
    ).toList();
  }

  Future<void> _openAuthorPage(Author author) async {
    if (author.uid.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AuthorPage(author: author)),
    );
  }

  Future<void> _openImagePage(ImageModel image) async {
    final selectedTag = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => FullImagePage(image: image)),
    );
    if (!mounted || selectedTag == null || selectedTag.isEmpty) {
      return;
    }
    _addTag(selectedTag);
  }

  void _prefetchAround(List<ImageModel> images, int index) {
    final start = (index + 1).clamp(0, images.length);
    final end = (index + (_displayMode == FollowingDisplayMode.grid ? 7 : 13))
        .clamp(0, images.length);
    if (start >= end) return;
    _prefetcher.prefetchImageModels(
      images.sublist(start, end),
      highQuality: _displayMode == FollowingDisplayMode.list,
      limit: _displayMode == FollowingDisplayMode.grid ? 6 : 8,
    );
  }

  void _scheduleScrollPrefetch() {
    if (!_scrollController.hasClients || _visibleImagesForPrefetch.isEmpty) {
      return;
    }
    _scrollPrefetchTimer?.cancel();
    _scrollPrefetchTimer = Timer(const Duration(milliseconds: 180), () {
      if (!_scrollController.hasClients || _visibleImagesForPrefetch.isEmpty) {
        return;
      }
      final position = _scrollController.position;
      final estimatedItemExtent =
          _displayMode == FollowingDisplayMode.list ? 420.0 : 220.0;
      final index = (position.pixels / estimatedItemExtent)
          .floor()
          .clamp(
            0,
            math.max(0, _visibleImagesForPrefetch.length - 1),
          )
          .toInt();
      _prefetchAround(_visibleImagesForPrefetch, index);
    });
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final padding = EdgeInsets.fromLTRB(
          12,
          4,
          12,
          MediaQuery.viewInsetsOf(context).bottom + 12,
        );

        Widget shell({required Widget child}) {
          return MobileSheetFrame(
            padding: padding,
            child: child,
          );
        }

        return DeferredSheetContent(
          placeholder: shell(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.42,
              child: const MobileSheetSection(
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
          ),
          builder: (context) {
            return shell(
              child: SingleChildScrollView(
                child: MobileSheetSection(
                  child: _FollowSidebar(
                    compact: true,
                    activeUserLabel: _session.activeUser?.name ?? '当前会话用户',
                    selectedAuthor: _selectedAuthor,
                    selectedTags: _selectedTags,
                    onClearAuthor: _clearSelectedAuthor,
                    onClearFilters: _clearMobileFilters,
                    onRemoveTag: _toggleTag,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openViewOptionsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            void refreshSheet(VoidCallback change, {bool reload = false}) {
              setState(change);
              setSheetState(() {});
              if (reload) _refreshFollowing();
            }

            Widget option({
              required IconData icon,
              required String label,
              required bool selected,
              required VoidCallback onTap,
            }) {
              return ListTile(
                dense: true,
                leading: Icon(icon, size: 20),
                title: Text(label),
                trailing: selected
                    ? const Icon(Icons.check_rounded, color: Color(0xFF0096FA))
                    : null,
                selected: selected,
                onTap: onTap,
              );
            }

            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                Text('浏览设置', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                const _SheetLabel('内容来源'),
                option(
                  icon: Icons.favorite_outline_rounded,
                  label: '关注动态',
                  selected: _sourceMode == FollowingSourceMode.following,
                  onTap: () => refreshSheet(() {
                    _sourceMode = FollowingSourceMode.following;
                    _page = 1;
                  }, reload: true),
                ),
                option(
                  icon: Icons.bookmarks_outlined,
                  label: '收藏作品',
                  selected: _sourceMode == FollowingSourceMode.bookmarks,
                  onTap: () => refreshSheet(() {
                    _sourceMode = FollowingSourceMode.bookmarks;
                    _page = 1;
                  }, reload: true),
                ),
                if (_sourceMode == FollowingSourceMode.bookmarks) ...[
                  const Divider(),
                  const _SheetLabel('收藏范围'),
                  option(
                    icon: Icons.lock_outline_rounded,
                    label: '私有收藏',
                    selected: _bookmarkRestMode == BookmarkRestMode.hide,
                    onTap: () => refreshSheet(() {
                      _bookmarkRestMode = BookmarkRestMode.hide;
                      _page = 1;
                    }, reload: true),
                  ),
                  option(
                    icon: Icons.public_rounded,
                    label: '公开收藏',
                    selected: _bookmarkRestMode == BookmarkRestMode.show,
                    onTap: () => refreshSheet(() {
                      _bookmarkRestMode = BookmarkRestMode.show;
                      _page = 1;
                    }, reload: true),
                  ),
                ],
                const Divider(),
                const _SheetLabel('内容分级'),
                option(
                  icon: Icons.layers_outlined,
                  label: '全部内容',
                  selected: _feedMode == FollowingFeedMode.all,
                  onTap: () => refreshSheet(() {
                    _feedMode = FollowingFeedMode.all;
                    _page = 1;
                  }, reload: true),
                ),
                option(
                  icon: Icons.shield_outlined,
                  label: 'Safe',
                  selected: _feedMode == FollowingFeedMode.safe,
                  onTap: () => refreshSheet(() {
                    _feedMode = FollowingFeedMode.safe;
                    _page = 1;
                  }, reload: true),
                ),
                option(
                  icon: Icons.explicit_outlined,
                  label: 'R18',
                  selected: _feedMode == FollowingFeedMode.r18,
                  onTap: () => refreshSheet(() {
                    _feedMode = FollowingFeedMode.r18;
                    _page = 1;
                  }, reload: true),
                ),
                const Divider(),
                const _SheetLabel('显示方式'),
                option(
                  icon: Icons.grid_view_rounded,
                  label: '网格',
                  selected: _displayMode == FollowingDisplayMode.grid,
                  onTap: () => refreshSheet(
                    () => _displayMode = FollowingDisplayMode.grid,
                  ),
                ),
                option(
                  icon: Icons.view_agenda_outlined,
                  label: '列表',
                  selected: _displayMode == FollowingDisplayMode.list,
                  onTap: () => refreshSheet(
                    () => _displayMode = FollowingDisplayMode.list,
                  ),
                ),
                if (_activeFilterCount > 0) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.filter_alt_off_outlined),
                    title: const Text('清除作品筛选'),
                    subtitle: Text('当前 $_activeFilterCount 个条件'),
                    onTap: () {
                      _clearMobileFilters();
                      setSheetState(() {});
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  int get _activeFilterCount {
    var count = _selectedTags.length;
    if (_selectedAuthor.isNotEmpty) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ImageModel>>(
      future: _followingFuture,
      builder: (context, snapshot) {
        final rawImages = snapshot.data ?? const <ImageModel>[];
        final images = _filterImages(rawImages);
        _visibleImagesForPrefetch = images;
        return LayoutBuilder(
          builder: (context, constraints) {
            final phone = constraints.maxWidth < 720;
            final showSidebar = constraints.maxWidth >= 1040;
            final content = Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            MobileScrollHideToolbar(
                              enabled: phone,
                              scrollController: _scrollController,
                              child: _TopPanel(
                                phone: phone,
                                resultCount: images.length,
                                activeFilterCount: _activeFilterCount,
                                selectedAuthor: _selectedAuthor,
                                sourceMode: _sourceMode,
                                bookmarkRestMode: _bookmarkRestMode,
                                feedMode: _feedMode,
                                displayMode: _displayMode,
                                selectedTags: _selectedTags,
                                onSourceModeChanged: (mode) {
                                  setState(() {
                                    _sourceMode = mode;
                                    _page = 1;
                                  });
                                  _refreshFollowing();
                                },
                                onBookmarkRestModeChanged: (mode) {
                                  setState(() {
                                    _bookmarkRestMode = mode;
                                    _page = 1;
                                  });
                                  _refreshFollowing();
                                },
                                onFeedModeChanged: (mode) {
                                  setState(() {
                                    _feedMode = mode;
                                    _page = 1;
                                  });
                                  _refreshFollowing();
                                },
                                onDisplayModeChanged: (mode) {
                                  setState(() => _displayMode = mode);
                                },
                                onRefresh: () => _refreshFollowing(force: true),
                                onOpenViewOptions: _openViewOptionsSheet,
                                onOpenFilters: _openFilterSheet,
                                onRemoveTag: _toggleTag,
                                onClearAuthor: _clearSelectedAuthor,
                              ),
                            ),
                            SizedBox(height: phone ? 4 : 10),
                            Expanded(
                              child: phone
                                  ? _buildBody(snapshot, images, phone: true)
                                  : _Surface(
                                      padding: EdgeInsets.zero,
                                      child: _buildBody(
                                        snapshot,
                                        images,
                                        phone: false,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      if (showSidebar) ...[
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 220,
                          child: _FollowSidebar(
                            compact: false,
                            activeUserLabel:
                                _session.activeUser?.name ?? '当前会话用户',
                            selectedAuthor: _selectedAuthor,
                            selectedTags: _selectedTags,
                            onClearAuthor: _clearSelectedAuthor,
                            onClearFilters: _clearMobileFilters,
                            onRemoveTag: _toggleTag,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: phone ? 4 : 10),
                if (phone)
                  PageBottomBar(
                    currentPage: _page,
                    canGoNext: rawImages.isNotEmpty,
                    onPageChange: _changePage,
                  )
                else
                  PageBottomBar(
                    currentPage: _page,
                    canGoNext: rawImages.isNotEmpty,
                    onPageChange: _changePage,
                    summary: snapshot.hasError
                        ? '加载失败: ${snapshot.error}'
                        : '${images.length} 条结果',
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
    );
  }

  Widget _buildBody(
    AsyncSnapshot<List<ImageModel>> snapshot,
    List<ImageModel> images, {
    required bool phone,
  }) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        snapshot.data == null) {
      return AppLoadingGrid(
        padding: EdgeInsets.symmetric(
          horizontal: phone ? 6 : 10,
          vertical: phone ? 2 : 10,
        ),
        minTileWidth: phone ? 176 : 230,
      );
    }

    if (snapshot.hasError && images.isEmpty) {
      return _EmptyState(
        title: '加载失败',
        description: snapshot.error.toString(),
      );
    }

    if (images.isEmpty) {
      return const _EmptyState(
        title: '没有结果',
        description: '试试切换分组、翻页，或者去掉部分筛选条件。',
      );
    }

    if (_displayMode == FollowingDisplayMode.list) {
      return ListView.builder(
        controller: _scrollController,
        cacheExtent: phone ? 1400 : 900,
        padding: EdgeInsets.symmetric(horizontal: phone ? 0 : 10),
        itemCount: images.length,
        itemBuilder: (context, index) {
          final image = images[index];
          return ImageWithInfo(
            image: image,
            selectedTags: _selectedTags,
            onSelectedTagsChanged: _toggleTag,
            onSelectedAuthor: _toggleAuthor,
            onImageChanged: _updateImage,
            onAuthorTap: () => _openAuthorPage(image.author),
            onImageTap: () => _openImagePage(image),
            highQualityPreview: true,
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final count =
            (constraints.maxWidth / (phone ? 176 : 230)).floor().clamp(2, 6);
        return MasonryGridView.count(
          controller: _scrollController,
          cacheExtent: phone ? 700 : 650,
          padding: EdgeInsets.symmetric(
            horizontal: phone ? 6 : 10,
            vertical: phone ? 2 : 10,
          ),
          crossAxisCount: count,
          crossAxisSpacing: phone ? 6 : 10,
          mainAxisSpacing: phone ? 6 : 10,
          itemCount: images.length,
          itemBuilder: (context, index) {
            final image = images[index];
            return MasonryImageTile(
              image: image,
              highQualityPreview:
                  !phone && defaultTargetPlatform != TargetPlatform.windows,
              onImageChanged: _updateImage,
              onTap: () => _openImagePage(image),
              onAuthorTap: () => _openAuthorPage(image.author),
            );
          },
        );
      },
    );
  }
}

class _TopPanel extends StatelessWidget {
  final bool phone;
  final int resultCount;
  final int activeFilterCount;
  final String selectedAuthor;
  final FollowingSourceMode sourceMode;
  final BookmarkRestMode bookmarkRestMode;
  final FollowingFeedMode feedMode;
  final FollowingDisplayMode displayMode;
  final List<String> selectedTags;
  final ValueChanged<FollowingSourceMode> onSourceModeChanged;
  final ValueChanged<BookmarkRestMode> onBookmarkRestModeChanged;
  final ValueChanged<FollowingFeedMode> onFeedModeChanged;
  final ValueChanged<FollowingDisplayMode> onDisplayModeChanged;
  final VoidCallback onRefresh;
  final VoidCallback onOpenViewOptions;
  final VoidCallback onOpenFilters;
  final ValueChanged<String> onRemoveTag;
  final VoidCallback onClearAuthor;

  const _TopPanel({
    required this.phone,
    required this.resultCount,
    required this.activeFilterCount,
    required this.selectedAuthor,
    required this.sourceMode,
    required this.bookmarkRestMode,
    required this.feedMode,
    required this.displayMode,
    required this.selectedTags,
    required this.onSourceModeChanged,
    required this.onBookmarkRestModeChanged,
    required this.onFeedModeChanged,
    required this.onDisplayModeChanged,
    required this.onRefresh,
    required this.onOpenViewOptions,
    required this.onOpenFilters,
    required this.onRemoveTag,
    required this.onClearAuthor,
  });

  @override
  Widget build(BuildContext context) {
    if (phone) {
      final subtitle = [
        sourceMode == FollowingSourceMode.bookmarks
            ? 'Pixiv 收藏 · $resultCount 个作品'
            : 'Pixiv 关注动态 · $resultCount 个作品',
        if (selectedAuthor.isNotEmpty) selectedAuthor,
        if (selectedTags.isNotEmpty) '${selectedTags.length} 个标签',
      ].join(' · ');

      return MobileToolbar(
        title: sourceMode == FollowingSourceMode.bookmarks ? '收藏' : '关注',
        subtitle: subtitle,
        leading: Icon(
          sourceMode == FollowingSourceMode.bookmarks
              ? Icons.bookmarks_rounded
              : Icons.favorite_rounded,
          color: mobileBlue,
        ),
        actions: [
          MobileIconButton(
            icon: Icons.tune_rounded,
            tooltip: '浏览设置',
            onTap: onOpenViewOptions,
          ),
          MobileIconButton(
            icon: Icons.refresh_rounded,
            tooltip: '刷新',
            onTap: onRefresh,
          ),
        ],
      );
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sourceMode == FollowingSourceMode.bookmarks
                    ? const Color(0xFFFFEEF1)
                    : const Color(0xFFE8F5FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                sourceMode == FollowingSourceMode.bookmarks
                    ? Icons.bookmarks_rounded
                    : Icons.favorite_outline_rounded,
                color: sourceMode == FollowingSourceMode.bookmarks
                    ? const Color(0xFFE5484D)
                    : const Color(0xFF0096FA),
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sourceMode == FollowingSourceMode.bookmarks
                        ? '收藏作品'
                        : '关注动态',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sourceMode == FollowingSourceMode.bookmarks
                        ? 'Pixiv 当前账户收藏的作品'
                        : 'Pixiv 关注作者最近发布的作品',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            _SoftChip(label: '$resultCount 项'),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _PillToggle<FollowingSourceMode>(
              value: sourceMode,
              options: const [
                _PillOption(
                  value: FollowingSourceMode.following,
                  label: '关注',
                  icon: Icons.favorite_rounded,
                ),
                _PillOption(
                  value: FollowingSourceMode.bookmarks,
                  label: '收藏',
                  icon: Icons.bookmarks_rounded,
                ),
              ],
              onChanged: onSourceModeChanged,
            ),
            if (sourceMode == FollowingSourceMode.bookmarks)
              _PillToggle<BookmarkRestMode>(
                value: bookmarkRestMode,
                options: const [
                  _PillOption(value: BookmarkRestMode.hide, label: '私有'),
                  _PillOption(value: BookmarkRestMode.show, label: '公开'),
                ],
                onChanged: onBookmarkRestModeChanged,
              ),
            _PillToggle<FollowingFeedMode>(
              value: feedMode,
              options: const [
                _PillOption(value: FollowingFeedMode.all, label: '全部'),
                _PillOption(value: FollowingFeedMode.safe, label: 'Safe'),
                _PillOption(value: FollowingFeedMode.r18, label: 'R18'),
              ],
              onChanged: onFeedModeChanged,
            ),
            _PillToggle<FollowingDisplayMode>(
              value: displayMode,
              options: const [
                _PillOption(
                  value: FollowingDisplayMode.list,
                  label: '列表',
                  icon: Icons.view_agenda_rounded,
                ),
                _PillOption(
                  value: FollowingDisplayMode.grid,
                  label: '网格',
                  icon: Icons.grid_view_rounded,
                ),
              ],
              onChanged: onDisplayModeChanged,
            ),
            _PillAction(
              icon: Icons.tune_rounded,
              label: activeFilterCount > 0 ? '筛选 $activeFilterCount' : '筛选',
              selected: activeFilterCount > 0,
              onTap: onOpenFilters,
            ),
            _IconPillAction(
              icon: Icons.refresh_rounded,
              tooltip: '刷新',
              onTap: onRefresh,
            ),
          ],
        ),
        if (selectedAuthor.isNotEmpty || selectedTags.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (selectedAuthor.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _ActiveChip(
                      label: selectedAuthor,
                      onDeleted: onClearAuthor,
                    ),
                  ),
                for (final tag in selectedTags)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _ActiveChip(
                      label: tag,
                      onDeleted: () => onRemoveTag(tag),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );

    if (phone) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
        child: content,
      );
    }

    return _Surface(child: content);
  }
}

class _FollowSidebar extends StatelessWidget {
  final bool compact;
  final String activeUserLabel;
  final String selectedAuthor;
  final List<String> selectedTags;
  final VoidCallback onClearAuthor;
  final VoidCallback onClearFilters;
  final ValueChanged<String> onRemoveTag;

  const _FollowSidebar({
    required this.compact,
    required this.activeUserLabel,
    required this.selectedAuthor,
    required this.selectedTags,
    required this.onClearAuthor,
    required this.onClearFilters,
    required this.onRemoveTag,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '筛选',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (selectedAuthor.isNotEmpty || selectedTags.isNotEmpty)
              TextButton(
                onPressed: onClearFilters,
                child: const Text('清空'),
              ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            '当前用户: $activeUserLabel',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _InlineLabel(
          label: '作者',
          trailing: selectedAuthor.isEmpty
              ? null
              : IconButton(
                  onPressed: onClearAuthor,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  visualDensity: VisualDensity.compact,
                ),
        ),
        const SizedBox(height: 4),
        Text(selectedAuthor.isEmpty ? '未选择' : selectedAuthor),
        if (selectedTags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedTags.map((tag) {
              return _ActiveChip(
                label: tag,
                onDeleted: () => onRemoveTag(tag),
              );
            }).toList(),
          ),
        ],
      ],
    );

    if (compact) {
      return content;
    }

    return _Surface(child: content);
  }
}

class _Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Surface({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}

class _SoftChip extends StatelessWidget {
  final String label;

  const _SoftChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE1E5EA)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PillOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const _PillOption({
    required this.value,
    required this.label,
    this.icon,
  });
}

class _PillToggle<T> extends StatelessWidget {
  final T value;
  final List<_PillOption<T>> options;
  final ValueChanged<T> onChanged;

  const _PillToggle({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE1E5EA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            _PillToggleItem<T>(
              option: option,
              selected: option.value == value,
              onTap: () => onChanged(option.value),
            ),
        ],
      ),
    );
  }
}

class _PillToggleItem<T> extends StatelessWidget {
  final _PillOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  const _PillToggleItem({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? const Color(0xFF0077C8) : const Color(0xFF636B76);
    return InkWell(
      borderRadius: BorderRadius.circular(5),
      onTap: selected ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F5FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: selected ? const Color(0xFFB8E1FF) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (option.icon != null) ...[
              Icon(option.icon, size: 14, color: foreground),
              const SizedBox(width: 4),
            ],
            Text(
              option.label,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PillAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? const Color(0xFF0077C8) : const Color(0xFF454B54);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F5FF) : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? const Color(0xFFB8E1FF) : const Color(0xFFE1E5EA),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: foreground,
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

class _IconPillAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconPillAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE1E5EA)),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFF475569)),
        ),
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onDeleted;

  const _ActiveChip({
    required this.label,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onDeleted: onDeleted,
      visualDensity: VisualDensity.compact,
      backgroundColor: const Color(0xFFEFF6FF),
      side: const BorderSide(color: Color(0xFFBFDBFE)),
      labelStyle: const TextStyle(
        color: Color(0xFF1D4ED8),
        fontWeight: FontWeight.w600,
      ),
      deleteIconColor: const Color(0xFF1D4ED8),
    );
  }
}

class _InlineLabel extends StatelessWidget {
  final String label;
  final Widget? trailing;

  const _InlineLabel({
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF243B53),
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;

  const _SheetLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF636B76),
            ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String description;

  const _EmptyState({
    required this.title,
    required this.description,
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
              Icons.inbox_outlined,
              size: 40,
              color: Color(0xFF64748B),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
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
