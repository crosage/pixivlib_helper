import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tagselector/components/like_recommendation_sheet.dart';
import 'package:tagselector/model/image_model.dart';
import 'package:tagselector/service/api_service.dart';
import 'package:tagselector/service/cache_proxy_manager.dart';
import 'package:tagselector/service/image_prefetcher.dart';
import 'package:tagselector/service/remote_image_url.dart';
import 'package:tagselector/utils.dart';

class GridImageTile extends StatefulWidget {
  final ImageModel imageModel;
  final ValueChanged<ImageModel>? onImageChanged;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;

  const GridImageTile({
    super.key,
    required this.imageModel,
    this.onImageChanged,
    this.onTap,
    this.onAuthorTap,
  });

  @override
  State<GridImageTile> createState() => _GridImageTileState();
}

class _GridImageTileState extends State<GridImageTile> {
  final ApiService _api = ApiService.instance;

  late ImageModel _image;
  bool _isBookmarkSubmitting = false;

  @override
  void initState() {
    super.initState();
    _image = widget.imageModel;
  }

  @override
  void didUpdateWidget(covariant GridImageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageModel != widget.imageModel) {
      _image = widget.imageModel;
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
          content: Text(updatedImage.isBookmarked ? '已收藏作品' : '已取消收藏'),
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
    final coverUrl = previewUrlForImage(_image, highQuality: false);
    final radius = BorderRadius.circular(compact ? 8 : 16);
    final showLike = _image.pid > 0;
    final pageCount =
        _image.pageCount > 0 ? _image.pageCount : _image.pages.length;

    if (compact) {
      return RepaintBoundary(
        child: Material(
          color: Colors.white,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: radius,
            onTap: widget.onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _NetworkArtwork(url: coverUrl),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00000000),
                          Color(0x00000000),
                          Color(0xB3000000),
                        ],
                        stops: [0, 0.54, 1],
                      ),
                    ),
                  ),
                ),
                if (showLike)
                  Positioned(
                    top: 7,
                    right: 7,
                    child: _MiniLikeButton(
                      isBookmarked: _image.isBookmarked,
                      count: _image.bookmarkCount,
                      isBusy: _isBookmarkSubmitting,
                      onTap: _toggleBookmark,
                    ),
                  ),
                if (pageCount > 1)
                  Positioned(
                    top: 7,
                    left: 7,
                    child: _MobileOverlayPill(label: '${pageCount}P'),
                  ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: InkWell(
                    onTap: widget.onAuthorTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_image.name.trim().isNotEmpty)
                          Text(
                            _image.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _AuthorAvatar(
                              name: _image.author.name,
                              uid: _image.author.uid,
                              avatarUrl: _image.author.avatarUrl,
                              compact: true,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _image.author.name.trim().isEmpty
                                    ? '未知作者'
                                    : _image.author.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
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
        ),
      );
    }

    return RepaintBoundary(
      child: Material(
        color: Colors.white,
        borderRadius: radius,
        clipBehavior: Clip.none,
        child: InkWell(
          borderRadius: radius,
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border:
                  compact ? null : Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: radius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _NetworkArtwork(url: coverUrl),
                      if (showLike)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _MiniLikeButton(
                            isBookmarked: _image.isBookmarked,
                            count: _image.bookmarkCount,
                            isBusy: _isBookmarkSubmitting,
                            onTap: _toggleBookmark,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 6 : 10,
                    compact ? 6 : 9,
                    compact ? 6 : 10,
                    compact ? 7 : 10,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: widget.onAuthorTap,
                    child: Row(
                      children: [
                        _AuthorAvatar(
                          name: _image.author.name,
                          uid: _image.author.uid,
                          avatarUrl: _image.author.avatarUrl,
                          compact: compact,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
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
                                  fontSize: compact ? 11 : 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _buildPublishedLabel(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: compact ? 10 : 11,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  String _buildPublishedLabel() {
    final published = formatUnixTimestamp(_image.publishedAt);
    if (published.isNotEmpty) {
      return published;
    }
    final updated = formatUnixTimestamp(_image.updatedAt);
    return updated.isNotEmpty ? updated : '时间未知';
  }
}

class _NetworkArtwork extends StatelessWidget {
  final String url;

  const _NetworkArtwork({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: const Color(0xFFF8FAFC),
        child: const Center(child: Icon(Icons.image_not_supported_outlined)),
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
      placeholder: (context, _) => const ColoredBox(color: Color(0xFFF8FAFC)),
      errorWidget: (context, _, __) => Container(
        color: const Color(0xFFF8FAFC),
        child: const Center(child: Icon(Icons.broken_image_outlined, size: 28)),
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

class _MiniLikeButton extends StatelessWidget {
  final bool isBookmarked;
  final int count;
  final bool isBusy;
  final VoidCallback onTap;

  const _MiniLikeButton({
    required this.isBookmarked,
    required this.count,
    required this.isBusy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isBookmarked ? const Color(0xFFE11D48) : const Color(0xFF1F2937);

    return Material(
      color: Colors.white.withValues(alpha: 0.94),
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
              const SizedBox(width: 3),
              Text(
                count <= 0 ? '获取中' : '$count',
                style: TextStyle(
                  fontSize: count <= 0 ? 9 : 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileOverlayPill extends StatelessWidget {
  final String label;

  const _MobileOverlayPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
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

class _AuthorAvatar extends StatelessWidget {
  final String name;
  final String uid;
  final String avatarUrl;
  final bool compact;

  const _AuthorAvatar({
    required this.name,
    required this.uid,
    required this.avatarUrl,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarUrl.isNotEmpty) {
      if (compact) {
        return CircleAvatar(
          radius: 11,
          backgroundImage: CachedNetworkImageProvider(
            proxiedImageUrl(avatarUrl),
            cacheManager: imageProxyCacheManager,
          ),
        );
      }
      return CircleAvatar(
        radius: 11,
        backgroundImage: CachedNetworkImageProvider(
          proxiedImageUrl(avatarUrl),
          cacheManager: imageProxyCacheManager,
        ),
      );
    }

    if (compact) {
      return CircleAvatar(
        radius: 11,
        backgroundColor: getRandomColor(uid.hashCode).withValues(alpha: 0.18),
        child: Text(
          name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1D4ED8),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 11,
      backgroundColor: getRandomColor(uid.hashCode).withValues(alpha: 0.18),
      child: Text(
        name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1D4ED8),
        ),
      ),
    );
  }
}
