class Author {
  int id;
  String name;
  String uid;
  String avatarUrl;
  int avatarUpdatedAt;
  bool avatarNeedsRefresh;

  Author({
    required this.id,
    required this.name,
    required this.uid,
    required this.avatarUrl,
    required this.avatarUpdatedAt,
    required this.avatarNeedsRefresh,
  });

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      uid: json['uid'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
      avatarUpdatedAt: json['avatar_updated_at'] ?? 0,
      avatarNeedsRefresh: json['avatar_needs_refresh'] ?? false,
    );
  }
}
