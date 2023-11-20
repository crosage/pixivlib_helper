import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tagselector/components/search_tool.dart';
import 'dart:convert';

class TagList extends StatefulWidget {
  @override
  _TagListState createState() => _TagListState();
}

class _TagListState extends State<TagList> {
  late List<dynamic> tags;
  late List<dynamic> selectedTags;
  List<FilterChip> filterChips = [];
  late List<String> suggestions;

  int _tagIndex = 0;
  TextEditingController bottomPageController = TextEditingController();

  Future<List<String>> getTagSuggestions() async {
    var jsonData = json.encode(<String, dynamic>{"limit": 10000});
    final response = await http.post(Uri.parse('http://127.0.0.1:8000/api/tag'),
        body: jsonData);
    final data = json.decode(utf8.decode(response.bodyBytes));
    return List<String>.from(data["tags"]);
  }

  @override
  void initState() {
    super.initState();
    getTags();
  }

  void _onSelectTag(String s) {}

  Future<void> getTags() async {
    var jsonData =
        json.encode(<String, dynamic>{"limit": 50, "offset": _tagIndex * 50});
    final response = await http.post(Uri.parse('http://127.0.0.1:8000/api/tag'),
        body: jsonData);
    final data = json.decode(utf8.decode(response.bodyBytes));
    tags = data["tags"];
    filterChips.clear();
    for (int i = 0; i < tags.length; i++) {
      filterChips.add(FilterChip(
        label: Text(tags[i]),
        selected: true,
        onSelected: (isSelected) {
          _onSelectTag(tags[i]);
        },
      ));
    }
    print("111111111111111111");
  }

  void _lastPage() {
    setState(() {
      _tagIndex = _tagIndex > 0 ? _tagIndex - 1 : 0;
    });
  }

  void _nextPage() {
    setState(() {
      _tagIndex = _tagIndex + 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 1000,
          child: FutureBuilder(
            future: getTags(),
            builder: (context, snapshot) {
              return ListView(shrinkWrap: true, children: [
                FutureBuilder<List<String>>(
                  future: getTagSuggestions(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    } else {
                      return SearchTool(
                          onSelected: _onSelectTag,
                          suggestions: snapshot.data!);
                    }
                  },
                ),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: filterChips,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                        onPressed: _lastPage, icon: Icon(Icons.arrow_back)),
                    Container(
                        width: 50,
                        child: TextField(
                          controller: bottomPageController,
                          decoration: InputDecoration(
                            hintText: (_tagIndex + 1).toString(),
                          ),
                          textAlign: TextAlign.center,
                          onSubmitted: (value) {
                            _tagIndex = int.parse(value) - 1;
                            setState(() {
                              bottomPageController.clear();
                            });
                          },
                        )),
                    IconButton(
                        onPressed: _nextPage, icon: Icon(Icons.arrow_forward)),
                  ],
                )
              ]);
            },
          ),
        ),
      ],
    );
  }
}
