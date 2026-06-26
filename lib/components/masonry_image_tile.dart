import 'package:flutter/material.dart';
import 'package:tagselector/components/image_card.dart';
import 'package:tagselector/model/image_model.dart';
import 'package:tagselector/service/api_service.dart';
import 'package:tagselector/service/artwork_download_manager.dart';
import 'package:tagselector/service/image_prefetcher.dart';
import 'package:tagselector/service/image_state_merger.dart';

class MasonryImageTile extends StatefulWidget {
  final ImageModel image;
  final bool highQualityPreview;
  final ValueChanged<ImageModel>? onImageChanged;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;
  final bool showBookmarkCount;
  final ValueChanged<ImageModel>? onImageBookmarked;

  const MasonryImageTile({
    super.key,
    required this.image,
    this.highQualityPreview = false,
    this.onImageChanged,
    this.onTap,
    this.onAuthorTap,
    this.showBookmarkCount = true,
    this.onImageBookmarked,
  });

  @override
  State<MasonryImageTile> createState() => _MasonryImageTileState();
}

class _MasonryImageTileState extends State<MasonryImageTile> {
  final ApiService _api = ApiService.instance;

  late ImageModel _image;
  late double _lockedAspectRatio;
  bool _isBookmarkSubmitting = false;
  bool _isOriginDownloadStarting = false;

  @override
  void initState() {
    super.initState();
    _image = widget.image;
    _lockedAspectRatio = _tileAspectRatio(widget.image);
  }

  @override
  void didUpdateWidget(covariant MasonryImageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _image = widget.image;
      if (oldWidget.image.pid != widget.image.pid) {
        _lockedAspectRatio = _tileAspectRatio(widget.image);
      }
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

  Future<void> _downloadOriginalArtwork() async {
    if (_isOriginDownloadStarting || _image.pid <= 0) return;

    setState(() => _isOriginDownloadStarting = true);
    try {
      var image = _image;
      if (image.urls.original.isEmpty) {
        image = await _api.fetchImageDetail(_image.pid);
        if (!mounted) return;
        setState(() => _image = image);
        widget.onImageChanged?.call(image);
      }

      final batchFuture =
          ArtworkDownloadManager.instance.downloadOriginalArtwork(image);
      if (!mounted) return;
      // Download progress is shown by the shared floating download control.
      final batch = await batchFuture;
      if (!mounted) return;
      if (batch.hasFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '保存完成：${batch.completedCount}/${batch.tasks.length} 张成功',
            ),
          ),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final imageUrl = previewUrlForImage(
      _image,
      highQuality: widget.highQualityPreview,
    );

    return AppImageCard(
      image: _image,
      imageUrl: imageUrl,
      onTap: widget.onTap,
      onLongPress: _downloadOriginalArtwork,
      topLeft: _image.pages.length > 1
          ? AppImageBadge(label: '${_image.pages.length}P')
          : null,
      topRight: _image.pid > 0
          ? AppImageLikePill(
              isBookmarked: _image.isBookmarked,
              count: _image.bookmarkCount,
              showCount: widget.showBookmarkCount,
              isBusy: _isBookmarkSubmitting,
              onTap: _toggleBookmark,
              compact: compact,
            )
          : null,
      bottom: AppImageCardCaption(
        image: _image,
        onAuthorTap: widget.onAuthorTap,
      ),
      radius: compact ? 8 : 16,
      aspectRatio: _lockedAspectRatio,
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
