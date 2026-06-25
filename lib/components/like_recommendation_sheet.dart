import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tagselector/components/app_ui.dart';
import 'package:tagselector/model/image_model.dart';
import 'package:tagselector/model/image_recommendation_model.dart';
import 'package:tagselector/pages/full_image_page.dart';
import 'package:tagselector/service/api_service.dart';
import 'package:tagselector/service/cache_proxy_manager.dart';
import 'package:tagselector/service/remote_image_url.dart';

OverlayEntry? _activeRecommendationOverlay;

void showBookmarkRecommendationTray(
  BuildContext context, {
  required ImageModel seedImage,
  int limit = 6,
}) {
  _activeRecommendationOverlay?.remove();
  _activeRecommendationOverlay = null;

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    return;
  }

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _BookmarkRecommendationTray(
      seedImage: seedImage,
      limit: limit,
      onClose: () {
        if (_activeRecommendationOverlay == entry) {
          _activeRecommendationOverlay = null;
        }
        entry.remove();
      },
    ),
  );

  _activeRecommendationOverlay = entry;
  overlay.insert(entry);
}

class _BookmarkRecommendationTray extends StatefulWidget {
  final ImageModel seedImage;
  final int limit;
  final VoidCallback onClose;

  const _BookmarkRecommendationTray({
    required this.seedImage,
    required this.limit,
    required this.onClose,
  });

  @override
  State<_BookmarkRecommendationTray> createState() =>
      _BookmarkRecommendationTrayState();
}

class _BookmarkRecommendationTrayState
    extends State<_BookmarkRecommendationTray>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  final ScrollController _scrollController = ScrollController();
  List<ImageRecommendationModel> _recommendations = const [];
  Object? _error;
  bool _loading = true;
  Timer? _dismissTimer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
    _dismissTimer = Timer(const Duration(seconds: 8), _close);
  }

  Future<void> _loadRecommendations() async {
    try {
      final recommendations =
          await ApiService.instance.fetchImageRecommendations(
        widget.seedImage.pid,
        limit: widget.limit,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _recommendations = recommendations;
        _loading = false;
        _error = null;
      });
      _hydrateRecommendationBookmarkCounts(recommendations);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  void _hydrateRecommendationBookmarkCounts(
    List<ImageRecommendationModel> recommendations,
  ) {
    final targets = recommendations
        .where((recommendation) =>
            recommendation.pid > 0 && recommendation.bookmarkCount <= 0)
        .toList();
    if (targets.isEmpty) {
      return;
    }

    unawaited(() async {
      final hydrated =
          await ApiService.instance.hydrateRecommendationBookmarkCounts(
        targets,
        maxItems: targets.length,
      );
      if (!mounted) {
        return;
      }
      final hydratedByPid = {
        for (final recommendation in hydrated)
          if (recommendation.pid > 0) recommendation.pid: recommendation,
      };
      setState(() {
        _recommendations = _recommendations.map((recommendation) {
          return hydratedByPid[recommendation.pid] ?? recommendation;
        }).toList();
      });
    }());
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _dismissTimer?.cancel();
    await _controller.reverse();
    if (mounted) {
      widget.onClose();
    }
  }

  Future<void> _openRecommendation(ImageModel image) async {
    _dismissTimer?.cancel();
    await _close();
    if (!mounted) return;
    unawaited(
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => FullImagePage(image: image)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final trayWidth = math.min(screenWidth - 24, 760.0);

    return Positioned(
      left: 12,
      right: 12,
      bottom: 16,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SlideTransition(
          position: _offsetAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: trayWidth,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A0F172A),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: _close,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Close',
                    visualDensity: VisualDensity.compact,
                  ),
                  _buildRecommendations(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendations() {
    if (_loading) {
      return const SizedBox(
        height: 122,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_error != null) {
      return const SizedBox(
        height: 122,
        child: Center(
          child: Icon(Icons.cloud_off_rounded, color: Color(0xFF94A3B8)),
        ),
      );
    }

    if (_recommendations.isEmpty) {
      return const SizedBox(
        height: 122,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Color(0xFF94A3B8),
          ),
        ),
      );
    }

    return SizedBox(
      height: 122,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: _recommendations.length > 5,
        child: ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          itemCount: _recommendations.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final image = _recommendations[index].toPlaceholderImage();
            return _RecommendationMiniCard(
              image: image,
              onTap: () => _openRecommendation(image),
            );
          },
        ),
      ),
    );
  }
}

class _RecommendationMiniCard extends StatelessWidget {
  final ImageModel image;
  final VoidCallback onTap;

  const _RecommendationMiniCard({
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final previewUrl = image.urls.small.isNotEmpty
        ? image.urls.small
        : (image.urls.regular.isNotEmpty
            ? image.urls.regular
            : image.urls.thumb);

    return SizedBox(
      width: 96,
      child: Material(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: previewUrl.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFFF1F5F9),
                        child: Center(
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: proxiedImageUrl(previewUrl),
                        cacheManager: imageProxyCacheManager,
                        httpHeaders: imageRequestHeaders(previewUrl),
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
                top: 7,
                right: 7,
                child: AppBookmarkButton(
                  image: image,
                  iconOnly: true,
                  showCount: false,
                  elevated: true,
                  iconSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
