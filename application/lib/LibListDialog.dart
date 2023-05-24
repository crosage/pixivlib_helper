import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LibListDialog extends StatefulWidget {
  @override
  _LibListDialogState createState() => _LibListDialogState();
}

class _LibListDialogState extends State<LibListDialog> {
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
