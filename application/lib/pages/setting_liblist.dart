import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:tagselector/components/modify_text.dart';

class LibList extends StatefulWidget {
  @override
  _LibListState createState() => _LibListState();
}

class _LibListState extends State<LibList> {
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
    print("222222");
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(),
        Text(
          "仓库列表",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20.0,
          ),
        ),
        Divider(),
        FutureBuilder(
          future: getlibs(),
          builder: (context, snapshot) {
            return Container(
              width: MediaQuery.of(context).size.width - 400,
              height: MediaQuery.of(context).size.height - 200,
              child: ListView(
                  //shrinkWrap: true,
                  children: [
                    for (int index = 0; index < libs.length; index++)
                      ModifyText(
                        hintText: libs[index]["path"].toString(),
                        onDelete: () async {
                          print("http://127.0.0.1:8000/api/lib/" +
                              libs[index]["id"].toString());
                          final response = await http.delete(Uri.parse(
                              "http://127.0.0.1:8000/api/lib/" +
                                  libs[index]["id"].toString()));
                          setState(() {});
                        },
                        onUpdate: () {},
                      ),
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
        ),
      ],
    );
  }
}
