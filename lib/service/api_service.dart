import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:tagselector/model/app_user_model.dart';
import 'package:tagselector/model/author_model.dart';
import 'package:tagselector/model/author_profile_model.dart';
import 'package:tagselector/model/daily_ranking_model.dart';
import 'package:tagselector/model/followed_author_model.dart';
import 'package:tagselector/model/image_model.dart';
import 'package:tagselector/model/image_recommendation_model.dart';
import 'package:tagselector/model/search_model.dart';
import 'package:tagselector/model/system_summary_model.dart';
import 'package:tagselector/model/tag_model.dart';
import 'package:tagselector/service/app_user_session.dart';
import 'package:tagselector/service/http_helper.dart';

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  static const String baseUrl = String.fromEnvironment(
    'PIXIV_HELPER_API_BASE',
    defaultValue: 'https://api.zundamon.bond',
  );

  final HttpHelper _http = HttpHelper.getInstance();
  final Set<String> _avatarRefreshInFlight = <String>{};
  final Map<String, DateTime> _avatarRefreshAttemptedAt = <String, DateTime>{};

  static const Set<int> _transientStatusCodes = {408, 429, 500, 502, 503, 504};
  static const Duration _avatarRefreshCooldown = Duration(minutes: 30);

  Future<AppUsersResponse> fetchAppUsers() async {
    final payload = await _get('/api/users', includeUserHeader: false);
    return AppUsersResponse.fromJson(payload);
  }

  Future<AppUsersResponse> createAppUser({
    required String name,
    String pixivUserId = '',
    bool setActive = true,
  }) async {
    final payload = await _post(
      '/api/users',
      {
        'name': name,
        'pixiv_user_id': pixivUserId,
        'set_active': setActive,
      },
      includeUserHeader: false,
    );
    return AppUsersResponse.fromJson(payload);
  }

  Future<AppUsersResponse> switchAppUser(int userId) async {
    final payload = await _post(
      '/api/users/switch',
      {'user_id': userId},
      includeUserHeader: false,
    );
    return AppUsersResponse.fromJson(payload);
  }

  Future<AppUsersResponse> loginWithSession({
    required String session,
    String name = '',
  }) async {
    final payload = await _post(
      '/api/auth/session',
      {
        'session': session,
        'name': name,
      },
      includeUserHeader: false,
    );
    return AppUsersResponse.fromJson(payload);
  }

  Future<PagedImagesResponse> searchImages(SearchCriteria criteria) async {
    final payload = await _post('/api/image', criteria.toJson());
    final images = (payload['images'] as List? ?? [])
        .map((json) => ImageModel.fromJson(Map<String, dynamic>.from(json)))
        .toList();
    _scheduleAuthorAvatarRefresh(images);
    return PagedImagesResponse(
      images: images,
      total: payload['total'] ?? 0,
    );
  }

  Future<List<ImageModel>> fetchFollowingImages({
    required String userId,
    required int page,
    String mode = 'all',
  }) async {
    final payload = await _post('/api/pixiv/image/following', {
      'userID': userId,
      'page': page,
      'mode': mode,
    });
    final images = (payload['images'] as List? ?? [])
        .map((json) => ImageModel.fromJson(Map<String, dynamic>.from(json)))
        .toList();
    _scheduleAuthorAvatarRefresh(images);
    return images;
  }

  Future<List<ImageModel>> fetchBookmarkImages({
    required String userId,
    required int page,
    String rest = 'hide',
    String mode = 'all',
  }) async {
    final queryParameters = <String, String>{
      'page': '$page',
      'rest': rest,
      'mode': mode,
    };
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isNotEmpty) {
      queryParameters['user_id'] = trimmedUserId;
    }
    final path = Uri(
      path: '/api/pixiv/bookmarks',
      queryParameters: queryParameters,
    ).toString();
    final payload = await _get(path);
    final images = (payload['images'] as List? ?? [])
        .map(
          (json) => ImageRecommendationModel.fromJson(
            Map<String, dynamic>.from(json),
          ).toPlaceholderImage(),
        )
        .toList();
    _scheduleAuthorAvatarRefresh(images);
    return images;
  }

  Future<FollowedAuthorListResponse> fetchFollowingAuthors({
    int offset = 0,
    int limit = 48,
    String sortMode = 'recent_work',
    bool forceRefresh = false,
    String query = '',
  }) async {
    final requestPath = StringBuffer(
      '/api/pixiv/following/authors?offset=$offset&limit=$limit&sort=$sortMode',
    );
    final trimmedQuery = query.trim();
    if (trimmedQuery.isNotEmpty) {
      final encoded = Uri.encodeQueryComponent(trimmedQuery);
      requestPath.write('&query=$encoded');
    }
    if (forceRefresh) {
      requestPath.write('&force=1');
    }
    final payload = await _get(requestPath.toString());
    final authors = (payload['authors'] as List? ?? [])
        .map(
          (json) =>
              FollowedAuthorModel.fromJson(Map<String, dynamic>.from(json)),
        )
        .toList();
    final total = payload['total'] ?? 0;
    final overallTotal = payload['overall_total'] ?? total;
    final safeOffset = payload['offset'] ?? offset;
    final payloadLimit = payload['limit'];
    final safeLimit = math.max(
      1,
      payloadLimit is int ? payloadLimit : limit,
    );
    return FollowedAuthorListResponse(
      authors: authors,
      total: total,
      overallTotal: overallTotal,
      offset: safeOffset,
      limit: safeLimit,
      hasMore: payload['has_more'] ?? false,
      userId: payload['user_id'] ?? '',
      query: payload['query'] ?? trimmedQuery,
    );
  }

  Future<List<String>> fetchTagSuggestions() async {
    final payload = await _post('/api/tag', {
      'page': 1,
      'size': 100000,
    });
    return (payload['tags'] as List? ?? [])
        .map((tag) => Map<String, dynamic>.from(tag)['name'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  Future<List<ExtendedTag>> fetchTagStatistics() async {
    final payload = await _get('/api/tag/tag-statistics');
    return (payload['tags'] as List? ?? [])
        .map((json) => ExtendedTag.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<PixivConnectionInfo> fetchPixivConnectionInfo() async {
    final cookiePayload = await _get('/api/pixiv/cookie');
    String username = '';
    try {
      final userPayload = await _get('/api/pixiv/lognow');
      username = userPayload['username'] ?? '';
    } catch (_) {
      username = '';
    }
    return PixivConnectionInfo(
      cookie: cookiePayload['cookie'] ?? '',
      username: username,
    );
  }

  Future<void> updatePixivCookie(String cookie) async {
    await _post('/api/pixiv/cookie', {'cookie': cookie});
  }

  Future<void> triggerFullRefresh() async {
    await _get('/api/pixiv/image/update', acceptedCodes: {200, 202});
  }

  Future<void> triggerZeroBookmarkRefresh() async {
    await _get('/api/pixiv/image/checker', acceptedCodes: {200, 202});
  }

  Future<List<Author>> refreshAuthorAvatars(
    List<String> uids, {
    bool force = false,
  }) async {
    if (uids.isEmpty) {
      return const [];
    }
    final payload = await _post('/api/author/avatar/refresh', {
      'uids': uids,
      'force': force,
    });
    return (payload['authors'] as List? ?? [])
        .map((json) => Author.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<AuthorProfileModel> fetchAuthorProfile(String uid) async {
    final payload = await _get('/api/author/$uid/profile');
    return AuthorProfileModel.fromJson(payload);
  }

  Future<ImageModel> fetchImageDetail(int pid) async {
    final payload = await _get('/api/image/$pid');
    final image =
        ImageModel.fromJson(Map<String, dynamic>.from(payload['image'] ?? {}));
    _scheduleAuthorAvatarRefresh([image]);
    return image;
  }

  Future<List<ImageRecommendationModel>> fetchImageRecommendations(
    int pid, {
    int limit = 18,
    int offset = 0,
  }) async {
    final payload = await _get(
      '/api/image/$pid/recommendations?limit=$limit&offset=$offset',
    );
    return (payload['images'] as List? ?? [])
        .map(
          (json) => ImageRecommendationModel.fromJson(
            Map<String, dynamic>.from(json),
          ),
        )
        .toList();
  }

  Future<List<ImageRecommendationModel>> fetchDiscoveryRecommendations({
    int limit = 30,
    String mode = 'all',
    Iterable<int> seenPids = const [],
    SearchCriteria? criteria,
  }) async {
    final queryParameters = <String, String>{
      'limit': '$limit',
      'mode': mode,
    };
    final seen = seenPids.where((pid) => pid > 0).toSet();
    if (seen.isNotEmpty) {
      queryParameters['seen'] = seen.join(',');
    }
    if (criteria != null) {
      void putIfNotEmpty(String key, String value) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          queryParameters[key] = trimmed;
        }
      }

      putIfNotEmpty('author', criteria.authorName);
      putIfNotEmpty('author_uid', criteria.authorUid);
      if (criteria.tags.isNotEmpty) {
        queryParameters['tags'] = criteria.tags.join(',');
      }
      if (criteria.excludedTags.isNotEmpty) {
        queryParameters['excluded_tags'] = criteria.excludedTags.join(',');
      }
      if (criteria.pid != null) {
        queryParameters['pid'] = '${criteria.pid}';
      }
      if (criteria.minBookmarkCount != null) {
        queryParameters['min_bookmark_count'] = '${criteria.minBookmarkCount}';
      }
      if (criteria.maxBookmarkCount != null) {
        queryParameters['max_bookmark_count'] = '${criteria.maxBookmarkCount}';
      }
      if (criteria.isBookmarked != null) {
        queryParameters['is_bookmarked'] = '${criteria.isBookmarked}';
      }
      if (criteria.publishedAfter != null) {
        queryParameters['published_after'] =
            '${criteria.publishedAfter!.millisecondsSinceEpoch ~/ 1000}';
      }
      if (criteria.publishedBefore != null) {
        queryParameters['published_before'] =
            '${criteria.publishedBefore!.millisecondsSinceEpoch ~/ 1000}';
      }
    }
    final path = Uri(
      path: '/api/pixiv/discovery/artworks',
      queryParameters: queryParameters,
    ).toString();
    final payload = await _get(path);
    return (payload['images'] as List? ?? [])
        .map(
          (json) => ImageRecommendationModel.fromJson(
            Map<String, dynamic>.from(json),
          ),
        )
        .toList();
  }

  Future<SystemSummaryModel> fetchSystemSummary() async {
    final payload = await _get('/api/system/summary');
    return SystemSummaryModel.fromJson(payload);
  }

  Future<DailyRankingResponse> fetchDailyRanking({
    int page = 1,
    String mode = 'daily',
    String date = '',
  }) async {
    final queryParameters = <String, String>{
      'page': '$page',
      'mode': mode,
    };
    final trimmedDate = date.trim();
    if (trimmedDate.isNotEmpty) {
      queryParameters['date'] = trimmedDate;
    }
    final path = Uri(
      path: '/api/pixiv/ranking/daily',
      queryParameters: queryParameters,
    ).toString();
    final payload = await _get(path);
    final images = (payload['images'] as List? ?? [])
        .map(
          (json) => DailyRankingModel.fromJson(Map<String, dynamic>.from(json)),
        )
        .toList();
    return DailyRankingResponse(
      page: payload['page'] ?? page,
      mode: payload['mode'] ?? mode,
      date: payload['date'] ?? trimmedDate,
      dateLabel: payload['date_label'] ?? '',
      images: images,
    );
  }

  Future<ImageModel> bookmarkImage(
    int pid, {
    bool private = true,
    String comment = '',
    List<String> tags = const [],
  }) async {
    final payload = await _post('/api/image/$pid/bookmark', {
      'private': private,
      'comment': comment,
      'tags': tags,
    });
    final image =
        ImageModel.fromJson(Map<String, dynamic>.from(payload['image'] ?? {}));
    _scheduleAuthorAvatarRefresh([image]);
    return image;
  }

  Future<ImageModel> unbookmarkImage(int pid) async {
    final response = await _http.deleteRequest(
      '$baseUrl/api/image/$pid/bookmark',
      headers: _buildHeaders(includeUserHeader: true),
    );
    final payload = _unwrapResponse(response, const {200});
    final image =
        ImageModel.fromJson(Map<String, dynamic>.from(payload['image'] ?? {}));
    _scheduleAuthorAvatarRefresh([image]);
    return image;
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Set<int> acceptedCodes = const {200},
    bool includeUserHeader = true,
  }) async {
    return _sendWithRetry(
      () => _http.getRequest(
        '$baseUrl$path',
        headers: _buildHeaders(includeUserHeader: includeUserHeader),
      ),
      acceptedCodes,
      retryTransient: true,
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    Set<int> acceptedCodes = const {200},
    bool includeUserHeader = true,
  }) async {
    return _sendWithRetry(
      () => _http.postRequest(
        '$baseUrl$path',
        body,
        headers: _buildHeaders(includeUserHeader: includeUserHeader),
      ),
      acceptedCodes,
      retryTransient: _isReadOnlyPostPath(path),
    );
  }

  Map<String, dynamic>? _buildHeaders({required bool includeUserHeader}) {
    if (!includeUserHeader) {
      return null;
    }
    final userId = AppUserSession.instance.activeUserId;
    if (userId == null || userId <= 0) {
      return null;
    }
    return {'X-App-User-Id': '$userId'};
  }

  Future<Map<String, dynamic>> _sendWithRetry(
    Future<Response> Function() request,
    Set<int> acceptedCodes, {
    required bool retryTransient,
  }) async {
    ApiException? lastApiError;
    Object? lastError;

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await request();
        return _unwrapResponse(response, acceptedCodes);
      } on ApiException catch (error) {
        lastApiError = error;
        if (!retryTransient || !_isTransientStatus(error.statusCode)) {
          rethrow;
        }
      } on DioException catch (error) {
        lastError = error;
        if (!retryTransient) {
          rethrow;
        }
      }

      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 350 * (attempt + 1)));
      }
    }

    if (lastApiError != null) {
      throw lastApiError;
    }
    if (lastError != null) {
      throw ApiException(_friendlyNetworkMessage(lastError), 0);
    }
    throw const ApiException('请求失败，请稍后重试', 500);
  }

  Map<String, dynamic> _unwrapResponse(
    Response response,
    Set<int> acceptedCodes,
  ) {
    final statusCode = response.statusCode ?? 500;
    final payload = _decodePayload(response.data, statusCode: statusCode);
    if (!acceptedCodes.contains(statusCode)) {
      final message = payload['msg'] ??
          payload['error'] ??
          _friendlyStatusMessage(statusCode);
      throw ApiException(message.toString(), statusCode);
    }
    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _decodePayload(dynamic raw, {required int statusCode}) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String) {
      return _decodePayloadString(raw, statusCode: statusCode);
    }
    if (raw is List<int>) {
      return _decodePayloadString(
        utf8.decode(raw, allowMalformed: true),
        statusCode: statusCode,
      );
    }
    throw const ApiException('服务端返回了无法识别的数据', 500);
  }

  Map<String, dynamic> _decodePayloadString(
    String raw, {
    required int statusCode,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return {'msg': _friendlyStatusMessage(statusCode)};
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Cloudflare/Pixiv sometimes returns HTML or plain text for transient
      // 502s. Surface a useful message instead of a JSON "character" error.
    }

    return {'msg': _friendlyStatusMessage(statusCode, rawBody: trimmed)};
  }

  bool _isTransientStatus(int statusCode) {
    return _transientStatusCodes.contains(statusCode);
  }

  bool _isReadOnlyPostPath(String path) {
    return path == '/api/image' ||
        path == '/api/tag' ||
        path == '/api/pixiv/image/following' ||
        path == '/api/pixiv/usr/following' ||
        path == '/api/author/avatar/refresh';
  }

  String _friendlyNetworkMessage(Object error) {
    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('Connection') ||
        text.contains('EOF')) {
      return '网络连接临时中断，请稍后重试';
    }
    return '网络请求失败，请稍后重试';
  }

  String _friendlyStatusMessage(int statusCode, {String rawBody = ''}) {
    switch (statusCode) {
      case 429:
        return 'Pixiv 请求过快，稍等一下再试';
      case 502:
        return '服务临时不可用（502），可能是 Pixiv 或 Cloudflare 抖动，请稍后重试';
      case 503:
        return '服务暂时不可用（503），请稍后重试';
      case 504:
        return '请求超时（504），请稍后重试';
      case 0:
        return '网络请求失败，请检查连接后重试';
    }

    final body = rawBody.trim();
    if (body.isNotEmpty && !body.startsWith('<')) {
      return body.length > 120 ? '${body.substring(0, 120)}...' : body;
    }
    return '请求失败（$statusCode），请稍后重试';
  }

  void _scheduleAuthorAvatarRefresh(List<ImageModel> images) {
    final now = DateTime.now();
    final missingUids = images
        .where(
          (image) =>
              image.author.uid.isNotEmpty &&
              (image.author.avatarUrl.isEmpty ||
                  image.author.avatarNeedsRefresh),
        )
        .map((image) => image.author.uid)
        .where((uid) {
          if (_avatarRefreshInFlight.contains(uid)) {
            return false;
          }
          final lastAttempt = _avatarRefreshAttemptedAt[uid];
          return lastAttempt == null ||
              now.difference(lastAttempt) >= _avatarRefreshCooldown;
        })
        .toSet()
        .toList();

    if (missingUids.isEmpty) {
      return;
    }

    _avatarRefreshInFlight.addAll(missingUids);
    for (final uid in missingUids) {
      _avatarRefreshAttemptedAt[uid] = now;
    }
    unawaited(
      refreshAuthorAvatars(missingUids).whenComplete(
        () => _avatarRefreshInFlight.removeAll(missingUids),
      ),
    );
  }
}

class PagedImagesResponse {
  final List<ImageModel> images;
  final int total;

  const PagedImagesResponse({
    required this.images,
    required this.total,
  });
}

class PixivConnectionInfo {
  final String cookie;
  final String username;

  const PixivConnectionInfo({
    required this.cookie,
    required this.username,
  });
}

class AppUsersResponse {
  final List<AppUserModel> users;
  final AppUserModel? activeUser;

  const AppUsersResponse({
    required this.users,
    required this.activeUser,
  });

  factory AppUsersResponse.fromJson(Map<String, dynamic> json) {
    return AppUsersResponse(
      users: (json['users'] as List? ?? [])
          .map((item) => AppUserModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      activeUser: json['active_user'] is Map
          ? AppUserModel.fromJson(
              Map<String, dynamic>.from(json['active_user']),
            )
          : null,
    );
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  const ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
