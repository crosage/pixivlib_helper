import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:tagselector/model/author_model.dart';
import 'dart:math';
import 'package:tagselector/utils.dart';
import '../model/image_model.dart';
import '../model/page_model.dart';
import '../model/tag_model.dart';
import 'dart:typed_data';
import '../service/cache_proxy_manager.dart';
import '../service/http_helper.dart';

class ImageWithInfo extends StatefulWidget {
  final ImageModel image;
  final List<dynamic> selectedTags;
  final Function(String) onSelectedTagsChanged;
  final Function(String) onSelectedAuthor;

  const ImageWithInfo({
    super.key,
    required this.image,
    required this.selectedTags,
    required this.onSelectedTagsChanged,
    required this.onSelectedAuthor,
  });

  @override
  _ImageWithInfoState createState() => _ImageWithInfoState();
}

class _ImageWithInfoState extends State<ImageWithInfo> {
  late List<bool> _isSelected;
  late List<Color> _colors;
  int hoveredIndex = 0;
  int currentIndex = 0;
  final CacheManager myProxyCacheManager = imageProxyCacheManager;

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  void _initializeState() {
    _isSelected = List.generate(widget.image.tags.length, (index) => false);
    _colors = List.generate(widget.image.tags.length, (index) => Colors.grey);
    _updateTagSelectionVisuals();
    hoveredIndex = 0;
    currentIndex = 0;
  }

  @override
  void didUpdateWidget(ImageWithInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image.tags.length != oldWidget.image.tags.length) {
      setState(() {
        _isSelected = List<bool>.filled(widget.image.tags.length, false);
        _colors = List<Color>.generate(widget.image.tags.length, (index) {
          return Colors.primaries[index % Colors.primaries.length];
        });
      });
    }
  }

  void _updateTagSelectionVisuals() {
    for (int i = 0; i < widget.image.tags.length; i++) {
      bool isSelected = widget.selectedTags.contains(widget.image.tags[i].name);
      _isSelected[i] = isSelected;
      _colors[i] = isSelected
          ? getRandomColor(widget.image.tags[i].name.hashCode)
          : Colors.grey;
    }
  }

  void _handleTagSelection(int index, bool isSelected) {
    setState(() {
      _isSelected[index] = isSelected;
      _colors[index] = isSelected
          ? getRandomColor(widget.image.tags[index].name.hashCode)
          : Colors.grey;
    });
    widget.onSelectedTagsChanged(widget.image.tags[index].name);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 100.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () =>
                        widget.onSelectedAuthor(widget.image.author.name),
                    child: Text(
                      widget.image.author.name,
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.image.name,
                    style: textTheme.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    child: _buildImageArea(),
                  ),
                ),
              ],
            ),
            if (widget.image.tags.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Wrap(
                  spacing: 6.0,
                  runSpacing: 4.0,
                  children: List.generate(
                    widget.image.tags.length,
                    (index) {
                      final tag = widget.image.tags[index];
                      return FilterChip(
                        label: Text(tag.name),
                        labelStyle: TextStyle(fontSize: 11),
                        selected: _isSelected[index],
                        onSelected: (isSelected) =>
                            _handleTagSelection(index, isSelected),
                        backgroundColor: Colors.black12,
                        selectedColor: _colors[index].withOpacity(0.3),
                        showCheckmark: false,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 2.0),
                        side: BorderSide.none,
                        shape: StadiumBorder(),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    String? imageUrl = widget.image.urls.regular;

    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(/* 错误占位符 */);
    }
    return Container(
      color: Colors.grey[50],
      constraints: const BoxConstraints(
        maxWidth: 500,
        maxHeight: 500,
      ),
      child: CachedNetworkImage(
        cacheManager: myProxyCacheManager,
        imageUrl: imageUrl,
        httpHeaders: const {
          'Referer': 'https://www.pixiv.net/',
        },
        fit: BoxFit.contain,
        placeholder: (context, url) => Container(
          color: Colors.grey[200],
          child:
              const Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[100],
          child: const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: Colors.grey, size: 40)),
        ),
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 200),
      ),
    );
  }
}
