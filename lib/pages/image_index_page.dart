import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tagselector/components/image_with_info.dart';
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
  final _criteria = SearchCriteria();
  final _scrollController = ScrollController();
  final _authorNameController = TextEditingController();
  final _authorUidController = TextEditingController();
  final _pidController = TextEditingController();
  final _minLikesController = TextEditingController();
  final _maxLikesController = TextEditingController();
  final _pageSizeController = TextEditingController(text: '24');

  late Future<List<String>> _tagSuggestionsFuture;
  Future<PagedImagesResponse>? _resultsFuture;
  Timer? _debounceTimer;
  List<SearchPreset> _presets = const [];
  final Map<int, ImageModel> _imageOverrides = <int, ImageModel>{};
  final List<ImageModel> _discoveryImages = <ImageModel>[];
  final Set<int> _discoverySeenPids = <int>{};
  final ImagePrefetcher _prefetcher = ImagePrefetcher.instance;
  DisplayMode _displayMode = DisplayMode.list;
  bool _showingDiscovery = false;
  bool _isDiscoveryLoadingMore = false;
  bool _hasMoreDiscovery = true;
  Object? _discoveryLoadMoreError;
  int _discoveryRequestId = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _tagSuggestionsFuture = _api.fetchTagSuggestions();
    _loadPresets();
    _loadDiscoveryRecommendations();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.dispose();
    _authorNameController.dispose();
    _authorUidController.dispose();
    _pidController.dispose();
    _minLikesController.dispose();
    _maxLikesController.dispose();
    _pageSizeController.dispose();
    super.dispose();
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
    _discoverySeenPids.clear();
    _hasMoreDiscovery = true;
    _isDiscoveryLoadingMore = false;
    _discoveryLoadMoreError = null;
    setState(() {
      _showingDiscovery = false;
      _resultsFuture = _api.searchImages(_criteria);
    });
  }

  void _refreshVisibleResults() {
    if (_showingDiscovery) {
      _loadDiscoveryRecommendations();
      return;
    }
    _refreshResults();
  }

  void _loadDiscoveryRecommendations({bool resetPage = true}) {
    _applyFormFilters();
    final pageSize = _criteria.pageSize <= 0 ? 30 : _criteria.pageSize;
    final limit = pageSize.clamp(1, 60).toInt();
    final requestId = ++_discoveryRequestId;
    if (resetPage) {
      _criteria.page = 1;
      _discoveryImages.clear();
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
    final recommendations = await _api.fetchDiscoveryRecommendations(
      limit: limit,
      seenPids: _discoverySeenPids.take(300),
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
    _prefetcher.prefetchImageModels(
      images.take(8),
      highQuality: true,
      limit: 8,
    );
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
      _imageOverrides[image.pid] = image;
    });
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
    final end = (index + 13).clamp(0, images.length);
    if (start >= end) return;
    _prefetcher.prefetchImageModels(
      images.sublist(start, end),
      highQuality: true,
      limit: _showingDiscovery ? 6 : 8,
    );
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
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.82,
            child: MobileSheetSection(
              child: _buildSidebarContent(phone: true, sheet: true),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PagedImagesResponse>(
      future: _resultsFuture,
      builder: (context, snapshot) {
        final images = (snapshot.data?.images ?? const <ImageModel>[])
            .map((image) => _imageOverrides[image.pid] ?? image)
            .toList();
        final total = snapshot.data?.total ?? 0;
        final totalPages = _showingDiscovery
            ? null
            : total == 0
                ? 1
                : ((total - 1) ~/ _criteria.pageSize) + 1;

        _prefetcher.prefetchImageModels(
          images.take(_showingDiscovery ? 8 : 12),
          highQuality: true,
          limit: _showingDiscovery ? 8 : 12,
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final showSidebar = constraints.maxWidth >= 1180;
            final phone = constraints.maxWidth < 720;

            final content = Column(
              children: [
                MobileScrollHideToolbar(
                  enabled: phone,
                  scrollController: _scrollController,
                  height: phone ? 112 : 50,
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
      final chips = <Widget>[
        MobilePill(
          icon: Icons.auto_awesome_rounded,
          label: '发现',
          selected: _showingDiscovery,
          onTap: _loadDiscoveryRecommendations,
        ),
        MobilePill(label: _showingDiscovery ? '推荐 $total' : '作品 $total'),
        for (final option in _sortOptions)
          MobilePill(
            label: option.$2,
            selected: _criteria.sortBy == option.$1,
            onTap: () {
              setState(() => _criteria.sortBy = option.$1);
              _scheduleRefresh();
            },
          ),
        for (final tag in _criteria.tags)
          MobilePill(
            label: '#$tag',
            selected: true,
            onTap: () => _toggleIncludeTag(tag),
          ),
        for (final tag in _criteria.excludedTags)
          MobilePill(
            label: '-$tag',
            selected: true,
            accent: const Color(0xFFE11D48),
            onTap: () => _toggleExcludeTag(tag),
          ),
      ];

      return MobileToolbar(
        topCenter: const MobileBrandMark(label: 'Pixiv'),
        actions: [
          MobilePill(
            icon: Icons.tune_rounded,
            label: _activeFilterCount > 0 ? '筛选 $_activeFilterCount' : '筛选',
            selected: _activeFilterCount > 0,
            onTap: _openFilterSheet,
          ),
          MobileIconButton(
            icon: Icons.refresh_rounded,
            tooltip: '刷新',
            onTap: _refreshVisibleResults,
          ),
        ],
        chips: chips,
        bottom: MobileToolbarRow(
          children: [
            MobileSegmentedControl<DisplayMode>(
              selected: _displayMode,
              segments: const [
                MobileSegment(
                  value: DisplayMode.list,
                  label: '列表',
                  icon: Icons.view_agenda_rounded,
                ),
                MobileSegment(
                  value: DisplayMode.grid,
                  label: '网格',
                  icon: Icons.grid_view_rounded,
                ),
              ],
              onChanged: (mode) {
                setState(() => _displayMode = mode);
              },
            ),
            MobilePill(
              icon: Icons.close_rounded,
              label: '清空',
              onTap: _clearAllFilters,
            ),
          ],
        ),
      );
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _metaChip('$total 项'),
            for (final option in _sortOptions)
              ChoiceChip(
                label: Text(option.$2),
                selected: _criteria.sortBy == option.$1,
                onSelected: (_) {
                  setState(() => _criteria.sortBy = option.$1);
                  _scheduleRefresh();
                },
                visualDensity: VisualDensity.compact,
              ),
            modeSelector,
            if (compact)
              _flatActionButton(
                icon: Icons.tune_rounded,
                label: _activeFilterCount > 0 ? '筛选 $_activeFilterCount' : '筛选',
                onTap: _openFilterSheet,
              ),
            _squareIconButton(
              icon: Icons.refresh_rounded,
              onTap: _refreshVisibleResults,
            ),
            _flatActionButton(
              icon: Icons.auto_awesome_rounded,
              label: _showingDiscovery ? '推荐中' : '随机推荐',
              onTap: _loadDiscoveryRecommendations,
            ),
            TextButton(
              onPressed: _clearAllFilters,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('清空'),
            ),
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
  }) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '专业筛选',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            if (_activeFilterCount > 0) _metaChip('$_activeFilterCount 个条件'),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<String>>(
          future: _tagSuggestionsFuture,
          builder: (context, snapshot) => SearchTool(
            suggestions: snapshot.data ?? const [],
            onInclude: _toggleIncludeTag,
            onExclude: _toggleExcludeTag,
          ),
        ),
        const SizedBox(height: 16),
        _field(
          '作者名',
          TextField(
            controller: _authorNameController,
            decoration: const InputDecoration(hintText: '支持精确过滤'),
            onSubmitted: (_) => _refreshResults(),
          ),
        ),
        const SizedBox(height: 8),
        _field(
          '作者 UID',
          TextField(
            controller: _authorUidController,
            decoration: const InputDecoration(hintText: '例如 810305'),
            onSubmitted: (_) => _refreshResults(),
          ),
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
        ),
        const SizedBox(height: 12),
        const Text(
          '收藏区间',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
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
        const Text(
          '发布时间',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
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
        const Text(
          '收藏状态',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
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
                  onPressed: () => _applyPreset(preset),
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
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError && images.isEmpty) {
      return Center(child: Text('加载失败：${snapshot.error}'));
    }
    if (images.isEmpty) {
      return const Center(child: Text('没有结果，可以减少筛选条件后再试。'));
    }

    if (_displayMode == DisplayMode.list) {
      final itemCount = images.length + (_showingDiscovery ? 1 : 0);
      return ListView.builder(
        controller: _scrollController,
        cacheExtent: phone ? 1400 : 900,
        padding: EdgeInsets.fromLTRB(phone ? 0 : 8, 0, phone ? 0 : 8, 0),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= images.length) {
            return _buildDiscoveryFooter(phone: phone);
          }
          if (index % 3 == 0) {
            _prefetchAround(images, index);
          }
          final image = images[index];
          return ImageWithInfo(
            image: image,
            selectedTags: _criteria.tags,
            onSelectedTagsChanged: _toggleIncludeTag,
            onSelectedAuthor: _toggleAuthor,
            onImageChanged: _updateImage,
            onAuthorTap: () => _openAuthorPage(image.author),
            onImageTap: () => _openImagePage(image),
            highQualityPreview: true,
            showBookmarkCount: !_showingDiscovery,
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            phone ? 176.0 : (constraints.maxWidth < 520 ? 164.0 : 220.0);
        final rawCount = (constraints.maxWidth / tileWidth).floor();
        final count = rawCount.clamp(phone ? 2 : 1, 6).toInt();
        final itemCount = images.length + (_showingDiscovery ? 1 : 0);
        return MasonryGridView.count(
          controller: _scrollController,
          cacheExtent: phone ? 1200 : 900,
          padding: EdgeInsets.fromLTRB(phone ? 0 : 8, 0, phone ? 0 : 8, 0),
          crossAxisCount: count,
          crossAxisSpacing: phone ? 2 : 10,
          mainAxisSpacing: phone ? 2 : 10,
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index >= images.length) {
              return _buildDiscoveryFooter(phone: phone);
            }
            if (index % 6 == 0) {
              _prefetchAround(images, index);
            }
            final image = images[index];
            return MasonryImageTile(
              image: image,
              highQualityPreview: !phone,
              showBookmarkCount: !_showingDiscovery,
              onImageChanged: _updateImage,
              onTap: () => _openImagePage(image),
              onAuthorTap: () => _openAuthorPage(image.author),
            );
          },
        );
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }

  Widget _field(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
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
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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

  Widget _flatActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
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

  Widget _squareIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
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
