import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tagselector/SearchTools.dart';
import 'dart:convert';

class TagListDialog extends StatefulWidget {
  @override
  _TagListDialogState createState() => _TagListDialogState();
}

class _TagListDialogState extends State<TagListDialog> {
  late List<dynamic> tags;
  late List<dynamic> selectedTags;
  List<FilterChip> filterChips = [];
  int _tagIndex = 0;
  TextEditingController bottomPageController = TextEditingController();

  void _onSelectTag(int i) {}

  Future<void> getTags() async {
    var jsonData =
        json.encode(<String, dynamic>{"limit": 20, "offset": _tagIndex * 20});
    final response = await http.post(Uri.parse('http://127.0.0.1:8000/api/tag'),
        body: jsonData);
    final data = json.decode(utf8.decode(response.bodyBytes));
    setState(() {
      tags = data["tags"];
      filterChips.clear();
      for (int i = 0; i < tags.length; i++) {
        filterChips.add(FilterChip(
          label: Text(tags[i]),
          selected: true,
          onSelected: (isSelected) {
            _onSelectTag(i);
          },
        ));
      }
    });
  }

  void _lastPage() {
    setState(() {
      _tagIndex = _tagIndex > 0 ? _tagIndex - 1 : 0;
    });
  }

  void _onSearchTag(String s) {}

  void _nextPage() {
    setState(() {
      _tagIndex = _tagIndex + 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Filters'),
      content: Container(
          width: 400,
          // Set the height of the container to control the height of the AlertDialog
          child: FutureBuilder(
              future: getTags(),
              builder: (context, snapshot) {
                return ListView(shrinkWrap: true, children: [
                  Container(
                    height: 96,
                    child: SearchBar(
                      onSearchTag: _onSearchTag,
                    ),
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
                          onPressed: _nextPage,
                          icon: Icon(Icons.arrow_forward)),
                    ],
                  )
                ]);
              })),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close'),
        ),
      ],
    );
  }
}
