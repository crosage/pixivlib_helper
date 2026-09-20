import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tagselector/components/image_with_info.dart';
import 'package:tagselector/components/app_ui.dart';
import 'package:tagselector/components/masonry_image_tile.dart';
import 'package:tagselector/components/mobile_chrome.dart';
import 'package:tagselector/components/page_bottombar.dart';
import 'package:tagselector/components/search_tool.dart';
import 'package:tagselector/model/author_model.dart';
import 'package:tagselector/model/image_model.dart';
import 'package:tagselector/model/search_model.dart';
import 'package:tagselector/pages/author_page.dart';
import 'package:tagselector/pages/full_image_page.dart';
import 'package:tagselector/service/api_service.dart';
import 'package:tagselector/service/app_user_session.dart';
import 'package:tagselector/service/detail_visit_stats.dart';
import 'package:tagselector/service/image_prefetcher.dart';

enum DisplayMode { list, grid }

class ImageListPage extends StatefulWidget {
  const ImageListPage({super.key});

  @override
  State<ImageListPage> createState() => _ImageListPageState();
}

class _ImageListPageState extends State<ImageListPage> {
  static const _presetKey = 'image_search_presets_v1';
  static const _sortOptions = [
    ('bookmark_count', '收藏'),
    ('pid', 'PID'),
  ];

  final _api = ApiService.instance;
  final AppUserSession _session = AppUserSession.instance;
  final _criteria = SearchCriteria();
  final _scrollController = ScrollController();
  final _authorNameController = TextEditingController();
  final _authorUidController = TextEditingController();
  final _pidController = TextEditingController();
  final _minLikesController = TextEditingController();
  final _maxLikesController = TextEditingController();
  final _pageSizeController = TextEditingController(text: '24');

  Future<List<String>>? _tagSuggestionsFuture;
  Future<List<Author>>? _authorSuggestionsFuture;
  Future<PagedImagesResponse>? _resultsFuture;
  Timer? _debounceTimer;
  Timer? _scrollPrefetchTimer;
  List<SearchPreset> _presets = const [];
  final Map<int, ImageModel> _imageOverrides = <int, ImageModel>{};
  final Set<int> _bookmarkHydrationInFlight = <int>{};
  List<ImageModel> _visibleImagesForPrefetch = const [];
  final List<ImageModel> _discoveryImages = <ImageModel>[];
  final Set<int> _inlineRecommendationPids = <int>{};
  final Set<int> _discoverySeenPids = <int>{};
  final ImagePrefetcher _prefetcher = ImagePrefetcher.instance;
  final DetailVisitStats _visitStats = DetailVisitStats.instance;
  DisplayMode _displayMode = DisplayMode.grid;
  bool _showingDiscovery = false;
  bool _isDiscoveryLoadingMore = false;
  bool _hasMoreDiscovery = true;
  Object? _discoveryLoadMoreError;
  int _discoveryRequestId = 0;

  @override
  void initState() {
    super.initState();
    _session.addListener(_handleUserChanged);
    _scrollController.addListener(_handleScroll);
    _loadPresets();
    _loadDiscoveryRecommendations();
  }

  @override
  void dispose() {
    _session.removeListener(_handleUserChanged);
    _debounceTimer?.cancel();
    _scrollPrefetchTimer?.cancel();
    _scrollController.dispose();
    _authorNameController.dispose();
    _authorUidController.dispose();
    _pidController.dispose();
    _minLikesController.dispose();
    _maxLikesController.dispose();
    _pageSizeController.dispose();
    super.dispose();
  }

  void _handleUserChanged() {
    if (!mounted) {
      return;
    }
    _imageOverrides.clear();
    _criteria.page = 1;
    if (_showingDiscovery) {
      _loadDiscoveryRecommendations();
      return;
    }
    _refreshResults();
  }

