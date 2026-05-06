class SearchCriteria {
  String authorName;
  String authorUid;
  List<String> tags;
  List<String> excludedTags;
  String sortBy;
  String sortOrder;
  int page;
  int pageSize;
  int? pid;
  int? minBookmarkCount;
  int? maxBookmarkCount;
  bool? isBookmarked;
  DateTime? publishedAfter;
  DateTime? publishedBefore;

  SearchCriteria({
    this.authorName = '',
    this.authorUid = '',
    List<String>? tags,
    List<String>? excludedTags,
    this.sortBy = 'bookmark_count',
    this.sortOrder = 'DESC',
    this.page = 1,
    this.pageSize = 24,
    this.pid,
    this.minBookmarkCount,
    this.maxBookmarkCount,
    this.isBookmarked,
    this.publishedAfter,
    this.publishedBefore,
  })  : tags = List<String>.from(tags ?? const []),
        excludedTags = List<String>.from(excludedTags ?? const []);

  SearchCriteria copy() {
    return SearchCriteria(
      authorName: authorName,
      authorUid: authorUid,
      tags: List<String>.from(tags),
      excludedTags: List<String>.from(excludedTags),
      sortBy: sortBy,
      sortOrder: sortOrder,
      page: page,
      pageSize: pageSize,
      pid: pid,
      minBookmarkCount: minBookmarkCount,
      maxBookmarkCount: maxBookmarkCount,
      isBookmarked: isBookmarked,
      publishedAfter: publishedAfter,
      publishedBefore: publishedBefore,
    );
  }

  void applyFrom(SearchCriteria other) {
    authorName = other.authorName;
    authorUid = other.authorUid;
    tags = List<String>.from(other.tags);
    excludedTags = List<String>.from(other.excludedTags);
    sortBy = other.sortBy;
    sortOrder = other.sortOrder;
    page = other.page;
    pageSize = other.pageSize;
    pid = other.pid;
    minBookmarkCount = other.minBookmarkCount;
    maxBookmarkCount = other.maxBookmarkCount;
    isBookmarked = other.isBookmarked;
    publishedAfter = other.publishedAfter;
    publishedBefore = other.publishedBefore;
  }

  void addTag(String tag) {
    if (tag.isEmpty || tags.contains(tag)) {
      return;
    }
    excludedTags.remove(tag);
    tags.add(tag);
  }

  void addExcludedTag(String tag) {
    if (tag.isEmpty || excludedTags.contains(tag)) {
      return;
    }
    tags.remove(tag);
    excludedTags.add(tag);
  }

  void removeTag(String tag) {
    tags.remove(tag);
  }

  void removeExcludedTag(String tag) {
    excludedTags.remove(tag);
  }

  void toggleTag(String tag) {
    if (tags.contains(tag)) {
      tags.remove(tag);
    } else if (tag.isNotEmpty) {
      excludedTags.remove(tag);
      tags.add(tag);
    }
  }

  void toggleExcludedTag(String tag) {
    if (excludedTags.contains(tag)) {
      excludedTags.remove(tag);
    } else if (tag.isNotEmpty) {
      tags.remove(tag);
      excludedTags.add(tag);
    }
  }

  void clearAuthor() {
    authorName = '';
  }

  void clearAllFilters() {
    authorName = '';
    authorUid = '';
    tags.clear();
    excludedTags.clear();
    pid = null;
    minBookmarkCount = null;
    maxBookmarkCount = null;
    isBookmarked = null;
    publishedAfter = null;
    publishedBefore = null;
    sortBy = 'bookmark_count';
    sortOrder = 'DESC';
    page = 1;
    pageSize = 24;
  }

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'author': authorName,
      'author_uid': authorUid,
      'tags': tags,
      'excluded_tags': excludedTags,
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'page': page,
      'size': pageSize,
    };

    if (pid != null) {
      payload['pid'] = pid;
    }
    if (minBookmarkCount != null) {
      payload['min_bookmark_count'] = minBookmarkCount;
    }
    if (maxBookmarkCount != null) {
      payload['max_bookmark_count'] = maxBookmarkCount;
    }
    if (isBookmarked != null) {
      payload['is_bookmarked'] = isBookmarked;
    }
    if (publishedAfter != null) {
      payload['published_after'] =
          publishedAfter!.millisecondsSinceEpoch ~/ 1000;
    }
    if (publishedBefore != null) {
      payload['published_before'] =
          publishedBefore!.millisecondsSinceEpoch ~/ 1000;
    }

    return payload;
  }

  factory SearchCriteria.fromJson(Map<String, dynamic> json) {
    DateTime? readDate(String key) {
      final raw = json[key];
      if (raw is int && raw > 0) {
        return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
      }
      return null;
    }

    return SearchCriteria(
      authorName: json['author'] as String? ?? '',
      authorUid: json['author_uid'] as String? ?? '',
      tags: List<String>.from(json['tags'] as List? ?? const []),
      excludedTags:
          List<String>.from(json['excluded_tags'] as List? ?? const []),
      sortBy: json['sort_by'] as String? ?? 'bookmark_count',
      sortOrder: json['sort_order'] as String? ?? 'DESC',
      page: json['page'] as int? ?? 1,
      pageSize: json['size'] as int? ?? 24,
      pid: json['pid'] as int?,
      minBookmarkCount: json['min_bookmark_count'] as int?,
      maxBookmarkCount: json['max_bookmark_count'] as int?,
      isBookmarked: json['is_bookmarked'] as bool?,
      publishedAfter: readDate('published_after'),
      publishedBefore: readDate('published_before'),
    );
  }
}

class SearchPreset {
  final String name;
  final SearchCriteria criteria;

  const SearchPreset({
    required this.name,
    required this.criteria,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'criteria': criteria.toJson(),
    };
  }

  factory SearchPreset.fromJson(Map<String, dynamic> json) {
    return SearchPreset(
      name: json['name'] as String? ?? '未命名预设',
      criteria: SearchCriteria.fromJson(
        Map<String, dynamic>.from(json['criteria'] as Map? ?? const {}),
      ),
    );
  }
}
