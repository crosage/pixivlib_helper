import 'dart:convert';

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
  String _fetchedAvatarUrl = "";
  final CacheManager myProxyCacheManager = imageProxyCacheManager;
  HttpHelper httpHelper = HttpHelper.getInstance(
      globalProxyHost: "127.0.0.1", globalProxyPort: "7890");

  @override
  void initState() {
    super.initState();
    _initializeState();
    _fetchAvatarData();
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
    if (widget.image.author.uid != oldWidget.image.author.uid) {
      print(
          'Author changed, fetching new avatar for ${widget.image.author.uid}');
      setState(() {
        _fetchedAvatarUrl = "";
      });
      _fetchAvatarData();
    }
    if (widget.image.tags.length != oldWidget.image.tags.length) {
      print('Tags length changed, reinitializing tag state.');
      setState(() {
        _initializeSyncState();
      });
    } else {
      _updateTagSelectionVisualsIfNeeded(oldWidget.selectedTags);
    }
  }

  void _updateTagSelectionVisualsIfNeeded(List<dynamic> oldSelectedTags) {
    bool needsUpdate = false;
    if (widget.selectedTags.length != oldSelectedTags.length) {
      needsUpdate = true;
    } else {
      for (var tag in widget.image.tags) {
        bool wasSelected = oldSelectedTags.contains(tag.name);
        bool isSelected = widget.selectedTags.contains(tag.name);
        if (wasSelected != isSelected) {
          needsUpdate = true;
          break;
        }
      }
    }

    if (needsUpdate) {
      setState(() {
        _updateTagSelectionVisuals();
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

  void _initializeSyncState() {
    _isSelected = List.generate(widget.image.tags.length, (index) => false);
    _colors = List.generate(widget.image.tags.length, (index) => Colors.grey);
    _updateTagSelectionVisuals();
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

  Future<void> _fetchAvatarData() async {
    final response = await httpHelper.getRequest(
        "https://www.pixiv.net/ajax/user/${widget.image.author.uid}?full=1&lang=zh",
        headers: {
          "referer": "https://www.pixiv.net",
          "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.212 Safari/537.36",
        },
        useProxy: true);
    if (response.statusCode == 200) {
      Map<String, dynamic> responseData = jsonDecode(response.toString());
      String avatarUrl = responseData['body']['imageBig'];
      if (mounted) {
        setState(() {
          _fetchedAvatarUrl = avatarUrl;
        });
      }
    }
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipOval(
                        child: buildCircleAvatar(_fetchedAvatarUrl, 25),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      InkWell(
                        onTap: () =>
                            widget.onSelectedAuthor(widget.image.author.name),
                        child: Text(
                          widget.image.author.name,
                          style: textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    child: _buildImageArea(widget.image.urls.regular, 500, 500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.image.name,
                  style: textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.image.isBookmarked)
                  Icon(
                    Icons.favorite,
                    color: Colors.red,
                  )
                else
                  Icon(Icons.favorite_border)
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

  Widget _buildImageArea(
    String url,
    double width,
    double height, {
    BoxFit fit = BoxFit.contain,
  }) {
    String? imageUrl = url;

    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(/* 错误占位符 */);
    }
    return Container(
      color: Colors.grey[50],
      constraints: BoxConstraints(
        maxWidth: width,
        maxHeight: height,
      ),
      child: CachedNetworkImage(
        cacheManager: myProxyCacheManager,
        imageUrl: imageUrl,
        httpHeaders: const {
          'Referer': 'https://www.pixiv.net/',
        },
        fit: fit,
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

  Widget buildCircleAvatar(String? url, double radius) {
    ImageProvider? backgroundImage;
    if (url != null && url.isNotEmpty) {
      backgroundImage = CachedNetworkImageProvider(
        cacheManager: myProxyCacheManager,
        url,
        headers: const {'Referer': 'https://www.pixiv.net/'},
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[200],
      backgroundImage: backgroundImage,
      child: (backgroundImage == null)
          ? Icon(Icons.person_outline, size: radius, color: Colors.grey[400])
          : null,
    );
  }
}
