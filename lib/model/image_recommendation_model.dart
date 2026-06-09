import 'package:tagselector/model/author_model.dart';
import 'package:tagselector/model/image_model.dart';
import 'package:tagselector/model/image_url_model.dart';
import 'package:tagselector/model/tag_model.dart';

class ImageRecommendationModel {
  final int pid;
  final String title;
  final Author author;
  final String thumbUrl;
  final String smallUrl;
  final String regularUrl;
  final int bookmarkCount;
  final bool isBookmarked;
  final int pageCount;
  final int width;
  final int height;
  final int publishedAt;
  final List<String> tags;
  final String type;

  const ImageRecommendationModel({
    required this.pid,
    required this.title,
    required this.author,
    required this.thumbUrl,
    required this.smallUrl,
    required this.regularUrl,
    required this.bookmarkCount,
    required this.isBookmarked,
    required this.pageCount,
    required this.width,
    required this.height,
    required this.publishedAt,
    required this.tags,
    required this.type,
  });

  ImageRecommendationModel copyWith({
    int? bookmarkCount,
    bool? isBookmarked,
  }) {
    return ImageRecommendationModel(
      pid: pid,
      title: title,
      author: author,
      thumbUrl: thumbUrl,
      smallUrl: smallUrl,
      regularUrl: regularUrl,
      bookmarkCount: bookmarkCount ?? this.bookmarkCount,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      pageCount: pageCount,
      width: width,
      height: height,
      publishedAt: publishedAt,
      tags: tags,
      type: type,
    );
  }

  factory ImageRecommendationModel.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'] as List? ?? const [];
    return ImageRecommendationModel(
      pid: json['pid'] ?? 0,
      title: json['title'] ?? '',
      author: Author.fromJson(Map<String, dynamic>.from(json['author'] ?? {})),
      thumbUrl: json['thumb_url'] ?? '',
      smallUrl: json['small_url'] ?? '',
      regularUrl: json['regular_url'] ?? '',
      bookmarkCount: json['bookmark_count'] ?? 0,
      isBookmarked: json['is_bookmarked'] ?? false,
      pageCount: json['page_count'] ?? 0,
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
      publishedAt: json['published_at'] ?? 0,
      tags: rawTags.map(_parseTagName).where((tag) => tag.isNotEmpty).toList(),
      type: json['type'] ?? '',
    );
  }

  ImageModel toPlaceholderImage() {
    final derivedSmall = _deriveSmallFromPixivThumb(thumbUrl);
    final derivedRegular = _deriveRegularFromPixivThumb(thumbUrl);
    final fallbackSmall = smallUrl.isNotEmpty
        ? smallUrl
        : (derivedSmall.isNotEmpty ? derivedSmall : thumbUrl);
    final fallbackRegular = regularUrl.isNotEmpty
        ? regularUrl
        : (derivedRegular.isNotEmpty ? derivedRegular : fallbackSmall);

    return ImageModel(
      id: 0,
      pid: pid,
      author: author,
      tags: tags
          .map(
            (name) => Tag(
              id: 0,
              name: name,
              translateName: '',
            ),
          )
          .toList(),
      name: title,
      pages: const [],
      bookmarkCount: bookmarkCount,
      isBookmarked: isBookmarked,
      publishedAt: publishedAt,
      updatedAt: 0,
      width: width,
      height: height,
      pageCount: pageCount,
      type: type,
      needsRefresh: false,
      urls: ImageUrlsModel(
        original: '',
        mini: '',
        thumb: thumbUrl,
        small: fallbackSmall,
        regular: fallbackRegular.isNotEmpty ? fallbackRegular : fallbackSmall,
      ),
    );
  }

  static String _deriveSmallFromPixivThumb(String url) {
    return _derivePixivPreviewUrl(url, cropped: true);
  }

  static String _deriveRegularFromPixivThumb(String url) {
    return _derivePixivPreviewUrl(url, cropped: false);
  }

  static String _parseTagName(dynamic rawTag) {
    if (rawTag is String) {
      return rawTag.trim();
    }
    if (rawTag is Map) {
      final tagName = rawTag['name'] ?? rawTag['tag'];
      if (tagName is String && tagName.trim().isNotEmpty) {
        return tagName.trim();
      }
    }
    return '';
  }

  static String _derivePixivPreviewUrl(String url, {required bool cropped}) {
    if (url.isEmpty) {
      return '';
    }

    final targetPrefix =
        cropped ? '/c/540x540_70/img-master/img/' : '/img-master/img/';

    if (url.contains('/custom-thumb/img/')) {
      return url
          .replaceFirst(RegExp(r'/c/[^/]+/custom-thumb/img/'), targetPrefix)
          .replaceFirst(RegExp(r'_(custom|square)1200\.'), '_master1200.');
    }

    if (url.contains('/img-master/img/')) {
      final normalized = url.replaceFirst(
        RegExp(r'/c/[^/]+/img-master/img/'),
        targetPrefix,
      );
      return normalized.replaceFirst(
        RegExp(r'_(custom|square)1200\.'),
        '_master1200.',
      );
    }

    return '';
  }
}
