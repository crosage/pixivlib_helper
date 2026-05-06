import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tagselector/components/download_progress_sheet.dart';
import 'package:tagselector/components/like_recommendation_sheet.dart';
import 'package:tagselector/model/author_model.dart';
import 'package:tagselector/model/image_model.dart';
import 'package:tagselector/model/image_recommendation_model.dart';
import 'package:tagselector/pages/author_page.dart';
import 'package:tagselector/service/api_service.dart';
import 'package:tagselector/service/artwork_download_manager.dart';
import 'package:tagselector/service/cache_proxy_manager.dart';
import 'package:tagselector/service/native_image_clipboard.dart';
import 'package:tagselector/service/remote_image_url.dart';
import 'package:tagselector/utils.dart';
import 'package:url_launcher/url_launcher.dart';

class FullImagePage extends StatefulWidget {
  final ImageModel image;

  const FullImagePage({
    super.key,
    required this.image,
  });

  @override
  State<FullImagePage> createState() => _FullImagePageState();
}

enum _ArtworkCopyAction {
  image,
}

class _FullImagePageState extends State<FullImagePage> {
  static const int _bookmarkTrayRecommendationCount = 6;

  final ApiService _api = ApiService.instance;

  late ImageModel _image;
  List<ImageRecommendationModel> _recommendations = const [];
  int _currentPageIndex = 0;
  bool _imageInteractionEnabled = false;
  bool _isDetailLoading = true;
  bool _isRecommendationLoading = true;
  bool _isBookmarkSubmitting = false;
  bool _isImageCopying = false;
  bool _isOriginDownloadStarting = false;
  Object? _detailError;
  Object? _recommendationError;

  @override
  void initState() {
    super.initState();
    _image = widget.image;
    _loadPage();
  }

