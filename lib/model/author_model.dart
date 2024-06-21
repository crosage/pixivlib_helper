class Author {
  int id;
  String name;
  String uid;

  Author({
    required this.id,
    required this.name,
    required this.uid,
  });

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      id: json['id'],
      name: json['name'],
      uid: json['uid'],
    );
  }
}
