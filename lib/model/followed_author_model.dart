import 'package:tagselector/model/author_model.dart';

class FollowedAuthorModel {
  final Author author;
  final String comment;
  final bool followedBack;
  final bool acceptingCommission;
  final bool premium;
  final int recentWorkPid;
  final String recentWorkTitle;
  final int recentWorkAt;
  final int pixivPreviewCount;
  final List<FollowedAuthorWorkPreview> recentWorks;

  const FollowedAuthorModel({
    required this.author,
    required this.comment,
    required this.followedBack,
    required this.acceptingCommission,
    required this.premium,
    required this.recentWorkPid,
    required this.recentWorkTitle,
    required this.recentWorkAt,
    required this.pixivPreviewCount,
    required this.recentWorks,
  });

  factory FollowedAuthorModel.fromJson(Map<String, dynamic> json) {
    return FollowedAuthorModel(
      author: Author.fromJson(Map<String, dynamic>.from(json['author'] ?? {})),
      comment: json['comment'] ?? '',
      followedBack: json['followed_back'] ?? false,
      acceptingCommission: json['accepting_commission'] ?? false,
      premium: json['premium'] ?? false,
      recentWorkPid: json['recent_work_pid'] ?? 0,
      recentWorkTitle: json['recent_work_title'] ?? '',
      recentWorkAt: json['recent_work_at'] ?? 0,
      pixivPreviewCount: json['pixiv_preview_count'] ?? 0,
      recentWorks: (json['recent_works'] as List? ?? const [])
          .map(
            (item) => FollowedAuthorWorkPreview.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }
}

class FollowedAuthorWorkPreview {
  final int pid;
  final String title;
  final String thumbUrl;
  final int bookmarkCount;
  final bool? isBookmarked;
  final int publishedAt;
  final int width;
  final int height;

  const FollowedAuthorWorkPreview({
    required this.pid,
    required this.title,
    required this.thumbUrl,
    required this.bookmarkCount,
    this.isBookmarked,
    required this.publishedAt,
    required this.width,
    required this.height,
  });

  FollowedAuthorWorkPreview copyWith({
    String? title,
    String? thumbUrl,
    int? bookmarkCount,
    bool? isBookmarked,
    int? publishedAt,
    int? width,
    int? height,
  }) {
    return FollowedAuthorWorkPreview(
      pid: pid,
      title: title ?? this.title,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      bookmarkCount: bookmarkCount ?? this.bookmarkCount,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      publishedAt: publishedAt ?? this.publishedAt,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  factory FollowedAuthorWorkPreview.fromJson(Map<String, dynamic> json) {
    return FollowedAuthorWorkPreview(
      pid: json['pid'] ?? 0,
      title: json['title'] ?? '',
      thumbUrl: json['thumb_url'] ?? '',
      bookmarkCount: json['bookmark_count'] ?? 0,
      isBookmarked: json['is_bookmarked'] as bool?,
      publishedAt: json['published_at'] ?? 0,
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
    );
  }
}

class FollowedAuthorListResponse {
  final List<FollowedAuthorModel> authors;
  final int total;
  final int overallTotal;
  final int offset;
  final int limit;
  final bool hasMore;
  final String userId;
  final String query;

  const FollowedAuthorListResponse({
    required this.authors,
    required this.total,
    required this.overallTotal,
    required this.offset,
    required this.limit,
    required this.hasMore,
    required this.userId,
    required this.query,
  });
}