  Future<void> _loadPage({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _isDetailLoading = true;
        _isRecommendationLoading = true;
        _detailError = null;
        _recommendationError = null;
      });
    }

    await Future.wait([
      _loadDetail(),
      _loadRecommendations(),
    ]);
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await _api.fetchImageDetail(_image.pid);
      if (!mounted) return;
      setState(() {
        _image = detail;
        final maxIndex = math.max(0, detail.pages.length - 1);
        _currentPageIndex = _currentPageIndex.clamp(0, maxIndex);
        _isDetailLoading = false;
        _detailError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isDetailLoading = false;
        _detailError = error;
      });
    }
  }

  Future<void> _loadRecommendations() async {
    try {
      final recommendations = await _api.fetchImageRecommendations(_image.pid);
      if (!mounted) return;
      setState(() {
        _recommendations = recommendations;
        _isRecommendationLoading = false;
        _recommendationError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRecommendationLoading = false;
        _recommendationError = error;
      });
    }
  }

  Future<void> _openAuthorPage(Author author) async {
    if (author.uid.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AuthorPage(author: author)),
    );
  }

  Future<void> _openPixivArtwork() async {
    final uri = Uri.parse('https://www.pixiv.net/artworks/${_image.pid}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _copyCurrentImage(String imageUrl) async {
    if (imageUrl.isEmpty || _isImageCopying) {
      return;
    }

    setState(() => _isImageCopying = true);
    try {
      await NativeImageClipboard.copyNetworkImage(imageUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前图片已复制到剪贴板')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('复制图片失败: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isImageCopying = false);
      }
    }
  }

  Future<void> _downloadOriginalArtwork() async {
    if (_isOriginDownloadStarting) {
      return;
    }

    setState(() => _isOriginDownloadStarting = true);
    try {
      var image = _image;
      if (image.urls.original.isEmpty) {
        image = await _api.fetchImageDetail(_image.pid);
        if (!mounted) return;
        setState(() {
          _image = image;
          final maxIndex = math.max(0, image.pages.length - 1);
          _currentPageIndex = _currentPageIndex.clamp(0, maxIndex);
        });
      }

      final pageCount = image.pages.isEmpty ? 1 : image.pages.length;
      final batchFuture =
          ArtworkDownloadManager.instance.downloadOriginalArtwork(image);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已开始保存 origin，共 $pageCount 张'),
          action: SnackBarAction(
            label: '进度',
            onPressed: () => showDownloadProgressSheet(context),
          ),
        ),
      );

      final batch = await batchFuture;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            batch.hasFailed
                ? '保存完成：${batch.completedCount}/${batch.tasks.length} 张成功'
                : '已保存 ${batch.tasks.length} 张 origin 图片到 Pictures/PixivHelper',
          ),
          action: SnackBarAction(
            label: '进度',
            onPressed: () => showDownloadProgressSheet(context),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存 origin 失败: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isOriginDownloadStarting = false);
      }
    }
  }

  Future<void> _showArtworkContextMenu(
    TapDownDetails details,
    String imageUrl,
  ) async {
    final overlay = Overlay.maybeOf(context);
    final overlaySize = overlay?.context.size;
    if (overlay == null || overlaySize == null) {
      return;
    }

    final action = await showMenu<_ArtworkCopyAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
          details.globalPosition.dx,
          details.globalPosition.dy,
          1,
          1,
        ),
        Offset.zero & overlaySize,
      ),
      items: [
        if (imageUrl.isNotEmpty)
          const PopupMenuItem(
            value: _ArtworkCopyAction.image,
            child: Text('复制当前图片'),
          ),
      ],
    );

    if (action == null || !mounted) {
      return;
    }

    if (action == _ArtworkCopyAction.image) {
      await _copyCurrentImage(imageUrl);
      return;
    }
  }

  Future<void> _toggleBookmark() async {
    if (_isBookmarkSubmitting) return;

    final wasBookmarked = _image.isBookmarked;
    setState(() => _isBookmarkSubmitting = true);

    try {
      final updatedImage = wasBookmarked
          ? await _api.unbookmarkImage(_image.pid)
          : await _api.bookmarkImage(_image.pid);
      if (!mounted) return;
      setState(() {
        _image = updatedImage;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(updatedImage.isBookmarked ? '已收藏作品' : '已取消收藏'),
        ),
      );

      if (!wasBookmarked && updatedImage.isBookmarked) {
        unawaited(_loadRecommendations());
        showBookmarkRecommendationTray(
          context,
          seedImage: updatedImage,
          limit: _bookmarkTrayRecommendationCount,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('收藏操作失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isBookmarkSubmitting = false);
      }
    }
  }

  Future<void> _openRecommended(ImageRecommendationModel recommendation) async {
    final selectedTag = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            FullImagePage(image: recommendation.toPlaceholderImage()),
      ),
    );
    if (!mounted || selectedTag == null || selectedTag.isEmpty) {
      return;
    }
    Navigator.of(context).pop(selectedTag);
  }

  void _selectTagAndClose(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) {
      return;
    }
    Navigator.of(context).pop(trimmed);
  }

  void _setImageInteractionEnabled(bool enabled) {
    if (_imageInteractionEnabled == enabled) return;
    setState(() {
      _imageInteractionEnabled = enabled;
    });
  }

  int get _pageCount => _image.pages.isEmpty ? 1 : _image.pages.length;

  bool get _hasPreviousPage => _pageCount > 1 && _currentPageIndex > 0;

  bool get _hasNextPage => _pageCount > 1 && _currentPageIndex < _pageCount - 1;

  String _resolveCurrentImageUrl({required bool fullQuality}) {
    final pageID =
        _image.pages.isEmpty ? 0 : _image.pages[_currentPageIndex].pageId;
    return _resolveImageUrlForPage(pageID, fullQuality: fullQuality);
  }

  String _resolveImageUrlForPage(int pageID, {bool fullQuality = true}) {
    final candidates = fullQuality
        ? [
            _image.urls.original,
            _image.urls.regular,
            _image.urls.small,
            _image.urls.thumb,
            _image.urls.mini,
          ]
        : [
            _image.urls.regular,
            _image.urls.small,
            _image.urls.thumb,
            _image.urls.mini,
          ];

    for (final candidate in candidates) {
      final resolved = _swapPixivPageSuffix(candidate, pageID);
      if (resolved.isNotEmpty) {
        return resolved;
      }
    }
    return '';
  }

  String _swapPixivPageSuffix(String url, int pageID) {
    if (url.isEmpty) {
      return '';
    }
    final matcher = RegExp(r'_p\d+');
    if (matcher.hasMatch(url)) {
      return url.replaceFirst(matcher, '_p$pageID');
    }
    return url;
  }

  void _showPreviousPage() {
    if (!_hasPreviousPage) {
      return;
    }
    setState(() {
      _currentPageIndex -= 1;
    });
  }

  void _showNextPage() {
    if (!_hasNextPage) {
      return;
    }
    setState(() {
      _currentPageIndex += 1;
    });
  }

  void _handleArtworkHorizontalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 260) {
      return;
    }
    if (velocity < 0) {
      _showNextPage();
    } else {
      _showPreviousPage();
    }
  }

  ButtonStyle _compactButtonStyle() {
    return const ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: WidgetStatePropertyAll(Size(0, 30)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      ),
      textStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final publishedAt = formatUnixTimestamp(_image.publishedAt);
    final updatedAt = formatUnixTimestamp(_image.updatedAt);
    final hasMultiplePages = _pageCount > 1;
    final screenSize = MediaQuery.sizeOf(context);
    final narrow = screenSize.width < 720;
    final imageUrl = _resolveCurrentImageUrl(fullQuality: !narrow);
    final imageViewportHeight = (screenSize.height * (narrow ? 0.56 : 0.72))
        .clamp(narrow ? 260.0 : 360.0, narrow ? 520.0 : 820.0)
        .toDouble();

    return Scaffold(
      backgroundColor: narrow ? Colors.white : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: narrow ? 44 : null,
        title: narrow
            ? null
            : Text(
                _image.name.isEmpty ? '作品详情' : _image.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          IconButton(
            onPressed: () => showDownloadProgressSheet(context),
            icon: const Icon(Icons.downloading_rounded),
            tooltip: '下载进度',
          ),
          IconButton(
            onPressed: _goHome,
            icon: const Icon(Icons.home_rounded),
            tooltip: '回到首页',
          ),
          IconButton(
            onPressed: () => _loadPage(showLoading: true),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新详情',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(narrow ? 0 : 16),
            child: narrow
                ? _buildMobileContent(
                    imageUrl: imageUrl,
                    publishedAt: publishedAt,
                    updatedAt: updatedAt,
                    hasMultiplePages: hasMultiplePages,
                    imageViewportHeight: imageViewportHeight,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_detailError != null) ...[
                        _StatusBanner(
                          text: '详情刷新失败，先展示当前内容。${_detailError.toString()}',
                          icon: Icons.cloud_off_rounded,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _Surface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _openAuthorPage(_image.author),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Row(
                                      children: [
                                        _AuthorAvatar(author: _image.author),
                                        SizedBox(width: narrow ? 8 : 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _image.author.name.isEmpty
                                                    ? '未知作者'
                                                    : _image.author.name,
                                                style: TextStyle(
                                                  fontSize: narrow ? 13 : 16,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      const Color(0xFF243B53),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _image.author.uid.isEmpty
                                                    ? '未记录 UID'
                                                    : 'UID ${_image.author.uid}',
                                                style: TextStyle(
                                                  fontSize: narrow ? 10 : 12,
                                                  color:
                                                      const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: narrow ? 6 : 10),
                                Wrap(
                                  spacing: narrow ? 4 : 8,
                                  runSpacing: narrow ? 4 : 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _openAuthorPage(_image.author),
                                      style:
                                          narrow ? _compactButtonStyle() : null,
                                      icon: Icon(
                                        Icons.person_outline_rounded,
                                        size: narrow ? 15 : 18,
                                      ),
                                      label: const Text('作者页'),
                                    ),
                                    FilledButton.tonalIcon(
                                      onPressed: _openPixivArtwork,
                                      style:
                                          narrow ? _compactButtonStyle() : null,
                                      icon: Icon(
                                        Icons.open_in_new_rounded,
                                        size: narrow ? 15 : 18,
                                      ),
                                      label: const Text('Pixiv'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: narrow ? 6 : 10),
                            Text(
                              _image.name.isEmpty ? '未命名作品' : _image.name,
                              maxLines: narrow ? 2 : null,
                              overflow: narrow ? TextOverflow.ellipsis : null,
                              style: TextStyle(
                                fontSize: narrow ? 16 : 21,
                                height: narrow ? 1.2 : null,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF243B53),
                              ),
                            ),
                            SizedBox(height: narrow ? 6 : 10),
                            if (!narrow)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _MetaChip(label: 'PID ${_image.pid}'),
                                  _MetaChip(
                                      label: '收藏 ${_image.bookmarkCount}'),
                                  if (publishedAt.isNotEmpty)
                                    _MetaChip(label: '上传 $publishedAt')
                                  else if (updatedAt.isNotEmpty)
                                    _MetaChip(label: '更新 $updatedAt'),
                                  if (hasMultiplePages)
                                    _MetaChip(
                                        label: '${_image.pages.length} 页'),
                                  if (_image.isBookmarked)
                                    const _MetaChip(label: '已收藏'),
                                ],
                              ),
                            SizedBox(height: narrow ? 6 : 10),
                            Wrap(
                              spacing: narrow ? 6 : 8,
                              runSpacing: narrow ? 6 : 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: _isBookmarkSubmitting
                                      ? null
                                      : _toggleBookmark,
                                  style: narrow ? _compactButtonStyle() : null,
                                  icon: Icon(
                                    _image.isBookmarked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: narrow ? 15 : 18,
                                  ),
                                  label: Text(
                                      _image.isBookmarked ? '取消收藏' : '收藏作品'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _openPixivArtwork,
                                  style: narrow ? _compactButtonStyle() : null,
                                  icon: Icon(
                                    Icons.travel_explore_rounded,
                                    size: narrow ? 15 : 18,
                                  ),
                                  label: const Text('打开作品页'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: narrow ? 6 : 14),
                      _Surface(
                        padding: EdgeInsets.all(narrow ? 6 : 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!narrow)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: () =>
                                        _setImageInteractionEnabled(
                                      !_imageInteractionEnabled,
                                    ),
                                    icon: Icon(
                                      _imageInteractionEnabled
                                          ? Icons.close_fullscreen_rounded
                                          : Icons.open_in_full_rounded,
                                    ),
                                    label: Text(
                                      _imageInteractionEnabled
                                          ? '退出缩放模式'
                                          : '启用缩放模式',
                                    ),
                                  ),
                                  if (!_imageInteractionEnabled)
                                    const _ImageModeHint(
                                      label: '当前滚轮只滚动页面',
                                      icon: Icons.mouse_rounded,
                                    ),
                                ],
                              ),
                            if (hasMultiplePages) ...[
                              if (!narrow) const SizedBox(height: 10),
                              Wrap(
                                spacing: narrow ? 6 : 8,
                                runSpacing: narrow ? 6 : 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: _hasPreviousPage
                                        ? _showPreviousPage
                                        : null,
                                    style:
                                        narrow ? _compactButtonStyle() : null,
                                    icon: Icon(
                                      Icons.chevron_left_rounded,
                                      size: narrow ? 16 : 18,
                                    ),
                                    label: const Text('上一张'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: null,
                                    style:
                                        narrow ? _compactButtonStyle() : null,
                                    icon: Icon(
                                      Icons.collections_outlined,
                                      size: narrow ? 15 : 18,
                                    ),
                                    label: Text(
                                        '第 ${_currentPageIndex + 1} / $_pageCount 张'),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed:
                                        _hasNextPage ? _showNextPage : null,
                                    style:
                                        narrow ? _compactButtonStyle() : null,
                                    icon: Icon(
                                      Icons.chevron_right_rounded,
                                      size: narrow ? 16 : 18,
                                    ),
                                    label: const Text('下一张'),
                                  ),
                                ],
                              ),
                            ],
                            SizedBox(height: narrow ? 6 : 10),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onLongPress: _downloadOriginalArtwork,
                              onHorizontalDragEnd: !_imageInteractionEnabled
                                  ? _handleArtworkHorizontalSwipe
                                  : null,
                              onSecondaryTapDown: (details) =>
                                  _showArtworkContextMenu(details, imageUrl),
                              child: SizedBox(
                                width: double.infinity,
                                height: imageViewportHeight,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: ColoredBox(
                                        color: Colors.white,
                                        child: narrow
                                            ? _ArtworkImage(imageUrl: imageUrl)
                                            : _imageInteractionEnabled
                                                ? InteractiveViewer(
                                                    minScale: 0.7,
                                                    maxScale: 5,
                                                    trackpadScrollCausesScale:
                                                        false,
                                                    child: _ArtworkImage(
                                                      imageUrl: imageUrl,
                                                    ),
                                                  )
                                                : InkWell(
                                                    onTap: () =>
                                                        _setImageInteractionEnabled(
                                                      true,
                                                    ),
                                                    child: _ArtworkImage(
                                                      imageUrl: imageUrl,
                                                    ),
                                                  ),
                                      ),
                                    ),
                                    if (hasMultiplePages)
                                      Positioned(
                                        right: 12,
                                        bottom: 12,
                                        child: _MobileImageCounter(
                                          text:
                                              '${_currentPageIndex + 1} / $_pageCount',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (hasMultiplePages) ...[
                              SizedBox(height: narrow ? 6 : 10),
                              SizedBox(
                                height: narrow ? 62 : 82,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _pageCount,
                                  separatorBuilder: (_, __) =>
                                      SizedBox(width: narrow ? 6 : 10),
                                  itemBuilder: (context, index) {
                                    final pageUrl =
                                        _resolveImageUrlForPage(index);
                                    return _PageThumbnail(
                                      imageUrl: pageUrl,
                                      label: '${index + 1}',
                                      selected: index == _currentPageIndex,
                                      onTap: () {
                                        setState(() {
                                          _currentPageIndex = index;
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: narrow ? 6 : 14),
                      _Surface(
                        child: _Section(
                          title: '标签',
                          trailing: Text('${_image.tags.length} 项'),
                          child: _image.tags.isEmpty
                              ? Text(
                                  '这张图当前没有记录标签。',
                                  style:
                                      TextStyle(fontSize: narrow ? 12 : null),
                                )
                              : Wrap(
                                  spacing: narrow ? 6 : 8,
                                  runSpacing: narrow ? 6 : 8,
                                  children: _image.tags.map((tag) {
                                    final text = tag.translateName.isEmpty
                                        ? tag.name
                                        : '${tag.name} · ${tag.translateName}';
                                    return ActionChip(
                                      visualDensity: narrow
                                          ? VisualDensity.compact
                                          : VisualDensity.standard,
                                      materialTapTargetSize: narrow
                                          ? MaterialTapTargetSize.shrinkWrap
                                          : MaterialTapTargetSize.padded,
                                      label: Text(text),
                                      avatar: Icon(
                                        Icons.filter_alt_rounded,
                                        size: narrow ? 14 : 16,
                                        color: const Color(0xFF2563EB),
                                      ),
                                      onPressed: () =>
                                          _selectTagAndClose(tag.name),
                                      backgroundColor: const Color(0xFFEFF6FF),
                                      side: const BorderSide(
                                        color: Color(0xFFBFDBFE),
                                      ),
                                      labelStyle: TextStyle(
                                        fontSize: narrow ? 11 : 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF1D4ED8),
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                      ),
                      SizedBox(height: narrow ? 6 : 14),
                      _Surface(
                        child: _Section(
                          title: '相关推荐',
                          trailing: Text(
                            _isRecommendationLoading
                                ? '加载中'
                                : '${_recommendations.length} 项',
                          ),
                          child: _buildRecommendations(),
                        ),
                      ),
                    ],
                  ),
          ),
          if (_isDetailLoading)
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

  Widget _buildMobileContent({
    required String imageUrl,
    required String publishedAt,
    required String updatedAt,
    required bool hasMultiplePages,
    required double imageViewportHeight,
  }) {
    final dateLabel = publishedAt.isNotEmpty
        ? publishedAt
        : updatedAt.isNotEmpty
            ? updatedAt
            : '';

    return ColoredBox(
      color: const Color(0xFFF2F2F7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_detailError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: _StatusBanner(
                text: '详情刷新失败，先展示当前内容。${_detailError.toString()}',
                icon: Icons.cloud_off_rounded,
              ),
            ),
          _MobileArtworkStage(
            imageUrl: imageUrl,
            height: imageViewportHeight,
            hasMultiplePages: hasMultiplePages,
            currentPageIndex: _currentPageIndex,
            pageCount: _pageCount,
            onHorizontalSwipe: _handleArtworkHorizontalSwipe,
            onLongPress: _downloadOriginalArtwork,
            onSecondaryTapDown: (details) =>
                _showArtworkContextMenu(details, imageUrl),
          ),
          if (hasMultiplePages)
            _MobilePageStrip(
              pageCount: _pageCount,
              currentPageIndex: _currentPageIndex,
              resolveImageUrl: (index) =>
                  _resolveImageUrlForPage(index, fullQuality: false),
              onSelect: (index) {
                setState(() {
                  _currentPageIndex = index;
                });
              },
            ),
          _MobileGroupedCard(
            margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _openAuthorPage(_image.author),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        _AuthorAvatar(author: _image.author),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _image.author.name.isEmpty
                                    ? '未知作者'
                                    : _image.author.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dateLabel.isEmpty ? 'Pixiv artwork' : dateLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF8E8E93),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 22,
                          color: Color(0xFFC7C7CC),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _image.name.isEmpty ? '未命名作品' : _image.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MobileInfoPill(
                      icon: Icons.favorite_rounded,
                      label: '${_image.bookmarkCount}',
                    ),
                    if (hasMultiplePages)
                      _MobileInfoPill(
                        icon: Icons.collections_rounded,
                        label: '$_pageCount P',
                      ),
                    if (_image.isBookmarked)
                      const _MobileInfoPill(
                        icon: Icons.bookmark_rounded,
                        label: '已收藏',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MobileActionPill(
                        icon: _image.isBookmarked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        label: _image.isBookmarked ? '取消收藏' : '收藏',
                        selected: _image.isBookmarked,
                        onTap: _isBookmarkSubmitting ? null : _toggleBookmark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MobileActionPill(
                        icon: Icons.open_in_new_rounded,
                        label: 'Pixiv',
                        onTap: _openPixivArtwork,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _MobileGroupedCard(
            margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
            child: _MobileSectionBlock(
              title: 'Tags',
              trailing: '${_image.tags.length}',
              child: _image.tags.isEmpty
                  ? const Text(
                      '这张图当前没有记录标签。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8E8E93),
                      ),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _image.tags.map((tag) {
                        final text = tag.translateName.isEmpty
                            ? tag.name
                            : '${tag.name} · ${tag.translateName}';
                        return _MobileTagChip(
                          label: text,
                          onTap: () => _selectTagAndClose(tag.name),
                        );
                      }).toList(),
                    ),
            ),
          ),
          _MobileGroupedCard(
            margin: const EdgeInsets.fromLTRB(10, 10, 10, 14),
            padding: const EdgeInsets.fromLTRB(10, 11, 10, 10),
            child: _MobileSectionBlock(
              title: '相关推荐',
              trailing: _isRecommendationLoading
                  ? '加载中'
                  : '${_recommendations.length}',
              child: _buildRecommendations(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    if (_isRecommendationLoading) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final narrow = MediaQuery.sizeOf(context).width < 720;
          final count = (constraints.maxWidth / (narrow ? 150 : 220))
              .floor()
              .clamp(1, 5)
              .toInt();
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: count * 2,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: count,
              crossAxisSpacing: narrow ? 6 : 12,
              mainAxisSpacing: narrow ? 8 : 12,
              childAspectRatio: narrow ? 0.86 : 0.82,
            ),
            itemBuilder: (_, __) => const _RecommendationPlaceholder(),
          );
        },
      );
    }

    if (_recommendationError != null) {
      return Text('相关推荐加载失败：${_recommendationError.toString()}');
    }

    if (_recommendations.isEmpty) {
      return const Text('Pixiv 当前没有返回相关推荐。');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = MediaQuery.sizeOf(context).width < 720;
        final count = (constraints.maxWidth / (narrow ? 150 : 220))
            .floor()
            .clamp(1, 5)
            .toInt();
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recommendations.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: narrow ? 6 : 12,
            mainAxisSpacing: narrow ? 8 : 12,
            childAspectRatio: narrow ? 0.86 : 0.82,
          ),
          itemBuilder: (context, index) {
            final recommendation = _recommendations[index];
            return _RecommendationTile(
              recommendation: recommendation,
              onTap: () => _openRecommended(recommendation),
              onAuthorTap: () => _openAuthorPage(recommendation.author),
            );
          },
        );
      },
    );
  }
}

class _ArtworkImage extends StatelessWidget {
  final String imageUrl;

  const _ArtworkImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CachedNetworkImage(
        cacheManager: imageProxyCacheManager,
        imageUrl: proxiedImageUrl(imageUrl),
        fit: BoxFit.contain,
        placeholder: (_, __) => const _ImageLoadingPlaceholder(),
        errorWidget: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image_outlined, size: 42)),
      ),
    );
  }
}

class _MobileArtworkStage extends StatelessWidget {
  final String imageUrl;
  final double height;
  final bool hasMultiplePages;
  final int currentPageIndex;
  final int pageCount;
  final GestureDragEndCallback onHorizontalSwipe;
  final VoidCallback onLongPress;
  final GestureTapDownCallback onSecondaryTapDown;

  const _MobileArtworkStage({
    required this.imageUrl,
    required this.height,
    required this.hasMultiplePages,
    required this.currentPageIndex,
    required this.pageCount,
    required this.onHorizontalSwipe,
    required this.onLongPress,
    required this.onSecondaryTapDown,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      onHorizontalDragEnd: onHorizontalSwipe,
      onSecondaryTapDown: onSecondaryTapDown,
      child: Container(
        height: height,
        width: double.infinity,
        color: Colors.white,
        child: Stack(
          children: [
            Positioned.fill(
              child: _ArtworkImage(imageUrl: imageUrl),
            ),
            if (hasMultiplePages) ...[
              Positioned(
                right: 12,
                bottom: 12,
                child: _MobileImageCounter(
                  text: '${currentPageIndex + 1} / $pageCount',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MobileImageCounter extends StatelessWidget {
  final String text;

  const _MobileImageCounter({required this.text});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xBF111827),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MobilePageStrip extends StatelessWidget {
  final int pageCount;
  final int currentPageIndex;
  final String Function(int pageID) resolveImageUrl;
  final ValueChanged<int> onSelect;

  const _MobilePageStrip({
    required this.pageCount,
    required this.currentPageIndex,
    required this.resolveImageUrl,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      width: double.infinity,
      color: const Color(0xFFF2F2F7),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pageCount,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          return _MobilePageThumb(
            imageUrl: resolveImageUrl(index),
            label: '${index + 1}',
            selected: index == currentPageIndex,
            onTap: () => onSelect(index),
          );
        },
      ),
    );
  }
}

class _MobilePageThumb extends StatelessWidget {
  final String imageUrl;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MobilePageThumb({
    required this.imageUrl,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF0A84FF) : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0A84FF).withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl.isEmpty
                ? const ColoredBox(
                    color: Color(0xFFE5E5EA),
                    child: Icon(Icons.image_not_supported_outlined, size: 18),
                  )
                : CachedNetworkImage(
                    cacheManager: imageProxyCacheManager,
                    imageUrl: proxiedImageUrl(imageUrl),
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const ColoredBox(color: Color(0xFFE5E5EA)),
                    errorWidget: (_, __, ___) => const ColoredBox(
                      color: Color(0xFFE5E5EA),
                      child: Icon(Icons.broken_image_outlined, size: 18),
                    ),
                  ),
            Positioned(
              left: 5,
              bottom: 5,
              child: _MobileImageCounter(text: label),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileGroupedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  const _MobileGroupedCard({
    required this.child,
    this.margin = const EdgeInsets.fromLTRB(10, 10, 10, 0),
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MobileSectionBlock extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget child;

  const _MobileSectionBlock({
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
                  fontSize: 15,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8E8E93),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _MobileInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MobileInfoPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF6B7280)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _MobileActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final background =
        selected ? const Color(0xFFFFE8EF) : const Color(0xFFF2F2F7);
    final foreground =
        selected ? const Color(0xFFFF2D55) : const Color(0xFF111827);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          height: 42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileTagChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MobileTagChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEAF4FF),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0A63C7),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageThumbnail extends StatelessWidget {
  final String imageUrl;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PageThumbnail({
    required this.imageUrl,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    return SizedBox(
      width: narrow ? 50 : 68,
      child: Material(
        color: selected ? const Color(0xFFF3F8FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(narrow ? 8 : 14),
        clipBehavior: Clip.none,
        child: InkWell(
          borderRadius: BorderRadius.circular(narrow ? 8 : 14),
          onTap: onTap,
          child: Stack(
            children: [
              Positioned.fill(
                child: imageUrl.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFFF1F5F9),
                        child: Center(
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                      )
                    : CachedNetworkImage(
                        cacheManager: imageProxyCacheManager,
                        imageUrl: proxiedImageUrl(imageUrl),
                        fit: BoxFit.cover,
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
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: narrow ? 6 : 8,
                    vertical: narrow ? 3 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xCC0F172A),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: narrow ? 10 : 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (selected)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(narrow ? 8 : 14),
                      border: Border.all(
                        color: const Color(0xFF2563EB),
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final compactPadding = padding == const EdgeInsets.all(14)
        ? const EdgeInsets.fromLTRB(8, 8, 8, 10)
        : padding;
    return Container(
      width: double.infinity,
      padding: narrow ? compactPadding : padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(narrow ? 0 : 20),
        border: narrow ? null : Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _Section({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: narrow ? 14 : 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF243B53),
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        SizedBox(height: narrow ? 8 : 12),
        child,
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: narrow ? 8 : 10,
        vertical: narrow ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: narrow ? 11 : 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF334155),
        ),
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  final Author author;

  const _AuthorAvatar({required this.author});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final radius = narrow ? 15.0 : 20.0;
    if (author.avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(
          proxiedImageUrl(author.avatarUrl),
          cacheManager: imageProxyCacheManager,
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
          fontSize: narrow ? 12 : 16,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1D4ED8),
        ),
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  final ImageRecommendationModel recommendation;
  final VoidCallback onTap;
  final VoidCallback onAuthorTap;

  const _RecommendationTile({
    required this.recommendation,
    required this.onTap,
    required this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    final publishedAt = formatUnixTimestamp(recommendation.publishedAt);
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final radius = BorderRadius.circular(narrow ? 0 : 18);
    return Material(
      color: Colors.white,
      borderRadius: radius,
      clipBehavior: Clip.none,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: recommendation.thumbUrl.isEmpty
                  ? const _ImageLoadingPlaceholder()
                  : CachedNetworkImage(
                      imageUrl: proxiedImageUrl(recommendation.thumbUrl),
                      cacheManager: imageProxyCacheManager,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => const _ImageLoadingPlaceholder(),
                      errorWidget: (_, __, ___) =>
                          const _ImageLoadingPlaceholder(),
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                narrow ? 6 : 12,
                narrow ? 6 : 12,
                narrow ? 6 : 12,
                narrow ? 7 : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recommendation.title.isEmpty
                        ? '未命名作品'
                        : recommendation.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: narrow ? 12 : 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF243B53),
                    ),
                  ),
                  SizedBox(height: narrow ? 5 : 8),
                  InkWell(
                    onTap: onAuthorTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      children: [
                        _AuthorAvatar(author: recommendation.author),
                        SizedBox(width: narrow ? 6 : 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                recommendation.author.name.isEmpty
                                    ? '未知作者'
                                    : recommendation.author.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: narrow ? 10 : 12,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                              SizedBox(height: narrow ? 1 : 2),
                              Text(
                                publishedAt.isEmpty
                                    ? 'PID ${recommendation.pid}'
                                    : publishedAt,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: narrow ? 9 : 11,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _StatusBanner extends StatelessWidget {
  final String text;
  final IconData icon;

  const _StatusBanner({
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF334155)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageLoadingPlaceholder extends StatelessWidget {
  const _ImageLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _ImageModeHint extends StatelessWidget {
  final String label;
  final IconData icon;

  const _ImageModeHint({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationPlaceholder extends StatelessWidget {
  const _RecommendationPlaceholder();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ColoredBox(color: Color(0xFFEFF2F6)),
          ),
          SizedBox(height: 12),
          ColoredBox(
            color: Color(0xFFEFF2F6),
            child: SizedBox(height: 14, width: double.infinity),
          ),
          SizedBox(height: 8),
          ColoredBox(
            color: Color(0xFFEFF2F6),
            child: SizedBox(height: 12, width: 120),
          ),
        ],
      ),
    );
  }
}
