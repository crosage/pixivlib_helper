import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tagselector/service/cache_proxy_manager.dart';
import 'package:tagselector/service/remote_image_url.dart';
import 'package:tagselector/utils.dart';

class AppAvatar extends StatelessWidget {
  final String name;
  final String uid;
  final String avatarUrl;
  final double radius;

  const AppAvatar({
    super.key,
    required this.name,
    required this.uid,
    required this.avatarUrl,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = avatarUrl.trim();
    if (trimmed.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(
          proxiedImageUrl(trimmed),
          cacheManager: imageProxyCacheManager,
          headers: imageRequestHeaders(trimmed),
        ),
      );
    }

    final color = getRandomColor(uid.hashCode).withValues(alpha: 0.18);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontSize: radius * 0.78,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1D4ED8),
        ),
      ),
    );
  }
}
