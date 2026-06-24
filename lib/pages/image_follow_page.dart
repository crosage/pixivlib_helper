import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:tagselector/components/image_with_info.dart';
import 'package:tagselector/components/masonry_image_tile.dart';
import 'package:tagselector/components/mobile_chrome.dart';
import 'package:tagselector/components/page_bottombar.dart';
import 'package:tagselector/components/search_tool.dart';
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

  late Future<List<String>> _tagSuggestionsFuture;
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
    _tagSuggestionsFuture = _api.fetchTagSuggestions();
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

  void _refreshFollowing() {
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
  }) async {
    final images = await _api.fetchFollowingImages(page: page, mode: mode);
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
                    tagSearch: _buildTagSearch(),
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

  Widget _buildTagSearch() {
    return FutureBuilder<List<String>>(
      future: _tagSuggestionsFuture,
      builder: (context, tagSnapshot) {
        return SearchTool(
          suggestions: tagSnapshot.data ?? const [],
          onInclude: _toggleTag,
          onExclude: _toggleTag,
          hintText: '添加 tag',
        );
      },
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
            final tagSearch = _buildTagSearch();

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
                                onRefresh: _refreshFollowing,
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
                            tagSearch: tagSearch,
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
                  _Surface(
                    padding: EdgeInsets.zero,
                    child: PageBottomBar(
                      currentPage: _page,
                      canGoNext: rawImages.isNotEmpty,
                      onPageChange: _changePage,
                      summary: snapshot.hasError
                          ? '加载失败: ${snapshot.error}'
                          : '${images.length} 条结果',
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
    );
  }

  Widget _buildBody(
    AsyncSnapshot<List<ImageModel>> snapshot,
    List<ImageModel> images, {
    required bool phone,
  }) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        snapshot.data == null) {
      return const Center(child: CircularProgressIndicator());
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
    required this.onOpenFilters,
    required this.onRemoveTag,
    required this.onClearAuthor,
  });

  @override
  Widget build(BuildContext context) {
    if (phone) {
      final subtitle = [
        '$resultCount 个作品',
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
          MobilePill(
            icon: Icons.tune_rounded,
            label: activeFilterCount > 0 ? '筛选 $activeFilterCount' : '筛选',
            selected: activeFilterCount > 0,
            onTap: onOpenFilters,
          ),
          MobileIconButton(
            icon: Icons.refresh_rounded,
            tooltip: '刷新',
            onTap: onRefresh,
          ),
        ],
        bottom: MobileToolbarRow(
          children: [
            MobileSegmentedControl<FollowingSourceMode>(
              selected: sourceMode,
              segments: const [
                MobileSegment(
                  value: FollowingSourceMode.following,
                  label: '关注',
                ),
                MobileSegment(
                  value: FollowingSourceMode.bookmarks,
                  label: '收藏',
                ),
              ],
              onChanged: onSourceModeChanged,
            ),
            if (sourceMode == FollowingSourceMode.bookmarks)
              MobileSegmentedControl<BookmarkRestMode>(
                selected: bookmarkRestMode,
                segments: const [
                  MobileSegment(value: BookmarkRestMode.hide, label: '私有'),
                  MobileSegment(value: BookmarkRestMode.show, label: '公开'),
                ],
                onChanged: onBookmarkRestModeChanged,
              ),
            MobileSegmentedControl<FollowingFeedMode>(
              selected: feedMode,
              segments: const [
                MobileSegment(value: FollowingFeedMode.all, label: '全部'),
                MobileSegment(value: FollowingFeedMode.safe, label: 'Safe'),
                MobileSegment(value: FollowingFeedMode.r18, label: 'R18'),
              ],
              onChanged: onFeedModeChanged,
            ),
            MobileSegmentedControl<FollowingDisplayMode>(
              selected: displayMode,
              segments: const [
                MobileSegment(
                  value: FollowingDisplayMode.list,
                  label: '列表',
                  icon: Icons.view_agenda_rounded,
                ),
                MobileSegment(
                  value: FollowingDisplayMode.grid,
                  label: '网格',
                  icon: Icons.grid_view_rounded,
                ),
              ],
              onChanged: onDisplayModeChanged,
            ),
          ],
        ),
      );
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SoftChip(label: '$resultCount'),
            const SizedBox(width: 8),
            SegmentedButton<FollowingSourceMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: FollowingSourceMode.following,
                  label: Text('关注'),
                ),
                ButtonSegment(
                  value: FollowingSourceMode.bookmarks,
                  label: Text('收藏'),
                ),
              ],
              selected: {sourceMode},
              onSelectionChanged: (values) => onSourceModeChanged(values.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            if (sourceMode == FollowingSourceMode.bookmarks) ...[
              const SizedBox(width: 8),
              SegmentedButton<BookmarkRestMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: BookmarkRestMode.hide,
                    label: Text('私有'),
                  ),
                  ButtonSegment(
                    value: BookmarkRestMode.show,
                    label: Text('公开'),
                  ),
                ],
                selected: {bookmarkRestMode},
                onSelectionChanged: (values) =>
                    onBookmarkRestModeChanged(values.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
            const SizedBox(width: 8),
            SegmentedButton<FollowingFeedMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: FollowingFeedMode.all,
                  label: Text('全部'),
                ),
                ButtonSegment(
                  value: FollowingFeedMode.safe,
                  label: Text('Safe'),
                ),
                ButtonSegment(
                  value: FollowingFeedMode.r18,
                  label: Text('R18'),
                ),
              ],
              selected: {feedMode},
              onSelectionChanged: (values) => onFeedModeChanged(values.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const Spacer(),
            SegmentedButton<FollowingDisplayMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: FollowingDisplayMode.list,
                  label: Text('列表'),
                  icon: Icon(Icons.view_agenda_rounded),
                ),
                ButtonSegment(
                  value: FollowingDisplayMode.grid,
                  label: Text('网格'),
                  icon: Icon(Icons.grid_view_rounded),
                ),
              ],
              selected: {displayMode},
              onSelectionChanged: (values) {
                onDisplayModeChanged(values.first);
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: '刷新',
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
  final Widget tagSearch;
  final String activeUserLabel;
  final String selectedAuthor;
  final List<String> selectedTags;
  final VoidCallback onClearAuthor;
  final VoidCallback onClearFilters;
  final ValueChanged<String> onRemoveTag;

  const _FollowSidebar({
    required this.compact,
    required this.tagSearch,
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
        tagSearch,
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
    final compact = MediaQuery.sizeOf(context).width < 640;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
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
