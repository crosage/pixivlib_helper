import 'package:tagselector/model/author_model.dart';
import 'package:tagselector/model/image_model.dart';
import 'package:tagselector/model/image_url_model.dart';
import 'package:tagselector/model/tag_model.dart';

class DailyRankingModel {
  final int pid;
  final String title;
  final Author author;
  final String thumbUrl;
  final int bookmarkCount;
  final int pageCount;
  final int width;
  final int height;
  final int publishedAt;
  final List<String> tags;
  final String type;
  final int rank;
  final int previousRank;
  final int viewCount;
  final String dateLabel;

  const DailyRankingModel({
    required this.pid,
    required this.title,
    required this.author,
    required this.thumbUrl,
    required this.bookmarkCount,
    required this.pageCount,
    required this.width,
    required this.height,
    required this.publishedAt,
    required this.tags,
    required this.type,
    required this.rank,
    required this.previousRank,
    required this.viewCount,
    required this.dateLabel,
  });

  factory DailyRankingModel.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'] as List? ?? const [];
    return DailyRankingModel(
      pid: json['pid'] ?? 0,
      title: json['title'] ?? '',
      author: Author.fromJson(Map<String, dynamic>.from(json['author'] ?? {})),
      thumbUrl: json['thumb_url'] ?? '',
      bookmarkCount: json['bookmark_count'] ?? 0,
      pageCount: json['page_count'] ?? 0,
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
      publishedAt: json['published_at'] ?? 0,
      tags: rawTags.map((item) => item.toString()).toList(),
      type: json['type'] ?? '',
      rank: json['rank'] ?? 0,
      previousRank: json['previous_rank'] ?? 0,
      viewCount: json['view_count'] ?? 0,
      dateLabel: json['date_label'] ?? '',
    );
  }

  ImageModel toPlaceholderImage() {
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
      isBookmarked: false,
      publishedAt: publishedAt,
      updatedAt: 0,
      needsRefresh: false,
      urls: ImageUrlsModel(
        original: '',
        mini: '',
        thumb: thumbUrl,
        small: thumbUrl,
        regular: thumbUrl,
      ),
    );
  }
}

class DailyRankingResponse {
  final int page;
  final String mode;
  final String date;
  final String dateLabel;
  final List<DailyRankingModel> images;

  const DailyRankingResponse({
    required this.page,
    required this.mode,
    required this.date,
    required this.dateLabel,
    required this.images,
  });
}
