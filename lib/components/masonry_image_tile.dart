import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tagselector/components/like_recommendation_sheet.dart';
import 'package:tagselector/model/image_model.dart';
import 'package:tagselector/service/api_service.dart';
import 'package:tagselector/service/cache_proxy_manager.dart';
import 'package:tagselector/service/image_prefetcher.dart';
import 'package:tagselector/service/remote_image_url.dart';

class MasonryImageTile extends StatefulWidget {
  final ImageModel image;
  final bool highQualityPreview;
  final ValueChanged<ImageModel>? onImageChanged;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;
  final bool showBookmarkCount;

  const MasonryImageTile({
    super.key,
    required this.image,
    this.highQualityPreview = false,
    this.onImageChanged,
    this.onTap,
    this.onAuthorTap,
    this.showBookmarkCount = true,
  });

  @override
  State<MasonryImageTile> createState() => _MasonryImageTileState();
}

class _MasonryImageTileState extends State<MasonryImageTile> {
  final ApiService _api = ApiService.instance;

  late ImageModel _image;
  bool _isBookmarkSubmitting = false;

  @override
  void initState() {
    super.initState();
    _image = widget.image;
  }

  @override
  void didUpdateWidget(covariant MasonryImageTile oldWidget) {
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
      final mergedImage = _image.copyWith(
        bookmarkCount: updatedImage.bookmarkCount,
        isBookmarked: updatedImage.isBookmarked,
      );
      setState(() => _image = mergedImage);
      widget.onImageChanged?.call(mergedImage);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updatedImage.isBookmarked
                ? '\u5df2\u6536\u85cf\u4f5c\u54c1'
                : '\u5df2\u53d6\u6d88\u6536\u85cf',
          ),
        ),
      );
      if (!wasBookmarked && updatedImage.isBookmarked) {
        _openRecommendationTray(updatedImage);
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

  void _openRecommendationTray(ImageModel image) {
    showBookmarkRecommendationTray(
      context,
      seedImage: image,
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final imageUrl = previewUrlForImage(
      _image,
      highQuality: widget.highQualityPreview,
    );
    final aspectRatio = _tileAspectRatio(_image);
    final radius = BorderRadius.circular(compact ? 8 : 16);
    final showLike = _image.pid > 0;

    return RepaintBoundary(
      child: Material(
        color: Colors.white,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ArtworkImage(url: imageUrl),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x00000000),
                            Color(0x0A000000),
                            Color(0x8A000000),
                          ],
                          stops: [0, 0.58, 1],
                        ),
                      ),
                    ),
                    if (_image.pages.length > 1)
                      Positioned(
                        top: 7,
                        left: 7,
                        child: _OverlayPill(label: '${_image.pages.length}P'),
                      ),
                    if (showLike)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: _LikePill(
                          isBookmarked: _image.isBookmarked,
                          count: _image.bookmarkCount,
                          showCount: widget.showBookmarkCount,
                          isBusy: _isBookmarkSubmitting,
                          onTap: _toggleBookmark,
                        ),
                      ),
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: _Caption(
                        image: _image,
                        onAuthorTap: widget.onAuthorTap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _tileAspectRatio(ImageModel image) {
    if (image.width > 0 && image.height > 0) {
      return (image.width / image.height).clamp(0.58, 1.45).toDouble();
    }

    const fallbacks = [0.72, 0.82, 1.0, 1.18, 0.66, 0.92];
    return fallbacks[image.pid.abs() % fallbacks.length];
  }
}

class _ArtworkImage extends StatelessWidget {
  final String url;

  const _ArtworkImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const ColoredBox(
        color: Color(0xFFF1F5F9),
        child: Center(child: Icon(Icons.image_not_supported_outlined)),
      );
    }

    return CachedNetworkImage(
      cacheManager: imageProxyCacheManager,
      imageUrl: proxiedImageUrl(url),
      httpHeaders: imageRequestHeaders(url),
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      filterQuality: FilterQuality.low,
      memCacheWidth: _thumbnailCacheExtent(context),
      maxWidthDiskCache: _thumbnailCacheExtent(context),
      placeholder: (_, __) => const ColoredBox(color: Color(0xFFF1F5F9)),
      errorWidget: (_, __, ___) => const ColoredBox(
        color: Color(0xFFF1F5F9),
        child: Center(child: Icon(Icons.broken_image_outlined, size: 24)),
      ),
    );
  }

  int _thumbnailCacheExtent(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logicalTileWidth = width < 640 ? width / 2 : 260.0;
    return (logicalTileWidth * dpr).round().clamp(320, 900);
  }
}

class _Caption extends StatelessWidget {
  final ImageModel image;
  final VoidCallback? onAuthorTap;

  const _Caption({
    required this.image,
    required this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onAuthorTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (image.name.trim().isNotEmpty)
            Text(
              image.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.08,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: [Shadow(color: Color(0x99000000), blurRadius: 8)],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            image.author.name.trim().isEmpty
                ? '\u672a\u77e5\u4f5c\u8005'
                : image.author.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              height: 1,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              shadows: [Shadow(color: Color(0x99000000), blurRadius: 8)],
            ),
          ),
        ],
      ),
    );
  }
}

class _LikePill extends StatelessWidget {
  final bool isBookmarked;
  final int count;
  final bool showCount;
  final bool isBusy;
  final VoidCallback onTap;

  const _LikePill({
    required this.isBookmarked,
    required this.count,
    required this.showCount,
    required this.isBusy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isBookmarked ? const Color(0xFFE11D48) : const Color(0xFF1F2937);

    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: isBusy ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBusy)
                SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Icon(
                  isBookmarked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 12,
                  color: color,
                ),
              if (showCount) ...[
                const SizedBox(width: 3),
                Text(
                  count <= 0 ? '获取中' : '$count',
                  style: TextStyle(
                    fontSize: count <= 0 ? 9 : 10,
                    fontWeight: FontWeight.w800,
                    color: color,
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

class _OverlayPill extends StatelessWidget {
  final String label;

  const _OverlayPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
