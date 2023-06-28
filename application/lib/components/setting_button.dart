import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tagselector/components/lib_list_dialog.dart';
import 'package:tagselector/components/search_tool.dart';
import 'dart:convert';

import 'package:tagselector/components/tag_list_dialog.dart';

class dropDownButton extends StatefulWidget {
  @override
  _dropDownButtonState createState() => _dropDownButtonState();
}

class _dropDownButtonState extends State<dropDownButton> {
  void _handleTagSelection(int index) {}

  void _onSelectTag(String s) {}

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.settings),
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
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return TagListDialog();
            },
          );
        }
        if (value == "初始化仓库") {
          final response =
              await http.get(Uri.parse('http://127.0.0.1:8000/api/lib/init'));
        }
        if (value == "仓库列表") {
          final response =
              await http.get(Uri.parse("http://127.0.0.1:8000/api/lib"));
          Map<String, dynamic> map =
              json.decode(utf8.decode(response.bodyBytes));
          List<dynamic> libs = map["libs"];
          print(libs);
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return LibListDialog();
            },
          );
        }
      },
    );
  }
}
