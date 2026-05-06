class Page {
  int id;
  int imageId;
  int pageId;

  Page({
    required this.id,
    required this.imageId,
    required this.pageId,
  });

  factory Page.fromJson(Map<String, dynamic> json) {
    return Page(
      id: json['id'] ?? 0,
      imageId: json['image_id'] ?? 0,
      pageId: json['page_id'] ?? 0,
    );
  }
}
