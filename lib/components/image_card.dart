import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tagselector/model/image_model.dart';
import 'package:tagselector/service/cache_proxy_manager.dart';
import 'package:tagselector/service/remote_image_url.dart';

class AppImageCard extends StatelessWidget {
  final ImageModel image;
  final String imageUrl;
  final VoidCallback? onTap;
  final Widget? topLeft;
  final Widget? topRight;
  final Widget? bottom;
  final double radius;
  final double aspectRatio;
  final VoidCallback? onLongPress;

  const AppImageCard({
    super.key,
    required this.image,
    required this.imageUrl,
    this.onTap,
    this.topLeft,
    this.topRight,
    this.bottom,
    this.radius = 16,
    this.aspectRatio = 1.0,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return RepaintBoundary(
      child: Material(
        color: Colors.white,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImageArtwork(url: imageUrl),
                const Positioned.fill(
                  child: DecoratedBox(
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
                ),
                if (topLeft != null)
                  Positioned(top: 7, left: 7, child: topLeft!),
                if (topRight != null)
                  Positioned(top: 7, right: 7, child: topRight!),
                if (bottom != null)
                  Positioned(left: 8, right: 8, bottom: 8, child: bottom!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppImageArtwork extends StatelessWidget {
  final String url;
  final int? memCacheWidth;
  final int? maxWidthDiskCache;

  const AppImageArtwork({
    super.key,
    required this.url,
    this.memCacheWidth,
    this.maxWidthDiskCache,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const ColoredBox(
        color: Color(0xFFF8FAFC),
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
      memCacheWidth: memCacheWidth,
      maxWidthDiskCache: maxWidthDiskCache,
      placeholder: (_, __) => const ColoredBox(color: Color(0xFFF8FAFC)),
      errorWidget: (_, __, ___) => const ColoredBox(
        color: Color(0xFFF8FAFC),
        child: Center(child: Icon(Icons.broken_image_outlined, size: 28)),
      ),
    );
  }
}

class AppImageBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const AppImageBadge({
    super.key,
    required this.label,
    this.backgroundColor = const Color(0x66000000),
    this.foregroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: foregroundColor,
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class AppImageLikePill extends StatelessWidget {
  final bool isBookmarked;
  final int count;
  final bool showCount;
  final bool isBusy;
  final VoidCallback onTap;
  final bool compact;

  const AppImageLikePill({
    super.key,
    required this.isBookmarked,
    required this.count,
    required this.showCount,
    required this.isBusy,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isBookmarked ? const Color(0xFFE11D48) : const Color(0xFF64748B);

    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: isBusy ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 7,
            vertical: compact ? 5 : 5,
          ),
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

class AppImageCardCaption extends StatelessWidget {
  final ImageModel image;
  final bool showAuthorAvatar;
  final VoidCallback? onAuthorTap;
  final Widget? trailing;

  const AppImageCardCaption({
    super.key,
    required this.image,
    this.showAuthorAvatar = false,
    this.onAuthorTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onAuthorTap,
      child: Row(
        children: [
          if (showAuthorAvatar) ...[
            _TinyAuthorAvatar(
              name: image.author.name,
              uid: image.author.uid,
              avatarUrl: image.author.avatarUrl,
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
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
                    ),
                  ),
                const SizedBox(height: 3),
                Text(
                  image.author.name.trim().isEmpty ? '未知作者' : image.author.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.05,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _TinyAuthorAvatar extends StatelessWidget {
  final String name;
  final String uid;
  final String avatarUrl;

  const _TinyAuthorAvatar({
    required this.name,
    required this.uid,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final radius = MediaQuery.sizeOf(context).width < 720 ? 11.0 : 12.0;
    if (avatarUrl.trim().isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white.withValues(alpha: 0.16),
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
      radius: radius,
      backgroundImage: CachedNetworkImageProvider(
        proxiedImageUrl(avatarUrl),
        cacheManager: imageProxyCacheManager,
        headers: imageRequestHeaders(avatarUrl),
      ),
    );
  }
}
