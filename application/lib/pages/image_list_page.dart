import 'package:flutter/material.dart';
import 'package:tagselector/components/image_with_info.dart';
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
  late int total;
  late int _index;
  TextEditingController bottomPageController = TextEditingController();
  bool isEdting = false;
  int pages = 0;
  String searchHelperForWindows = "";

  void _searchTag(String value) {
    setState(() {
      selectedTags.add(value);
    });
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
      List<dynamic> imageWithInfo = [];
      for (final image in images) {
        int pid = image['pid'];
        searchHelperForWindows =
            searchHelperForWindows + pid.toString() + " OR ";
        int page = image['page'];
        String author = image['author'];
        String imageUrl = image['path'] + "\\" + image['name'];
        final resp = await http.get(
            Uri.parse('http://localhost:8000/api/image/' + pid.toString()));
        List<dynamic> tags = json.decode(utf8.decode(resp.bodyBytes))['tags'];
        imageWithInfo.add(ImageWithInfo(
          imageUrl: imageUrl,
          page: page,
          pid: pid,
          tags: tags,
          author: author,
          onSelectedTagsChanged: _handleSelectedTags,
          selectedTags: selectedTags,
        ));
      }
      return imageWithInfo;
    } else {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: MediaQuery.of(context).size.width - 50,
            child: Column(
              children: [
                Container(
                  width: 500,
                  // height: 500,
                  child: SearchTool(onSearchTag: _searchTag),
                ),
                Row(
                  children: [Text("data")],
                ),
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
                    // Flexible(
                    //   flex: 0,
                    //   child: IconButton(
                    //     icon: Icon(Icons.copy),
                    //     onPressed: () {
                    //       Clipboard.setData(
                    //         ClipboardData(text: searchHelperForWindows),
                    //       );
                    //     },
                    //   ),
                    // ),
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
//                        style: TextStyle(color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                            for (final i in snapshot.data!)
                              ImageWithInfo(
                                imageUrl: i.imageUrl,
                                page: i.page,
                                pid: i.pid,
                                tags: i.tags,
                                author: i.author,
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
          Sidebar()
        ],
      ),
    );
  }
}
