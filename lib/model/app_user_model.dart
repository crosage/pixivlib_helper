class AppUserModel {
  final int id;
  final String name;
  final String pixivUserId;
  final bool isActive;
  final int createdAt;
  final int updatedAt;

  const AppUserModel({
    required this.id,
    required this.name,
    required this.pixivUserId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppUserModel.fromJson(Map<String, dynamic> json) {
    return AppUserModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      pixivUserId: json['pixiv_user_id'] ?? '',
      isActive: json['is_active'] ?? false,
      createdAt: json['created_at'] ?? 0,
      updatedAt: json['updated_at'] ?? 0,
    );
  }
}
