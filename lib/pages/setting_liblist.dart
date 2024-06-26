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
    final response = await http.get(Uri.parse("http://127.0.0.1:23333/api/gallery"));
    Map<String, dynamic> map = json.decode(utf8.decode(response.bodyBytes));
    libs = map["data"]["galleries"];
    print("222222");
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "仓库列表",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 32.0,
          ),
        ),
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
                      Padding(
                        padding: EdgeInsets.only(left: 16.0),
                        child: ModifyText(
                          hintText: libs[index]["path"].toString(),
                          onDelete: () async {
                            print("http://127.0.0.1:23333/api/gallery" +
                                libs[index]["id"].toString());
                            final response = await http.delete(Uri.parse(
                                "http://127.0.0.1:23333/api/gallery" +
                                    libs[index]["id"].toString()));
                            setState(() {});
                          },
                          onUpdate: () {},
                        ),
                      ),
                    Align(
                      alignment: Alignment.bottomLeft,
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
                                              "http://127.0.0.1:23333/api/gallery"),
                                          body: jsonData);
                                      final resp = await http.get(Uri.parse(
                                          "http://127.0.0.1:23333/api/gallery"));
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
                    Row(children: [
                      Icon(Icons.accessible_forward),
                      InkWell(
                        onTap: () async {
                          final response = await http.get(
                              Uri.parse("http://127.0.0.1:23333/api/gallery/init"));
                        },
                        child: Text(
                          "爬取图片tag",
                          style: TextStyle(fontSize: 30.0),
                        ),
                      ),
                    ]),
                  ]),
            );
          },
        ),
      ],
    );
  }
}
