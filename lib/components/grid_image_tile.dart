import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../model/image_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../service/cache_proxy_manager.dart';
import '../service/http_helper.dart';

class GridImageTile extends StatefulWidget {
  final ImageModel imageModel;
  final VoidCallback? onTap;

  const GridImageTile({
    Key? key,
    required this.imageModel,
    this.onTap,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => GridImageTileState();
}

class GridImageTileState extends State<GridImageTile> {
  final CacheManager myProxyCacheManager = imageProxyCacheManager;
  HttpHelper httpHelper = HttpHelper.getInstance(
      globalProxyHost: "127.0.0.1", globalProxyPort: "7890");
  String _fetchedAvatarUrl = "";
  ImageProvider? backgroundImage;

  @override
  void initState() {
    super.initState();
    _fetchAvatarData();
  }

  Future<void> _fetchAvatarData() async {
    final response = await httpHelper.getRequest(
        "https://www.pixiv.net/ajax/user/${widget.imageModel.author.uid}?full=1&lang=zh",
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
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 184,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: SizedBox(
                width: 184,
                height: 184,
                child: _buildImageArea(widget.imageModel.urls.thumb, 184, 184),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6.0, left: 4.0, right: 4.0),
              child: Text(
                widget.imageModel.name,
                style: const TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                  top: 4.0, left: 4.0, right: 4.0, bottom: 4.0), // Add spacing
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildCircleAvatar(_fetchedAvatarUrl, 15),
                  const SizedBox(width: 6.0),
                  Expanded(
                    child: Text(
                      widget.imageModel.author.name,
                      style: TextStyle(
                        fontSize: 12.0,
                        color: Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildCircleAvatar(String? url, double radius) {
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
