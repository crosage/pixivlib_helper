class SystemSummaryModel {
  final int imageTotal;
  final int authorTotal;
  final int bookmarkedTotal;
  final int unbookmarkedTotal;
  final int recent24hAdded;
  final int cacheTotalBytes;
  final int cacheFileCount;
  final int runningTaskCount;
  final int recentFailureCount;
  final String cachePath;

  const SystemSummaryModel({
    required this.imageTotal,
    required this.authorTotal,
    required this.bookmarkedTotal,
    required this.unbookmarkedTotal,
    required this.recent24hAdded,
    required this.cacheTotalBytes,
    required this.cacheFileCount,
    required this.runningTaskCount,
    required this.recentFailureCount,
    required this.cachePath,
  });

  factory SystemSummaryModel.fromJson(Map<String, dynamic> json) {
    return SystemSummaryModel(
      imageTotal: json['image_total'] ?? 0,
      authorTotal: json['author_total'] ?? 0,
      bookmarkedTotal: json['bookmarked_total'] ?? 0,
      unbookmarkedTotal: json['unbookmarked_total'] ?? 0,
      recent24hAdded: json['recent_24h_added'] ?? 0,
      cacheTotalBytes: json['cache_total_bytes'] ?? 0,
      cacheFileCount: json['cache_file_count'] ?? 0,
      runningTaskCount: json['running_task_count'] ?? 0,
      recentFailureCount: json['recent_failure_count'] ?? 0,
      cachePath: json['cache_path'] ?? '',
    );
  }
}
