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
  final bool local;
  final ImageUrlsModel urls;

  ImageModel({
    required this.id,
    required this.pid,
    required this.author,
    required this.tags,
    required this.name,
    required this.pages,
    required this.bookmarkCount,
    required this.isBookmarked,
    required this.local,
    required this.urls,
  });

  factory ImageModel.fromJson(Map<String, dynamic> json) {
    print("处理开始");
    Author author = Author.fromJson(json['author']);
    var tagsList = json['tags'] as List?;
    List<Tag> tags = tagsList?.map((tagJson) => Tag.fromJson(tagJson)).toList() ?? [];
    var pagesList = json['pages'] as List?;
    List<Page> pages = pagesList?.map((pageJson) => Page.fromJson(pageJson)).toList() ?? [];
    ImageUrlsModel urls = ImageUrlsModel.fromJson(json['urls'] ?? {});
    print("处理结束");
    print("${urls.original}");
    return ImageModel(
      id: json['id'] ?? 0,
      pid: json['pid'] ?? 0,
      author: author,
      tags: tags,
      name: json['name'] ?? '',
      pages: pages,
      bookmarkCount: json['bookmark_count'] ?? 0,
      isBookmarked: json['is_bookmarked'] ?? false,
      local: json['local'] ?? false,
      urls: urls,
    );
  }
}