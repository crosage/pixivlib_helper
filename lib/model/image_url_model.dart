class ImageUrlsModel {
  final String original;
  final String mini;
  final String thumb;
  final String small;
  final String regular;

  ImageUrlsModel({
    required this.original,
    required this.mini,
    required this.thumb,
    required this.small,
    required this.regular,
  });

  factory ImageUrlsModel.fromJson(Map<String, dynamic> json) {
    return ImageUrlsModel(
      original: json['original'] ?? '',
      mini: json['mini'] ?? '',
      thumb: json['thumb'] ?? '',
      small: json['small'] ?? '',
      regular: json['regular'] ?? '',
    );
  }
}