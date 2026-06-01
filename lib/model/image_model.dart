import 'package:tagselector/model/page_model.dart';
import 'package:tagselector/model/tag_model.dart';

import 'author_model.dart';
import 'image_url_model.dart';

class ImageModel {
  final int id;
  final int pid;
  final Author author;
  final List<Tag> tags;
  final String name;
  final List<Page> pages;
  final int bookmarkCount;
  final bool isBookmarked;
  final int publishedAt;
  final int updatedAt;
  final int width;
  final int height;
  final bool needsRefresh;
  final String type;
  final ImageUrlsModel urls;

  const ImageModel({
    required this.id,
    required this.pid,
    required this.author,
    required this.tags,
    required this.name,
    required this.pages,
    required this.bookmarkCount,
    required this.isBookmarked,
    required this.publishedAt,
    required this.updatedAt,
    this.width = 0,
    this.height = 0,
    required this.needsRefresh,
    this.type = '',
    required this.urls,
  });

  ImageModel copyWith({
    int? id,
    int? pid,
    Author? author,
    List<Tag>? tags,
    String? name,
    List<Page>? pages,
    int? bookmarkCount,
    bool? isBookmarked,
    int? publishedAt,
    int? updatedAt,
    int? width,
    int? height,
    bool? needsRefresh,
    String? type,
    ImageUrlsModel? urls,
  }) {
    return ImageModel(
      id: id ?? this.id,
      pid: pid ?? this.pid,
      author: author ?? this.author,
      tags: tags ?? this.tags,
      name: name ?? this.name,
      pages: pages ?? this.pages,
      bookmarkCount: bookmarkCount ?? this.bookmarkCount,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      publishedAt: publishedAt ?? this.publishedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      width: width ?? this.width,
      height: height ?? this.height,
      needsRefresh: needsRefresh ?? this.needsRefresh,
      type: type ?? this.type,
      urls: urls ?? this.urls,
    );
  }

  factory ImageModel.fromJson(Map<String, dynamic> json) {
    final tagsList = json['tags'] as List? ?? [];
    final pagesList = json['pages'] as List? ?? [];
    return ImageModel(
      id: json['id'] ?? 0,
      pid: json['pid'] ?? 0,
      author: Author.fromJson(Map<String, dynamic>.from(json['author'] ?? {})),
      tags: tagsList
          .map((tagJson) => Tag.fromJson(Map<String, dynamic>.from(tagJson)))
          .toList(),
      name: json['name'] ?? '',
      pages: pagesList
          .map((pageJson) => Page.fromJson(Map<String, dynamic>.from(pageJson)))
          .toList(),
      bookmarkCount: json['bookmark_count'] ?? 0,
      isBookmarked: json['is_bookmarked'] ?? false,
      publishedAt: json['published_at'] ?? 0,
      updatedAt: json['updated_at'] ?? 0,
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
      needsRefresh: json['needs_refresh'] ?? false,
      type: json['type'] ?? json['illust_type']?.toString() ?? '',
      urls: ImageUrlsModel.fromJson(
          Map<String, dynamic>.from(json['urls'] ?? {})),
    );
  }
}
