import 'package:tagselector/model/author_model.dart';
import 'package:tagselector/model/followed_author_model.dart';

class AuthorProfileModel {
  final Author author;
  final AuthorProfileDetails profile;
  final List<String> pixivRecentIds;
  final int pixivPreviewCount;
  final List<FollowedAuthorWorkPreview> recentWorks;
  final AuthorSyncSummary syncSummary;

  const AuthorProfileModel({
    required this.author,
    required this.profile,
    required this.pixivRecentIds,
    required this.pixivPreviewCount,
    required this.recentWorks,
    required this.syncSummary,
  });

  factory AuthorProfileModel.fromJson(Map<String, dynamic> json) {
    final recentIds = json['pixiv_recent_ids'] as List? ?? [];

    return AuthorProfileModel(
      author: Author.fromJson(Map<String, dynamic>.from(json['author'] ?? {})),
      profile: AuthorProfileDetails.fromJson(
        Map<String, dynamic>.from(json['profile'] ?? {}),
      ),
      pixivRecentIds: recentIds.map((id) => id.toString()).toList(),
      pixivPreviewCount: json['pixiv_preview_count'] ?? recentIds.length,
      recentWorks: (json['recent_works'] as List? ?? const [])
          .map(
            (item) => FollowedAuthorWorkPreview.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      syncSummary: AuthorSyncSummary.fromJson(
        Map<String, dynamic>.from(json['sync_summary'] ?? {}),
      ),
    );
  }
}

class AuthorProfileDetails {
  final String comment;
  final String webpage;
  final String twitterUrl;
  final String backgroundUrl;
  final bool isFollowed;
  final int followers;
  final int following;
  final int illusts;
  final int manga;
  final int works;

  const AuthorProfileDetails({
    required this.comment,
    required this.webpage,
    required this.twitterUrl,
    required this.backgroundUrl,
    required this.isFollowed,
    required this.followers,
    required this.following,
    required this.illusts,
    required this.manga,
    required this.works,
  });

  factory AuthorProfileDetails.fromJson(Map<String, dynamic> json) {
    return AuthorProfileDetails(
      comment: json['comment'] ?? '',
      webpage: json['webpage'] ?? '',
      twitterUrl: json['twitter_url'] ?? '',
      backgroundUrl: json['background_url'] ?? '',
      isFollowed: json['is_followed'] ?? false,
      followers: json['followers'] ?? 0,
      following: json['following'] ?? 0,
      illusts: json['illusts'] ?? 0,
      manga: json['manga'] ?? 0,
      works: json['works'] ?? 0,
    );
  }
}

class AuthorSyncSummary {
  final int checked;
  final int existing;
  final int queued;
  final int imported;
  final int failed;
  final bool inProgress;

  const AuthorSyncSummary({
    required this.checked,
    required this.existing,
    required this.queued,
    required this.imported,
    required this.failed,
    required this.inProgress,
  });

  factory AuthorSyncSummary.fromJson(Map<String, dynamic> json) {
    return AuthorSyncSummary(
      checked: json['checked'] ?? 0,
      existing: json['existing'] ?? 0,
      queued: json['queued'] ?? 0,
      imported: json['imported'] ?? 0,
      failed: json['failed'] ?? 0,
      inProgress: json['in_progress'] ?? false,
    );
  }
}
