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