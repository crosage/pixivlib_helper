import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:tagselector/components/page_bottombar.dart';
import 'package:tagselector/components/search_tool.dart';
import 'package:tagselector/utils.dart';

class ImageGrid extends StatefulWidget {
  @override
  _ImageGridState createState() => _ImageGridState();
}

class _ImageGridState extends State<ImageGrid> {
  late int _index;
  late int pages;
  late List<String> selectedTags;

  @override
  void initState() {
    super.initState();
    selectedTags = [];
    _index = 0;
    pages = 0;
  }

  Future<int> getCountAndPages() async {
    int limit = 8 * 3, offset = _index * 8 * 3, pages = 0;
    var jsonData = json.encode(<String, dynamic>{
      "limit": limit,
      "offset": offset,
      "tag": selectedTags
    });
    final response = await http
        .post(Uri.parse('http://localhost:8000/api/image'), body: jsonData);
    if (response.statusCode == 200) {
      Map<String, dynamic> map = json.decode(utf8.decode(response.bodyBytes));
      pages = map["pages"];
    }
    print(pages);
    return pages;
  }

  Future<List<String>> getTagSuggestions() async {
    var jsonData = json.encode(<String, dynamic>{"limit": 10000});
    final response = await http.post(Uri.parse('http://127.0.0.1:8000/api/tag'),
        body: jsonData);
    final data = json.decode(utf8.decode(response.bodyBytes));
    return List<String>.from(data["tags"]);
  }

  Future<List<dynamic>> getImages() async {
    int limit = 8 * 3, offset = _index * 8 * 3;
    print("***********");
    var jsonData = json.encode(<String, dynamic>{
      "limit": limit,
      "offset": offset,
      "tag": selectedTags
    });
    final response = await http
        .post(Uri.parse('http://localhost:8000/api/image'), body: jsonData);
    if (response.statusCode == 200) {
      Map<String, dynamic> map = json.decode(utf8.decode(response.bodyBytes));
      final List<dynamic> images = map['images'];
      pages = map["pages"];
      return images;
    } else {
      return [];
    }
  }

  void _searchTag(String value) {
    setState(() {
      selectedTags.add(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF5bc2e7),
        title: Text('Grid View'),
      ),
      body: Row(
        children: [
          Container(
            width: MediaQuery.of(context).size.width - 50,
            child: Column(
              children: [
                FutureBuilder<List<String>>(
                  future: getTagSuggestions(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    } else {
                      return SearchTool(
                          onSelected: _searchTag, suggestions: snapshot.data!);
                    }
                  },
                ),
                Wrap(
                  spacing: 5,
                  children: [
                    for (int i = 0; i < selectedTags.length; i++)
                      FilterChip(
                        label: Text(selectedTags[i]),
                        selected: true,
                        onSelected: (isSelected) {
                          setState(() {
                            print("pages=" + pages.toString());
                            selectedTags.removeAt(i);
                          });
                        },
                        selectedColor: getRandomColor(selectedTags[i].hashCode),
                      ),
                  ],
                ),
                Container(
                  height: MediaQuery.of(context).size.height - 200,
                  child: FutureBuilder<List<dynamic>>(
                    future: getImages(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(
                          child: CircularProgressIndicator(),
                        );
                      } else {
                        // print(snapshot.data);
                        return GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 8),
                            itemCount: snapshot.data!.length,
                            itemBuilder: (BuildContext context, int index) {
                              // final now = index;
                              // print(snapshot.data![index]);
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                      child: Image.file(File(
                                          snapshot.data![index]["path"] +
                                              "\\" +
                                              snapshot.data![index]["name"]))),
                                  TextButton(
                                    onPressed: () {},
                                    child: Text(
                                      "pid:${snapshot.data![index]["pid"]}",
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {},
                                    child: Text(
                                      "auther:${snapshot.data![index]["author"]}",
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ),
                                ],
                              );
                            });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: FutureBuilder(
        future: getCountAndPages(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: LinearProgressIndicator(
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(Colors.blue),
              ),
            );
          } else {
            print(pages);
            return PageBottomBar(
                onPageChange: (value) {
                  setState(() {
                    _index = value;
                  });
                },
                totalPages: pages);
          }
        },
      ),
    );
  }
}
