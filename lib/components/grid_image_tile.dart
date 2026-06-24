import 'package:flutter/material.dart';
import 'package:tagselector/components/image_card.dart';
import 'package:tagselector/model/image_model.dart';
import 'package:tagselector/service/api_service.dart';
import 'package:tagselector/service/artwork_download_manager.dart';
import 'package:tagselector/service/image_state_merger.dart';
import 'package:tagselector/service/image_prefetcher.dart';
import 'package:tagselector/utils.dart';

class GridImageTile extends StatefulWidget {
  final ImageModel imageModel;
  final ValueChanged<ImageModel>? onImageChanged;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;
  final ValueChanged<ImageModel>? onImageBookmarked;

  const GridImageTile({
    super.key,
    required this.imageModel,
    this.onImageChanged,
    this.onTap,
    this.onAuthorTap,
    this.onImageBookmarked,
  });

  @override
  State<GridImageTile> createState() => _GridImageTileState();
}

class _GridImageTileState extends State<GridImageTile> {
  final ApiService _api = ApiService.instance;

  late ImageModel _image;
  bool _isBookmarkSubmitting = false;
  bool _isOriginDownloadStarting = false;

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
      final mergedImage = mergeImageState(_image, updatedImage);
      setState(() => _image = mergedImage);
      widget.onImageChanged?.call(mergedImage);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(updatedImage.isBookmarked ? '已收藏作品' : '已取消收藏'),
        ),
      );
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

      final pageCount = image.pages.isEmpty ? 1 : image.pages.length;
      final batchFuture =
          ArtworkDownloadManager.instance.downloadOriginalArtwork(image);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已开始保存 origin，共 $pageCount 张')),
      );
      final batch = await batchFuture;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            batch.hasFailed
                ? '保存完成：${batch.completedCount}/${batch.tasks.length} 张成功'
                : '已保存 ${batch.tasks.length} 张 origin 图片',
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

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final coverUrl = previewUrlForImage(_image, highQuality: false);
    final aspectRatio = _tileAspectRatio(_image);

    return AppImageCard(
      image: _image,
      imageUrl: coverUrl,
      onTap: widget.onTap,
      onLongPress: _downloadOriginalArtwork,
      topLeft: _image.pages.length > 1
          ? AppImageBadge(label: '${_image.pages.length}P')
          : null,
      topRight: _image.pid > 0
          ? AppImageLikePill(
              isBookmarked: _image.isBookmarked,
              count: _image.bookmarkCount,
              showCount: true,
              isBusy: _isBookmarkSubmitting,
              onTap: _toggleBookmark,
              compact: compact,
            )
          : null,
      bottom: AppImageCardCaption(
        image: _image,
        onAuthorTap: widget.onAuthorTap,
        trailing: Text(
          _buildPublishedLabel(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9,
            height: 1.05,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      radius: compact ? 8 : 16,
      aspectRatio: aspectRatio,
    );
  }

  double _tileAspectRatio(ImageModel image) {
    if (image.width > 0 && image.height > 0) {
      return (image.width / image.height).clamp(0.58, 1.45).toDouble();
    }

    const fallbacks = [0.72, 0.82, 1.0, 1.18, 0.66, 0.92];
    return fallbacks[image.pid.abs() % fallbacks.length];
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
