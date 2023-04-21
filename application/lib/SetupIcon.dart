import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:tagselector/utils.dart';

class dropDownButton extends StatefulWidget {
  @override
  _dropDownButtonState createState() => _dropDownButtonState();
}

class _dropDownButtonState extends State<dropDownButton> {
  late List<dynamic> tags;
  late List<dynamic> selectedTags;
  List<FilterChip> filterChips = [];

  void _handleTagSelection(int index) {}

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      itemBuilder: (BuildContext context) {
        return [
          PopupMenuItem<String>(
            value: 'Tag列表',
            child: Text('Tag列表'),
          ),
          PopupMenuItem<String>(
            value: "仓库列表",
            child: Text('仓库列表'),
          ),
          PopupMenuItem<String>(
            value: '初始化仓库',
            child: Text('初始化仓库'),
          ),
        ];
      },
      onSelected: (String value) async {
        if (value == "Tag列表") {
          var jsonData = json.encode(<String, dynamic>{
          });
          final response =
              await http.post(Uri.parse('http://127.0.0.1:8000/api/tag'),body:jsonData);
          final data = json.decode(utf8.decode(response.bodyBytes));
          setState(() {
            tags = data["tags"];
            print("*************************");
            for (int i = 0; i < tags.length; i++) {
              filterChips.add(FilterChip(
                label: Text(tags[i]),
                selected: true,
                onSelected: (isSelected) {
                  _handleTagSelection(i);
                },
              ));
            }
            print("#############################");
            print(filterChips);
          });
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Filters'),
                content: Container(
                  height: 200.0,
                  // Set the height of the container to control the height of the AlertDialog
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: filterChips,
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close'),
                  ),
                ],
              );
            },
          );
        }
        if(value=="初始化仓库"){
          final response = await http.get(Uri.parse('http://127.0.0.1:8000/api/lib'));
        }
      },
    );
  }
}
