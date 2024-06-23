class SearchCriteria {
  String _authorName;
  List<String> _tags;
  String _sortBy;
  String _sortOrder;

  SearchCriteria({
    String authorName = '',
    List<String> tags = const [],
    String sortBy = 'pid',
    String sortOrder = 'DESC',
  })  : _authorName = authorName,
        _tags = tags,
        _sortBy = sortBy,
        _sortOrder = sortOrder;

  // Getter and Setter for authorName
  String get authorName => _authorName;
  set authorName(String value) {
    _authorName = value;
  }

  // Getter and Setter for tags
  List<String> get tags => _tags;
  set tags(List<String> value) {
    _tags = value;
  }

  // Getter and Setter for sortBy
  String get sortBy => _sortBy;
  set sortBy(String value) {
    _sortBy = value;
  }

  // Getter and Setter for sortOrder
  String get sortOrder => _sortOrder;
  set sortOrder(String value) {
    _sortOrder = value;
  }

  factory SearchCriteria.fromJson(Map<String, dynamic> json) {
    return SearchCriteria(
      authorName: json['authorName'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      sortBy: json['sortBy'] ?? 'pid',
      sortOrder: json['sortOrder'] ?? 'DESC',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'authorName': _authorName,
      'tags': _tags,
      'sortBy': _sortBy,
      'sortOrder': _sortOrder,
    };
  }
}
