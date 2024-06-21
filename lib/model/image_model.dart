import 'package:tagselector/model/page_model.dart';
import 'package:tagselector/model/tag_model.dart';
import 'author_model.dart';

class ImageModel {
  int id;
  int pid;
  Author author;
  List<Tag> tags;
  String name;
  String path;
  List<Page> pages;
  String fileType;

  ImageModel({
    required this.id,
    required this.pid,
    required this.author,
    required this.tags,
    required this.name,
    required this.path,
    required this.pages,
    required this.fileType,
  });

  factory ImageModel.fromJson(Map<String, dynamic> json) {
    // Parse author
    Author author = Author.fromJson(json['author']);

    // Parse tags
    var tagsList = json['tags'] as List;
    List<Tag> tags = tagsList.map((tagJson) => Tag.fromJson(tagJson)).toList();

    // Parse pages
    var pagesList = json['pages'] as List;
    List<Page> pages = pagesList.map((pageJson) => Page.fromJson(pageJson)).toList();

    return ImageModel(
      id: json['id'],
      pid: json['pid'],
      author: author,
      tags: tags,
      name: json['name'],
      path: json['path'],
      pages: pages,
      fileType: json['file_type'],
    );
  }
}