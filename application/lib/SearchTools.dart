import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:flutter/material.dart';

class SearchBar extends StatefulWidget {
  final Function(String) onSearchTag;

  const SearchBar({super.key, required this.onSearchTag});

  @override
  _SearchBarState createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  TextEditingController _searchController = TextEditingController();
  List<dynamic> _options = [];
  List<dynamic> _filteredOptions = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      var jsonData = json.encode(<String, dynamic>{"limit": 10000});
      final response = await http
          .post(Uri.parse('http://127.0.0.1:8000/api/tag'), body: jsonData);
      final data = json.decode(utf8.decode(response.bodyBytes));
      //print(data);
      _options = data["tags"];
      //print(_options);
    });
  }

  void _updateFilteredOptions(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredOptions = [];
      } else {
        _filteredOptions = _options
            .where(
                (option) => option.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    //print(_options);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: 10.0),
            Icon(Icons.search),
            SizedBox(width: 10.0),
            Flexible(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '在这里输入Tag',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  _updateFilteredOptions(value);
                },
                onSubmitted: (value) {
                  widget.onSearchTag(value);
                },
              ),
            ),
            IconButton(
              icon: Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _updateFilteredOptions('');
              },
            ),
            SizedBox(width: 10.0),
          ],
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            physics: ClampingScrollPhysics(),
            itemCount: _filteredOptions.length,
            itemBuilder: (BuildContext context, int index) {
              return ListTile(
                title: Text(_filteredOptions[index]),
                onTap: () {
                  _searchController.text = _filteredOptions[index];
                  widget.onSearchTag(_filteredOptions[index]);
                  _updateFilteredOptions('');
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
