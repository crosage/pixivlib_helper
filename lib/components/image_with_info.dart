import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tagselector/components/app_avatar.dart';
import 'package:tagselector/model/image_model.dart';
import 'package:tagselector/service/api_service.dart';
import 'package:tagselector/service/cache_proxy_manager.dart';
import 'package:tagselector/service/image_prefetcher.dart';
import 'package:tagselector/service/image_state_merger.dart';
import 'package:tagselector/service/remote_image_url.dart';
import 'package:tagselector/utils.dart';

class ImageWithInfo extends StatefulWidget {
  final ImageModel image;
  final List<String> selectedTags;
  final ValueChanged<String> onSelectedTagsChanged;
  final ValueChanged<String> onSelectedAuthor;
  final ValueChanged<ImageModel>? onImageChanged;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onImageTap;
  final bool highQualityPreview;
  final bool showBookmarkCount;
  final ValueChanged<ImageModel>? onImageBookmarked;

  const ImageWithInfo({
    super.key,
    required this.image,
    required this.selectedTags,
    required this.onSelectedTagsChanged,
    required this.onSelectedAuthor,
    this.onImageChanged,
    this.onAuthorTap,
    this.onImageTap,
    this.highQualityPreview = true,
    this.showBookmarkCount = true,
    this.onImageBookmarked,
  });

  @override
  State<ImageWithInfo> createState() => _ImageWithInfoState();
}

class _ImageWithInfoState extends State<ImageWithInfo> {
  final ApiService _api = ApiService.instance;

  late ImageModel _image;
  bool _isBookmarkSubmitting = false;

  @override
  void initState() {
    super.initState();
    _image = widget.image;
  }

  @override
  void didUpdateWidget(covariant ImageWithInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _image = widget.image;
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
      final mergedImage = mergeImageState(_image, updatedImage);
      setState(() => _image = mergedImage);
      widget.onImageChanged?.call(mergedImage);
      if (!wasBookmarked && updatedImage.isBookmarked) {
        widget.onImageBookmarked?.call(mergedImage);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('收藏操作失败: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isBookmarkSubmitting = false);
      }
    }
  }

