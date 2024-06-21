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
      id: json['id'],
      imageId: json['image_id'],
      pageId: json['page_id'],
    );
  }
}