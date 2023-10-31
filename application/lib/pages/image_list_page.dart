import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tagselector/components/image_with_info.dart';
import 'package:tagselector/components/page_bottombar.dart';
import 'package:tagselector/components/search_tool.dart';
import 'package:tagselector/components/sidebar.dart';
import 'package:tagselector/utils.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ImageListPage extends StatefulWidget {
  @override
  _ImageListPageState createState() => _ImageListPageState();
}

class _ImageListPageState extends State<ImageListPage> {
  late List<String> selectedTags;
  ScrollController _scrollController = ScrollController();
  late int _index;
  TextEditingController bottomPageController = TextEditingController();
  int pages = 0;
  String searchHelperForWindows = "";
  late Future<List<dynamic>> values;

  // List<String> suggestions = [];
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
    selectedTags = [];
    _index = 0;
    pages = 0;
    _scrollController = ScrollController();
    values = getImages();
  }

  void _searchTag(String value) {
    setState(() {
      selectedTags.add(value);
    });
  }

  Future<int> getCountAndPages() async {
    int limit = 20, offset = _index * 20, pages = 0;
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
    }
    return pages;
  }

  void _handleSelectedTags(String tag) {
    setState(() {
      print("pages=" + pages.toString());
      _index = 0;
      if (selectedTags.contains(tag)) {
        selectedTags.removeWhere((item) => item == tag);
      } else {
        selectedTags.add(tag);
      }
    });
  }

  Future<List<dynamic>> getImages() async {
    int limit = 20, offset = _index * 20;
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
      searchHelperForWindows = "";
      for (final image in images) {
        int pid = image['pid'];
        searchHelperForWindows =
            searchHelperForWindows + pid.toString() + " OR ";
        final resp = await http.get(
            Uri.parse('http://localhost:8000/api/image/' + pid.toString()));
        List<dynamic> tags = json.decode(utf8.decode(resp.bodyBytes))['tags'];
        image["tags"] = tags;
      }
      return images;
    } else {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF5bc2e7),
        title: Text('pixiv_helper'),
      ),
      body: Row(
        children: [
          Container(
            width: MediaQuery.of(context).size.width - 60,
            child: Column(
              children: [
                FutureBuilder<List<String>>(
                    future: getTagSuggestions(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      } else {
                        print(snapshot.data!);
                        return SearchTool(
                            onSelected: _searchTag,
                            suggestions: snapshot.data!);
                      }
                    }),
                Row(
                  children: [
                    Flexible(
                      flex: 1,
                      child: Wrap(
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
                              selectedColor:
                                  getRandomColor(selectedTags[i].hashCode),
                            ),
                        ],
                      ),
                    ),
                    Flexible(
                      flex: 0,
                      child: IconButton(
                        icon: Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: searchHelperForWindows),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 5,
                ),
                FutureBuilder<List<dynamic>>(
                  future: getImages(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Flexible(
                        child: ListView(
                          controller: _scrollController,
                          children: [
                            Row(
                              children: [
                                RawChip(
                                  avatar: Icon(
                                    Icons.access_alarm,
                                    color: Colors.blue,
                                  ),
                                  label: Text(
                                    "Cnt:" + snapshot.data!.length.toString(),
                                  ),
                                ),
                              ],
                            ),
                            for (final i in snapshot.data!)
                              ImageWithInfo(
                                imageUrl: i["path"] + "\\" + i["name"],
                                page: i["page"],
                                pid: i["pid"],
                                tags: i["tags"],
                                author: i["author"],
                                onSelectedTagsChanged: _handleSelectedTags,
                                selectedTags: selectedTags,
                              ),
                          ],
                        ),
                      );
                    }
                    return Center(
                      child: CircularProgressIndicator(),
                    );
                  },
                ),
              ],
            ),
          ),
          VerticalDivider(),
          Sidebar(
            iconButtons: [
              IconButton(
                onPressed: () {
                  Get.toNamed("/setting");
                },
                icon: Icon(Icons.settings),
              ),
              IconButton(
                onPressed: () {
                  Get.toNamed("/gridView");
                },
                icon: Icon(Icons.apps_outlined),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: FutureBuilder(
        future: getCountAndPages(),
        builder: (context, snapshot) {
          return PageBottomBar(
              onPageChange: (value) {
                setState(() {
                  _index = value;
                  _scrollController.animateTo(0,
                      duration: Duration(milliseconds: 500),
                      curve: Curves.easeInOut);
                });
              },
              totalPages: pages);
        },
      ),
    );
  }
}