  Future<void> _loadPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_presetKey);
    if (raw == null || raw.isEmpty || !mounted) {
      return;
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      setState(() {
        _presets = decoded
            .map(
              (item) => SearchPreset.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
      });
    } catch (_) {
      // Ignore corrupt local presets; the next save will overwrite them.
    }
  }

  Future<void> _persistPresets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _presetKey,
      jsonEncode(_presets.map((preset) => preset.toJson()).toList()),
    );
  }

  void _applyFormFilters() {
    _criteria.authorName = _authorNameController.text.trim();
    _criteria.authorUid = _authorUidController.text.trim();
    _criteria.pid = int.tryParse(_pidController.text.trim());
    _criteria.minBookmarkCount = int.tryParse(_minLikesController.text.trim());
    _criteria.maxBookmarkCount = int.tryParse(_maxLikesController.text.trim());
    final pageSize = int.tryParse(_pageSizeController.text.trim());
    if (pageSize != null && pageSize > 0) {
      _criteria.pageSize = pageSize;
    }
  }

  void _syncFormFromCriteria() {
    _authorNameController.text = _criteria.authorName;
    _authorUidController.text = _criteria.authorUid;
    _pidController.text = _criteria.pid?.toString() ?? '';
    _minLikesController.text = _criteria.minBookmarkCount?.toString() ?? '';
    _maxLikesController.text = _criteria.maxBookmarkCount?.toString() ?? '';
    _pageSizeController.text = _criteria.pageSize.toString();
  }

  void _refreshResults() {
    _applyFormFilters();
    _discoveryRequestId++;
    _discoveryImages.clear();
    _inlineRecommendationPids.clear();
    _discoverySeenPids.clear();
    _hasMoreDiscovery = true;
    _isDiscoveryLoadingMore = false;
    _discoveryLoadMoreError = null;
    setState(() {
      _showingDiscovery = false;
      _resultsFuture = _fetchSearchResults();
    });
  }

  Future<PagedImagesResponse> _fetchSearchResults() async {
    final response = await _api.searchImages(_criteria);
    _prepareImages(response.images);
    return response;
  }

  void _prepareImages(List<ImageModel> images) {
    _prefetcher.prefetchImageModels(
      images.take(_displayMode == DisplayMode.grid ? 8 : 12),
      highQuality: _displayMode == DisplayMode.list,
      limit: _displayMode == DisplayMode.grid ? 8 : 12,
    );
    _hydrateBookmarkCounts(images);
  }

  Future<void> _insertBookmarkedRecommendations(ImageModel seedImage) async {
    if (!_showingDiscovery || seedImage.pid <= 0) {
      return;
    }

    try {
      final recommendations = await _api.fetchImageRecommendations(
        seedImage.pid,
        limit: 4,
      );
      if (!mounted || !_showingDiscovery) {
        return;
      }

      final existingPids = {
        ..._discoveryImages.map((image) => image.pid),
        ..._inlineRecommendationPids,
      };
      final images = recommendations
          .map((recommendation) => recommendation.toPlaceholderImage())
          .where((image) => image.pid > 0 && !existingPids.contains(image.pid))
          .take(4)
          .toList(growable: false);
      if (images.isEmpty) {
        return;
      }

      final seedIndex =
          _discoveryImages.indexWhere((image) => image.pid == seedImage.pid);
      final insertIndex = seedIndex < 0 ? _discoveryImages.length : seedIndex + 1;
      setState(() {
        _discoveryImages.insertAll(insertIndex, images);
        _discoverySeenPids.addAll(images.map((image) => image.pid));
        _inlineRecommendationPids.addAll(images.map((image) => image.pid));
        _resultsFuture = Future.value(
          PagedImagesResponse(
            images: List<ImageModel>.of(_discoveryImages),
            total: _discoverySeenPids.length,
          ),
        );
      });
      _prepareImages(images);
    } catch (_) {
      // Inline recommendations are best-effort and must not affect liking.
    }
  }

  void _refreshVisibleResults() {
    if (_showingDiscovery) {
      _loadDiscoveryRecommendations();
      return;
    }
    _refreshResults();
  }

  Future<void> _pullToRefreshDiscovery() async {
    _refreshVisibleResults();
    try {
      await _resultsFuture;
    } catch (_) {
      // The page already renders its error state; let the indicator settle.
    }
  }

  void _loadDiscoveryRecommendations({bool resetPage = true}) {
    _applyFormFilters();
    final pageSize = _criteria.pageSize <= 0 ? 30 : _criteria.pageSize;
    final limit = pageSize.clamp(1, 60).toInt();
    final requestId = ++_discoveryRequestId;
    if (resetPage) {
      _criteria.page = 1;
      _discoveryImages.clear();
      _inlineRecommendationPids.clear();
      _discoverySeenPids.clear();
      _hasMoreDiscovery = true;
      _isDiscoveryLoadingMore = false;
      _discoveryLoadMoreError = null;
    }

    setState(() {
      _showingDiscovery = true;
      _resultsFuture = _fetchDiscoveryBatch(
        limit: limit,
        requestId: requestId,
        replace: true,
      );
    });
  }

  Future<PagedImagesResponse> _fetchDiscoveryBatch({
    required int limit,
    required int requestId,
    required bool replace,
  }) async {
    final history = await _visitStats.loadRecords();
    final recommendations = await _api.fetchDiscoveryRecommendations(
      limit: limit,
      seenPids: _discoverySeenPids.take(300),
      history: history
          .map(
            (record) => DiscoveryHistorySignal(
              pid: record.pid,
              visitedAt: record.visitedAt,
            ),
          )
          .toList(growable: false),
      criteria: _criteria,
    );
    if (!mounted || requestId != _discoveryRequestId) {
      return PagedImagesResponse(
        images: List<ImageModel>.of(_discoveryImages),
        total: _discoverySeenPids.length,
      );
    }

    final images = recommendations
        .map((recommendation) => recommendation.toPlaceholderImage())
        .where(
            (image) => image.pid > 0 && !_discoverySeenPids.contains(image.pid))
        .toList();
    if (replace) {
      _discoveryImages
        ..clear()
        ..addAll(images);
    } else {
      _discoveryImages.addAll(images);
    }
    _discoverySeenPids.addAll(images.map((image) => image.pid));
    _hasMoreDiscovery = images.isNotEmpty;
    _prepareImages(images);
    return PagedImagesResponse(
      images: List<ImageModel>.of(_discoveryImages),
      total: _discoverySeenPids.length,
    );
  }

  void _handleScroll() {
    if (!_showingDiscovery ||
        _isDiscoveryLoadingMore ||
        !_hasMoreDiscovery ||
        !_scrollController.hasClients ||
        _discoveryImages.isEmpty) {
      return;
    }
    final position = _scrollController.position;
    if (position.extentAfter < 900) {
      _loadMoreDiscoveryRecommendations();
    }
    _scheduleScrollPrefetch();
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
          _displayMode == DisplayMode.list ? 420.0 : 220.0;
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

  Future<void> _loadMoreDiscoveryRecommendations() async {
    if (_isDiscoveryLoadingMore || !_hasMoreDiscovery) return;
    _applyFormFilters();
    final pageSize = _criteria.pageSize <= 0 ? 30 : _criteria.pageSize;
    final limit = pageSize.clamp(1, 60).toInt();
    final requestId = ++_discoveryRequestId;
    setState(() {
      _isDiscoveryLoadingMore = true;
      _discoveryLoadMoreError = null;
    });

    try {
      final response = await _fetchDiscoveryBatch(
        limit: limit,
        requestId: requestId,
        replace: false,
      );
      if (!mounted || requestId != _discoveryRequestId) return;
      setState(() {
        _resultsFuture = Future.value(response);
      });
    } catch (error) {
      if (!mounted || requestId != _discoveryRequestId) return;
      setState(() {
        _discoveryLoadMoreError = error;
      });
    } finally {
      if (mounted && requestId == _discoveryRequestId) {
        setState(() {
          _isDiscoveryLoadingMore = false;
        });
      }
    }
  }

  void _changePage(int page) {
    if (page < 1) {
      return;
    }

    _criteria.page = page;
    if (_showingDiscovery) {
      _loadDiscoveryRecommendations(resetPage: false);
      return;
    }
    _refreshResults();
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

  void _scheduleRefresh() {
    _criteria.page = 1;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), _refreshResults);
  }

  void _toggleIncludeTag(String tag) {
    setState(() => _criteria.toggleTag(tag));
    _scheduleRefresh();
  }

  void _toggleExcludeTag(String tag) {
    setState(() => _criteria.toggleExcludedTag(tag));
    _scheduleRefresh();
  }

  void _toggleAuthor(String author) {
    setState(() {
      _criteria.authorName = _criteria.authorName == author ? '' : author;
      _authorNameController.text = _criteria.authorName;
    });
    _scheduleRefresh();
  }

  void _selectAuthorSuggestion(Author suggestion) {
    setState(() {
      _criteria.authorName = suggestion.name;
      _authorNameController.text = suggestion.name;
      if (suggestion.uid.isNotEmpty) {
        _criteria.authorUid = suggestion.uid;
        _authorUidController.text = suggestion.uid;
      }
    });
    _scheduleRefresh();
  }

  Future<void> _openAuthorBrowser(List<Author> authors) async {
    final suggestions = authors
        .where(
          (author) => author.name.isNotEmpty || author.uid.isNotEmpty,
        )
        .toList(growable: false);
    if (suggestions.isEmpty) {
      return;
    }

    final searchController = TextEditingController();
    String keyword = '';

    List<Author> visibleAuthorsFor(String value) {
      final normalized = value.trim().toLowerCase();
      return suggestions
          .where((author) {
            if (normalized.isEmpty) {
              return true;
            }
            return author.name.toLowerCase().contains(normalized) ||
                author.uid.toLowerCase().contains(normalized);
          })
          .take(160)
          .toList(growable: false);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final visibleAuthors = visibleAuthorsFor(keyword);
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
                ),
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.72,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '全部作者',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '可以像全部标签一样搜索作者，并直接填入作者名或 UID 筛选。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF64748B),
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchController,
                        autofocus: true,
                        onChanged: (value) {
                          setSheetState(() => keyword = value);
                        },
                        decoration: const InputDecoration(
                          hintText: '搜索作者名或 UID',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const _AuthorBrowserHint(
                            icon: Icons.person_rounded,
                            label: '作者名',
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 8),
                          const _AuthorBrowserHint(
                            icon: Icons.badge_rounded,
                            label: 'UID',
                            color: Color(0xFF0F766E),
                          ),
                          const Spacer(),
                          Text(
                            '${visibleAuthors.length} 项',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: visibleAuthors.isEmpty
                            ? const Center(child: Text('没有匹配的作者'))
                            : ListView.separated(
                                itemCount: visibleAuthors.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final author = visibleAuthors[index];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: const CircleAvatar(
                                      radius: 15,
                                      backgroundColor: Color(0xFFEFF6FF),
                                      child: Icon(
                                        Icons.person_rounded,
                                        size: 17,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                    title: Text(
                                      author.name.isEmpty
                                          ? 'UID ${author.uid}'
                                          : author.name,
                                    ),
                                    subtitle: author.uid.isEmpty
                                        ? null
                                        : Text('UID ${author.uid}'),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      _selectAuthorSuggestion(author);
                                    },
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: author.name.isEmpty
                                              ? null
                                              : () {
                                                  Navigator.of(context).pop();
                                                  setState(() {
                                                    _criteria.authorName =
                                                        author.name;
                                                    _authorNameController.text =
                                                        author.name;
                                                  });
                                                  _scheduleRefresh();
                                                },
                                          icon:
                                              const Icon(Icons.person_rounded),
                                          color: const Color(0xFF2563EB),
                                          tooltip: '按作者名筛选',
                                        ),
                                        IconButton(
                                          onPressed: author.uid.isEmpty
                                              ? null
                                              : () {
                                                  Navigator.of(context).pop();
                                                  setState(() {
                                                    _criteria.authorUid =
                                                        author.uid;
                                                    _authorUidController.text =
                                                        author.uid;
                                                  });
                                                  _scheduleRefresh();
                                                },
                                          icon: const Icon(Icons.badge_rounded),
                                          color: const Color(0xFF0F766E),
                                          tooltip: '按 UID 筛选',
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2007, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _criteria.publishedAfter =
            DateTime(picked.year, picked.month, picked.day);
      } else {
        _criteria.publishedBefore =
            DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
    _scheduleRefresh();
  }

  Future<void> _savePreset() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存筛选预设'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '预设名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    setState(() {
      _presets = [
        ..._presets.where((preset) => preset.name != name),
        SearchPreset(name: name, criteria: _criteria.copy()),
      ];
    });
    await _persistPresets();
  }

  void _applyPreset(SearchPreset preset) {
    setState(() {
      _criteria.applyFrom(preset.criteria.copy());
      _syncFormFromCriteria();
    });
    _scheduleRefresh();
  }

  Future<void> _deletePreset(String name) async {
    setState(() {
      _presets = _presets.where((preset) => preset.name != name).toList();
    });
    await _persistPresets();
  }

  void _clearAllFilters() {
    setState(() {
      _criteria.clearAllFilters();
      _syncFormFromCriteria();
    });
    _scheduleRefresh();
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
    setState(() {
      _criteria.addTag(selectedTag);
    });
    _scheduleRefresh();
  }

  void _prefetchAround(List<ImageModel> images, int index) {
    final start = (index + 1).clamp(0, images.length);
    final end = (index + (_displayMode == DisplayMode.grid ? 7 : 13))
        .clamp(0, images.length);
    if (start >= end) return;
    _prefetcher.prefetchImageModels(
      images.sublist(start, end),
      highQuality: _displayMode == DisplayMode.list,
      limit: _displayMode == DisplayMode.grid ? 6 : 8,
    );
  }

  Future<void> _openFilterSheet() async {
    _ensureFilterSuggestions();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final sheetHeight = MediaQuery.sizeOf(context).height * 0.82;
        final padding = EdgeInsets.fromLTRB(
          12,
          4,
          12,
          MediaQuery.viewInsetsOf(context).bottom + 12,
        );

        Widget shell({required Widget child}) {
          return MobileSheetFrame(
            padding: padding,
            child: SizedBox(
              height: sheetHeight,
              child: MobileSheetSection(child: child),
            ),
          );
        }

        return DeferredSheetContent(
          placeholder: shell(
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                return shell(
                  child: _buildSidebarContent(
                    phone: true,
                    sheet: true,
                    onSheetChanged: () => setSheetState(() {}),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openGalleryOptionsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(
                  '图库设置',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: const Text('筛选作品'),
                subtitle: Text(
                  _activeFilterCount > 0
                      ? '已启用 $_activeFilterCount 个条件'
                      : '标签、作者、收藏数和时间',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openFilterSheet();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.grid_view_rounded),
                title: const Text('网格视图'),
                trailing: _displayMode == DisplayMode.grid
                    ? const Icon(Icons.check_rounded, color: Color(0xFF0096FA))
                    : null,
                onTap: () {
                  setState(() => _displayMode = DisplayMode.grid);
                  Navigator.of(sheetContext).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.view_agenda_outlined),
                title: const Text('列表视图'),
                trailing: _displayMode == DisplayMode.list
                    ? const Icon(Icons.check_rounded, color: Color(0xFF0096FA))
                    : null,
                onTap: () {
                  setState(() => _displayMode = DisplayMode.list);
                  Navigator.of(sheetContext).pop();
                },
              ),
              const Divider(),
              if (_activeFilterCount > 0)
                ListTile(
                  leading: const Icon(Icons.filter_alt_off_outlined),
                  title: const Text('清空筛选'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _clearAllFilters();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _ensureFilterSuggestions() {
    if (_tagSuggestionsFuture == null) {
      final future = _api.fetchTagSuggestions(limit: 100000);
      _tagSuggestionsFuture = future;
      future.whenComplete(() {
        if (mounted) setState(() {});
      });
    }
    if (_authorSuggestionsFuture == null) {
      final future = _api.fetchAuthorSuggestions(limit: 100000);
      _authorSuggestionsFuture = future;
      future.whenComplete(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PagedImagesResponse>(
      future: _resultsFuture,
      builder: (context, snapshot) {
        final images = (snapshot.data?.images ?? const <ImageModel>[])
            .map((image) => _imageOverrides[image.pid] ?? image)
            .toList();
        _visibleImagesForPrefetch = images;
        final total = snapshot.data?.total ?? 0;
        final totalPages = _showingDiscovery
            ? null
            : total == 0
                ? 1
                : ((total - 1) ~/ _criteria.pageSize) + 1;

        return LayoutBuilder(
          builder: (context, constraints) {
            final showSidebar = constraints.maxWidth >= 1180;
            final phone = constraints.maxWidth < 720;

            final content = Column(
              children: [
                MobileScrollHideToolbar(
                  enabled: phone,
                  scrollController: _scrollController,
                  height: 50,
                  child: _buildTopBar(
                    total,
                    compact: !showSidebar,
                    phone: phone,
                  ),
                ),
                SizedBox(height: phone ? 4 : 10),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: phone
                            ? _buildResults(snapshot, images, phone: true)
                            : _surface(
                                _buildResults(snapshot, images, phone: false),
                                padding: EdgeInsets.zero,
                              ),
                      ),
                      if (showSidebar) ...[
                        const SizedBox(width: 10),
                        SizedBox(width: 320, child: _buildSidebar()),
                      ],
                    ],
                  ),
                ),
                if (!_showingDiscovery) SizedBox(height: phone ? 4 : 10),
                if (!_showingDiscovery && phone)
                  PageBottomBar(
                    currentPage: _criteria.page,
                    totalPages: totalPages,
                    canGoNext: _showingDiscovery,
                    onPageChange: _changePage,
                  )
                else if (!_showingDiscovery)
                  Align(
                    alignment: Alignment.center,
                    child: PageBottomBar(
                      currentPage: _criteria.page,
                      totalPages: totalPages,
                      canGoNext: _showingDiscovery,
                      onPageChange: _changePage,
                      summary: snapshot.hasError
                          ? '加载失败：${snapshot.error}'
                          : '共 $total 条结果',
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

  Widget _buildTopBar(
    int total, {
    required bool compact,
    required bool phone,
  }) {
    final modeSelector = SegmentedButton<DisplayMode>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: DisplayMode.list,
          icon: const Icon(Icons.view_agenda_rounded),
          label: Text(phone ? '' : '列表'),
        ),
        ButtonSegment(
          value: DisplayMode.grid,
          icon: const Icon(Icons.grid_view_rounded),
          label: Text(phone ? '' : '网格'),
        ),
      ],
      selected: {_displayMode},
      onSelectionChanged: (values) {
        setState(() => _displayMode = values.first);
      },
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );

    if (phone) {
      final sortLabel = _sortOptions
          .firstWhere(
            (option) => option.$1 == _criteria.sortBy,
            orElse: () => _sortOptions.first,
          )
          .$2;
      final subtitle = [
        _showingDiscovery ? 'Pixiv 官方推荐 · $total 项' : '作品 $total',
        '排序 $sortLabel',
        if (_activeFilterCount > 0) '筛选 $_activeFilterCount',
      ].join(' · ');

      return MobileToolbar(
        title: _showingDiscovery ? '发现' : '图库',
        subtitle: subtitle,
        leading: Icon(
          _showingDiscovery ? Icons.auto_awesome_rounded : Icons.image_rounded,
          color: mobileBlue,
        ),
        actions: [
          MobileIconButton(
            icon: Icons.tune_rounded,
            tooltip: '图库设置',
            onTap: _openGalleryOptionsSheet,
          ),
          MobileIconButton(
            icon: Icons.refresh_rounded,
            tooltip: '刷新',
            onTap: _refreshVisibleResults,
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
                color: const Color(0xFFE8F5FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _showingDiscovery
                    ? Icons.auto_awesome_rounded
                    : Icons.photo_library_outlined,
                color: const Color(0xFF0096FA),
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _showingDiscovery ? 'Pixiv 官方主题推荐' : '本地图库',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _showingDiscovery
                        ? '来自 Pixiv 首页推荐，结合最近浏览记录补充结果'
                        : '检索、整理和浏览已收录作品',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            _metaChip('$total 项'),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 10),
        Row(
          children: [
            modeSelector,
            const Spacer(),
            if (compact)
              _squareIconButton(
                icon: Icons.tune_rounded,
                tooltip: _activeFilterCount > 0
                    ? '筛选：$_activeFilterCount 个条件'
                    : '打开筛选',
                active: _activeFilterCount > 0,
                onTap: _openFilterSheet,
              ),
            if (compact) const SizedBox(width: 6),
            _squareIconButton(
              icon: Icons.refresh_rounded,
              tooltip: '刷新当前结果',
              onTap: _refreshVisibleResults,
            ),
            const SizedBox(width: 6),
            _squareIconButton(
              icon: Icons.auto_awesome_rounded,
              tooltip: _showingDiscovery ? '重新加载发现作品' : '打开发现作品',
              active: _showingDiscovery,
              onTap: _loadDiscoveryRecommendations,
            ),
            if (_activeFilterCount > 0) ...[
              const SizedBox(width: 6),
              _squareIconButton(
                icon: Icons.filter_alt_off_rounded,
                tooltip: '清空筛选',
                onTap: _clearAllFilters,
              ),
            ],
          ],
        ),
        if (_criteria.tags.isNotEmpty || _criteria.excludedTags.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final tag in _criteria.tags)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InputChip(
                      label: Text('包含 $tag'),
                      onDeleted: () => _toggleIncludeTag(tag),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                for (final tag in _criteria.excludedTags)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InputChip(
                      label: Text('排除 $tag'),
                      onDeleted: () => _toggleExcludeTag(tag),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: const Color(0xFFFFF1F2),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );

    return _surface(content);
  }

  Widget _buildSidebar() {
    return _surface(_buildSidebarContent(phone: false));
  }

  Widget _buildSidebarContent({
    required bool phone,
    bool sheet = false,
    VoidCallback? onSheetChanged,
  }) {
    void toggleIncludeTag(String tag) {
      _toggleIncludeTag(tag);
      onSheetChanged?.call();
    }

    void toggleExcludeTag(String tag) {
      _toggleExcludeTag(tag);
      onSheetChanged?.call();
    }

    void applyPreset(SearchPreset preset) {
      _applyPreset(preset);
      onSheetChanged?.call();
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Row(
          children: [
            const Expanded(
                child: _FilterSectionTitle(
                    icon: Icons.tune_rounded, label: '筛选条件')),
            if (_activeFilterCount > 0) _metaChip('$_activeFilterCount 个条件'),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<String>>(
          future: _tagSuggestionsFuture,
          builder: (context, snapshot) => SearchTool(
            suggestions: snapshot.data ?? const [],
            onInclude: toggleIncludeTag,
            onExclude: toggleExcludeTag,
            onActivated: _ensureFilterSuggestions,
          ),
        ),
        if (_criteria.tags.isNotEmpty || _criteria.excludedTags.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            '已选标签',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in _criteria.tags)
                InputChip(
                  label: Text('#$tag'),
                  selected: true,
                  onDeleted: () => toggleIncludeTag(tag),
                ),
              for (final tag in _criteria.excludedTags)
                InputChip(
                  label: Text('-$tag'),
                  selected: true,
                  deleteIconColor: const Color(0xFFE11D48),
                  onDeleted: () => toggleExcludeTag(tag),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _field(
          '作者',
          Column(
            children: [
              TextField(
                controller: _authorNameController,
                decoration: const InputDecoration(hintText: '作者名，支持精确过滤'),
                onSubmitted: (_) => _refreshResults(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _authorUidController,
                decoration: const InputDecoration(hintText: '作者 UID，例如 810305'),
                onSubmitted: (_) => _refreshResults(),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FutureBuilder<List<Author>>(
                  future: _authorSuggestionsFuture,
                  builder: (context, snapshot) {
                    final authors = snapshot.data ?? const <Author>[];
                    final loading =
                        snapshot.connectionState == ConnectionState.waiting;
                    final failed = snapshot.hasError && authors.isEmpty;
                    return TextButton.icon(
                      onPressed: authors.isEmpty
                          ? (_authorSuggestionsFuture == null
                              ? _ensureFilterSuggestions
                              : null)
                          : () => _openAuthorBrowser(authors),
                      icon: Icon(
                        failed
                            ? Icons.error_outline_rounded
                            : Icons.people_alt_outlined,
                      ),
                      label: Text(
                        failed
                            ? '作者列表加载失败'
                            : _authorSuggestionsFuture == null
                                ? '加载作者列表'
                                : loading
                                    ? '正在加载作者...'
                                    : '查看全部作者 (${authors.length})',
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 8),
        _field(
          'PID',
          TextField(
            controller: _pidController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(hintText: '例如 124567890'),
            onSubmitted: (_) => _refreshResults(),
          ),
          icon: Icons.tag_rounded,
        ),
        const SizedBox(height: 12),
        const _FilterSectionTitle(
            icon: Icons.favorite_border_rounded, label: '收藏与状态'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minLikesController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(hintText: '最小'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('~'),
            ),
            Expanded(
              child: TextField(
                controller: _maxLikesController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(hintText: '最大'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _FilterSectionTitle(
            icon: Icons.calendar_today_outlined, label: '发布时间'),
        const SizedBox(height: 8),
        _dateButton(
          '开始时间',
          _criteria.publishedAfter,
          () => _pickDate(true),
          () {
            setState(() => _criteria.publishedAfter = null);
            _scheduleRefresh();
          },
          phone: phone,
        ),
        const SizedBox(height: 8),
        _dateButton(
          '结束时间',
          _criteria.publishedBefore,
          () => _pickDate(false),
          () {
            setState(() => _criteria.publishedBefore = null);
            _scheduleRefresh();
          },
          phone: phone,
        ),
        const SizedBox(height: 12),
        const _FilterSectionTitle(
            icon: Icons.bookmark_border_rounded, label: '收藏状态'),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'all', label: Text('全部')),
            ButtonSegment(value: 'yes', label: Text('已收藏')),
            ButtonSegment(value: 'no', label: Text('未收藏')),
          ],
          selected: {
            _criteria.isBookmarked == null
                ? 'all'
                : (_criteria.isBookmarked! ? 'yes' : 'no'),
          },
          onSelectionChanged: (values) {
            setState(() {
              _criteria.isBookmarked =
                  values.first == 'all' ? null : values.first == 'yes';
            });
            _scheduleRefresh();
          },
        ),
        const SizedBox(height: 12),
        _field(
          '每页数量',
          TextField(
            controller: _pageSizeController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(hintText: '默认 24'),
          ),
          icon: Icons.view_module_outlined,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _refreshResults,
              icon: const Icon(Icons.filter_alt_rounded),
              label: const Text('应用筛选'),
            ),
            FilledButton.tonalIcon(
              onPressed: _savePreset,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('保存预设'),
            ),
            if (sheet)
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('完成'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_presets.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _presets)
                InputChip(
                  label: Text(preset.name),
                  onPressed: () => applyPreset(preset),
                  onDeleted: () => _deletePreset(preset.name),
                ),
            ],
          )
        else
          const Text(
            '还没有保存的预设。',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
      ],
    );
  }

  int get _activeFilterCount {
    var count = 0;
    count += _criteria.tags.length;
    count += _criteria.excludedTags.length;
    if (_criteria.authorName.isNotEmpty) count++;
    if (_criteria.authorUid.isNotEmpty) count++;
    if (_criteria.pid != null) count++;
    if (_criteria.minBookmarkCount != null) count++;
    if (_criteria.maxBookmarkCount != null) count++;
    if (_criteria.publishedAfter != null) count++;
    if (_criteria.publishedBefore != null) count++;
    if (_criteria.isBookmarked != null) count++;
    return count;
  }

  Widget _buildResults(
    AsyncSnapshot<PagedImagesResponse> snapshot,
    List<ImageModel> images, {
    required bool phone,
  }) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        snapshot.data == null) {
      final loading = AppLoadingGrid(
        padding: EdgeInsets.symmetric(horizontal: phone ? 6 : 10),
        minTileWidth: phone ? 176 : 230,
      );
      if (phone && _showingDiscovery) {
        return RefreshIndicator(
          onRefresh: _pullToRefreshDiscovery,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [SizedBox(height: 520, child: loading)],
          ),
        );
      }
      return loading;
    }
    if (snapshot.hasError && images.isEmpty) {
      final error = Center(child: Text('加载失败：${snapshot.error}'));
      if (phone && _showingDiscovery) {
        return RefreshIndicator(
          onRefresh: _pullToRefreshDiscovery,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [SizedBox(height: 280, child: error)],
          ),
        );
      }
      return error;
    }
    if (images.isEmpty) {
      const empty = Center(child: Text('没有结果，可以减少筛选条件后再试。'));
      if (phone && _showingDiscovery) {
        return RefreshIndicator(
          onRefresh: _pullToRefreshDiscovery,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [SizedBox(height: 280, child: empty)],
          ),
        );
      }
      return empty;
    }

    if (_displayMode == DisplayMode.list) {
      final itemCount = images.length + (_showingDiscovery ? 1 : 0);
      final list = ListView.builder(
        controller: _scrollController,
        physics: phone && _showingDiscovery
            ? const AlwaysScrollableScrollPhysics()
            : null,
        cacheExtent: phone ? 1400 : 900,
        padding: EdgeInsets.fromLTRB(phone ? 0 : 8, 0, phone ? 0 : 8, 0),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= images.length) {
            return _buildDiscoveryFooter(phone: phone);
          }
          final image = images[index];
          final tile = ImageWithInfo(
            key: ValueKey('discovery-list-image-${image.pid}'),
            image: image,
            selectedTags: _criteria.tags,
            onSelectedTagsChanged: _toggleIncludeTag,
            onSelectedAuthor: _toggleAuthor,
            onImageChanged: _updateImage,
            onImageBookmarked:
                _showingDiscovery ? _insertBookmarkedRecommendations : null,
            onAuthorTap: () => _openAuthorPage(image.author),
            onImageTap: () => _openImagePage(image),
            highQualityPreview: true,
            showBookmarkCount: true,
          );
          if (!_inlineRecommendationPids.contains(image.pid)) {
            return tile;
          }
          return TweenAnimationBuilder<double>(
            key: ValueKey('inline-list-recommendation-${image.pid}'),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * 14),
                  child: child,
                ),
              );
            },
            child: tile,
          );
        },
      );
      final body = phone && _showingDiscovery
          ? RefreshIndicator(onRefresh: _pullToRefreshDiscovery, child: list)
          : list;
      return body;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            phone ? 176.0 : (constraints.maxWidth < 520 ? 164.0 : 220.0);
        final rawCount = (constraints.maxWidth / tileWidth).floor();
        final count = rawCount.clamp(phone ? 2 : 1, 6).toInt();
        final itemCount = images.length + (_showingDiscovery ? 1 : 0);
        final grid = MasonryGridView.count(
          controller: _scrollController,
          physics: phone && _showingDiscovery
              ? const AlwaysScrollableScrollPhysics()
              : null,
          cacheExtent: phone ? 700 : 650,
          padding: EdgeInsets.fromLTRB(phone ? 6 : 8, 0, phone ? 6 : 8, 0),
          crossAxisCount: count,
          crossAxisSpacing: phone ? 6 : 10,
          mainAxisSpacing: phone ? 6 : 10,
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index >= images.length) {
              return _buildDiscoveryFooter(phone: phone);
            }
            final image = images[index];
            final tile = MasonryImageTile(
              key: ValueKey('discovery-image-${image.pid}'),
              image: image,
              highQualityPreview:
                  !phone && defaultTargetPlatform != TargetPlatform.windows,
              showBookmarkCount: true,
              onImageChanged: _updateImage,
              onImageBookmarked:
                  _showingDiscovery ? _insertBookmarkedRecommendations : null,
              onTap: () => _openImagePage(image),
              onAuthorTap: () => _openAuthorPage(image.author),
            );
            if (!_inlineRecommendationPids.contains(image.pid)) {
              return tile;
            }
            return TweenAnimationBuilder<double>(
              key: ValueKey('inline-recommendation-${image.pid}'),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 14),
                    child: child,
                  ),
                );
              },
              child: tile,
            );
          },
        );
        final body = phone && _showingDiscovery
            ? RefreshIndicator(onRefresh: _pullToRefreshDiscovery, child: grid)
            : grid;
        return body;
      },
    );
  }

  Widget _buildDiscoveryFooter({required bool phone}) {
    if (_discoveryLoadMoreError != null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: phone ? 14 : 18),
        child: Center(
          child: FilledButton.tonalIcon(
            onPressed: _loadMoreDiscoveryRecommendations,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('\u91cd\u8bd5'),
          ),
        ),
      );
    }

    if (_isDiscoveryLoadingMore) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: phone ? 18 : 24),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }

    if (!_hasMoreDiscovery) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: phone ? 18 : 24),
        child: const Center(
          child: Text(
            '\u6682\u65f6\u6ca1\u6709\u66f4\u591a\u4e86',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
      );
    }

    return SizedBox(height: phone ? 44 : 56);
  }

  Widget _surface(
    Widget child, {
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E5EA)),
      ),
      child: child,
    );
  }

  Widget _field(String label, Widget child, {IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterSectionTitle(icon: icon, label: label),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _dateButton(
    String label,
    DateTime? value,
    VoidCallback onTap,
    VoidCallback onClear, {
    required bool phone,
  }) {
    final text = value == null
        ? '未设置'
        : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onTap,
      child: Ink(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: phone ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE1E5EA)),
        ),
        child: Row(
          children: [
            Expanded(child: Text('$label: $text')),
            if (value != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            const Icon(Icons.calendar_today_outlined, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE1E5EA)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _squareIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE8F5FF) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color:
                    active ? const Color(0xFF8CCBFF) : const Color(0xFFE1E5EA)),
          ),
          child: Icon(icon,
              size: 18, color: active ? const Color(0xFF0077C8) : null),
        ),
      ),
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  final IconData? icon;
  final String label;

  const _FilterSectionTitle({this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}

class _AuthorBrowserHint extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _AuthorBrowserHint({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
