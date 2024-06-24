class SearchCriteria {
  String _authorName;
  List<String> _tags;
  String _sortBy;
  String _sortOrder;
  int _page;
  int _pageSize;

  SearchCriteria({
    String authorName = '',
    List<String> tags = const [],
    String sortBy = 'pid',
    String sortOrder = 'DESC',
    int page = 1,
    int pageSize = 10,
  })  : _authorName = authorName,
        _tags = List.from(tags),
        _sortBy = sortBy,
        _sortOrder = sortOrder,
        _page = page,
        _pageSize = pageSize;

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

  // Getter and Setter for page
  int get page => _page;
  set page(int value) {
    _page = value;
  }

  // Getter and Setter for pageSize
  int get pageSize => _pageSize;
  set pageSize(int value) {
    _pageSize = value;
  }
  
  void addTag(String tag) {
    if (!_tags.contains(tag)) {
      _tags.add(tag);
    }
  }
  
  void removeTag(String tag) {
    _tags.remove(tag);
  }

  void handleTag(String tag){
    if (!_tags.contains(tag)) {
      _tags.add(tag);
    }else {
      _tags.remove(tag);
    }
  }
  
  factory SearchCriteria.fromJson(Map<String, dynamic> json) {
    return SearchCriteria(
      authorName: json['authorName'] ?? '',
      tags: List<String>.of(json['tags'] ?? []),
      sortBy: json['sortBy'] ?? 'pid',
      sortOrder: json['sortOrder'] ?? 'DESC',
      page: json['page'] ?? 1,
      pageSize: json['pageSize'] ?? 10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'author': _authorName,
      'tags': _tags,
      'sort_by': _sortBy,
      'sort_order': _sortOrder,
      'page': _page,
      'size': _pageSize,
    };
  }
}
