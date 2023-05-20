import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:tagselector/utils.dart';

class statefulDialog extends StatefulWidget {
  @override
  _statefulDialogState createState() => _statefulDialogState();
}

class _statefulDialogState extends State<statefulDialog> {
  List<dynamic> libs = [];
  List<bool> isEdting = [];

  @override
  void initState() {
    super.initState();
    for (int i = 1; i <= 100; i++) isEdting.add(false);
  }

  Future<void> getlibs() async {
    final response = await http.get(Uri.parse("http://127.0.0.1:8000/api/lib"));
    Map<String, dynamic> map = json.decode(utf8.decode(response.bodyBytes));
    libs = map["libs"];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: Text("lib"),
        content: FutureBuilder(
          future: getlibs(),
          builder: (context, snapshot) {
            return Container(
              width: 400,
              child: ListView(
                  //shrinkWrap: true,
                  children: [
                    for (int index = 0; index < libs.length; index++)
                      Row(children: [
                        if (isEdting[index] == true)
                          SizedBox(
                              width: 300,
                              child: TextField(
                                decoration: InputDecoration(
                                    hintText: libs[index]["path"].toString()),
                              ))
                        else
                          Text(libs[index]["path"].toString()),
                        IconButton(
                          onPressed: () async {
                            isEdting[index] = !isEdting[index];
                            setState(() {
                              for (int i = 1; i <= 10; i++) print(isEdting[i]);
                            });
//                            final response=await http.post()
                          },
                          icon: Icon(Icons.edit),
                        ),
                        IconButton(
                          onPressed: () async {
                            print("http://127.0.0.1:8000/api/lib/" +
                                libs[index]["id"].toString());
                            final response = await http.delete(Uri.parse(
                                "http://127.0.0.1:8000/api/lib/" +
                                    libs[index]["id"].toString()));
                            setState(() {});
                          },
                          icon: Icon(Icons.delete),
                        ),
                      ]),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text("添加仓库"),
                                  content: TextField(
                                    onSubmitted: (value) async {
                                      var jsonData = json.encode(
                                          <String, dynamic>{"path": value});
                                      final response = await http.post(
                                          Uri.parse(
                                              "http://127.0.0.1:8000/api/lib"),
                                          body: jsonData);
                                      final resp = await http.get(Uri.parse(
                                          "http://127.0.0.1:8000/api/lib"));
                                      Map<String, dynamic> map = json
                                          .decode(utf8.decode(resp.bodyBytes));
                                      libs = map["libs"];
                                      setState(() {});
                                    },
                                  ),
                                );
                              });
                        },
                      ),
                    ),
                  ]),
            );
          },
        ));
  }
}

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
          var jsonData = json.encode(<String, dynamic>{});
          final response = await http
              .post(Uri.parse('http://127.0.0.1:8000/api/tag'), body: jsonData);
          final data = json.decode(utf8.decode(response.bodyBytes));
          setState(() {
            tags = data["tags"];
            for (int i = 0; i < tags.length; i++) {
              filterChips.add(FilterChip(
                label: Text(tags[i]),
                selected: true,
                onSelected: (isSelected) {
                  _handleTagSelection(i);
                },
              ));
            }
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
                return statefulDialog();
              });
        }
      },
    );
  }
}