  void _openTagSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '全部标签',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _image.tags.map((tag) {
                    final selected = widget.selectedTags.contains(tag.name);
                    return _CompactTagChip(
                      label: tag.name,
                      selected: selected,
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onSelectedTagsChanged(tag.name);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 640;
    final previewUrl = previewUrlForImage(
      _image,
      highQuality: widget.highQualityPreview,
    );
    final title = _image.name.trim();
    final showBookmarkButton = _image.pid > 0;
    final visibleTagCount = compact ? 3 : 5;
    final visibleTags = _image.tags.take(visibleTagCount).toList();
    final hiddenTagCount = math.max(0, _image.tags.length - visibleTags.length);

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 0 : 14),
      decoration: compact
          ? const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE8EDF4)),
              ),
            )
          : BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(18),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 10 : 14,
              compact ? 9 : 14,
              compact ? 10 : 14,
              compact ? 8 : 12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AuthorAvatar(
                  name: _image.author.name,
                  uid: _image.author.uid,
                  avatarUrl: _image.author.avatarUrl,
                  radius: compact ? 18 : 20,
                  compact: compact,
                ),
                SizedBox(width: compact ? 10 : 12),
                Expanded(
                  child: InkWell(
                    onTap: widget.onAuthorTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _image.author.name.trim().isEmpty
                              ? '未知作者'
                              : _image.author.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 14 : 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        if (_buildPublishedLabel().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _buildPublishedLabel(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 11 : 12,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (showBookmarkButton)
                  _BookmarkButton(
                    isBookmarked: _image.isBookmarked,
                    bookmarkCount: _image.bookmarkCount,
                    showCount: widget.showBookmarkCount,
                    isBusy: _isBookmarkSubmitting,
                    onTap: _toggleBookmark,
                    compact: compact,
                  ),
              ],
            ),
          ),
          Material(
            color: compact ? Colors.white : const Color(0xFFF8FAFC),
            child: InkWell(
              onTap: widget.onImageTap,
              child: _Artwork(url: previewUrl),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 10 : 14,
              compact ? 8 : 12,
              compact ? 10 : 14,
              compact ? 10 : 14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 15 : 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                if (visibleTags.isNotEmpty || hiddenTagCount > 0) ...[
                  if (title.isNotEmpty) const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in visibleTags)
                        _CompactTagChip(
                          label: tag.name,
                          selected: widget.selectedTags.contains(tag.name),
                          onTap: () => widget.onSelectedTagsChanged(tag.name),
                        ),
                      if (hiddenTagCount > 0)
                        _CompactMoreChip(
                          label: '+$hiddenTagCount',
                          onTap: _openTagSheet,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildPublishedLabel() {
    final published = formatUnixTimestamp(_image.publishedAt);
    if (published.isNotEmpty) return published;
    return formatUnixTimestamp(_image.updatedAt);
  }
}

class _Artwork extends StatefulWidget {
  final String url;

  const _Artwork({required this.url});

  @override
  State<_Artwork> createState() => _ArtworkState();
}

class _ArtworkState extends State<_Artwork> {
  CachedNetworkImageProvider? _provider;
  ImageStream? _imageStream;
  ImageStreamListener? _listener;
  Size? _imageSize;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _provider = _buildProvider();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant _Artwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _detachImageStream();
      _provider = _buildProvider();
      _imageSize = null;
      _loadError = null;
      _resolveImage();
    }
  }

  @override
  void dispose() {
    _detachImageStream();
    super.dispose();
  }

  CachedNetworkImageProvider? _buildProvider() {
    if (widget.url.isEmpty) return null;
    final resolvedUrl = proxiedImageUrl(widget.url);
    return CachedNetworkImageProvider(
      resolvedUrl,
      cacheManager: imageProxyCacheManager,
      headers: imageRequestHeaders(widget.url, resolvedUrl: resolvedUrl),
    );
  }

  void _resolveImage() {
    final provider = _provider;
    if (provider == null) return;
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (_imageStream?.key == stream.key) return;
    _detachImageStream();
    _imageStream = stream;
    _listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        setState(() {
          _imageSize =
              Size(info.image.width.toDouble(), info.image.height.toDouble());
          _loadError = null;
        });
      },
      onError: (error, _) {
        if (!mounted) return;
        setState(() => _loadError = error);
      },
    );
    stream.addListener(_listener!);
  }

  void _detachImageStream() {
    if (_imageStream != null && _listener != null) {
      _imageStream!.removeListener(_listener!);
    }
    _imageStream = null;
    _listener = null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (provider == null) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: Icon(Icons.image_not_supported_outlined, size: 42),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final maxPreviewHeight = availableWidth < 720 ? 640.0 : 760.0;
        final fallbackHeight = availableWidth < 720 ? 320.0 : 420.0;
        double previewWidth = availableWidth;
        double previewHeight = fallbackHeight;
        final imageSize = _imageSize;
        if (imageSize != null && imageSize.height > 0) {
          final aspectRatio = imageSize.width / imageSize.height;
          final naturalHeight = availableWidth / aspectRatio;
          previewHeight = math.min(naturalHeight, maxPreviewHeight);
          previewWidth = availableWidth;
        }

        return Container(
          width: double.infinity,
          color: availableWidth < 720 ? Colors.white : const Color(0xFFF8FAFC),
          child: Center(
            child: SizedBox(
              width: previewWidth,
              height: previewHeight,
              child: _loadError != null
                  ? const Center(
                      child: Icon(Icons.broken_image_outlined, size: 42),
                    )
                  : Image(
                      image: provider,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      frameBuilder: (context, child, frame, _) {
                        if (frame == null && _imageSize == null) {
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        return child;
                      },
                      errorBuilder: (context, _, __) => const Center(
                        child: Icon(Icons.broken_image_outlined, size: 42),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  final String name;
  final String uid;
  final String avatarUrl;
  final double radius;
  final bool compact;

  const _AuthorAvatar({
    required this.name,
    required this.uid,
    required this.avatarUrl,
    required this.radius,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return AppAvatar(
      name: name,
      uid: uid,
      avatarUrl: avatarUrl,
      radius: radius,
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  final bool isBookmarked;
  final int bookmarkCount;
  final bool showCount;
  final bool isBusy;
  final VoidCallback onTap;
  final bool compact;

  const _BookmarkButton({
    required this.isBookmarked,
    required this.bookmarkCount,
    required this.showCount,
    required this.isBusy,
    required this.onTap,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final foreground =
        isBookmarked ? const Color(0xFFE11D48) : const Color(0xFF475569);

    return Material(
      color: isBookmarked ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: isBusy ? null : onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 9,
            vertical: compact ? 6 : 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBusy)
                SizedBox(
                  width: compact ? 12 : 13,
                  height: compact ? 12 : 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(foreground),
                  ),
                )
              else
                Icon(
                  isBookmarked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: compact ? 14 : 15,
                  color: foreground,
                ),
              if (showCount) ...[
                const SizedBox(width: 4),
                Text(
                  bookmarkCount <= 0 ? '获取中' : '$bookmarkCount',
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactTagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CompactTagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEAF4FF) : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Text(
            '#$label',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color:
                  selected ? const Color(0xFF0A84FF) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactMoreChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CompactMoreChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }
}
