class Tag {
  int id;
  String name;
  String translateName;

  Tag({
    required this.id,
    required this.name,
    required this.translateName,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'],
      name: json['name'],
      translateName: json['translate_name'],
    );
  }
}

class ExtendedTag extends Tag {
  int count;

  ExtendedTag({
    required int id,
    required String name,
    String? translateName, // 允许为null
    required this.count,
  }) : super(id: id, name: name, translateName: translateName ?? '');

  factory ExtendedTag.fromJson(Map<String, dynamic> json) {
    return ExtendedTag(
      id: json['id'],
      name: json['name'],
      translateName: json['translate_name'],
      count: json['count'],
    );
  }
}
