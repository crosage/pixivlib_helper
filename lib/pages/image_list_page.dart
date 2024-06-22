import 'package:flutter/material.dart';
import 'package:tagselector/components/image_with_info.dart';
import 'package:tagselector/components/page_bottombar.dart';
import 'package:tagselector/components/search_tool.dart';
import 'package:tagselector/utils.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../model/image_model.dart';
import '../service/http_helper.dart';

class ImageListPage extends StatefulWidget {
  @override
  _ImageListPageState createState() => _ImageListPageState();
}

class _ImageListPageState extends State<ImageListPage> {
  late List<String> selectedTags;
  HttpHelper httpHelper = HttpHelper();

  ScrollController _scrollController = ScrollController();
  late int _index;

  Future<List<String>> getTagSuggestions() async {
    var jsonData = json.encode(<String, dynamic>{
      "page": _index,
      "size": 100000,
    });
    final response = await httpHelper.postRequest(
        "http://localhost:23333/api/tag", jsonData);
    if (response.statusCode == 200) {
      Map<String, dynamic> responseData = jsonDecode(response.toString());
      List<dynamic> tags = responseData['data']['tags'];
      List<String> names = tags.map((tag) => tag['name'] as String).toList();
      return names;

    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    selectedTags = [];
    _index = 1;
    _scrollController = ScrollController();
  }

  void _searchTag(String value) {
    setState(() {
      selectedTags.add(value);
    });
  }

  Future<int> getCountAndPages() async {
    int size = 20, pages = 0;
    var jsonData = json.encode(<String, dynamic>{
      "page": _index,
      "size": size,
      "tag": selectedTags
    });
    final response = await httpHelper.postRequest(
        "http://localhost:23333/api/image", jsonData);
    if (response.statusCode == 200) {
      Map<String, dynamic> responseData = jsonDecode(response.toString());
      pages = responseData["data"]["total"];
    }
    return (pages ~/ size) + 1;
  }

  void _handleSelectedTags(String tag) {
    setState(() {
      _index = 1;
      if (selectedTags.contains(tag)) {
        selectedTags.removeWhere((item) => item == tag);
      } else {
        selectedTags.add(tag);
      }
    });
  }

  List<ImageModel> _parseImages(List<dynamic> rolesData) {
    List<ImageModel> parsedUsers = [];
    for (var roleData in rolesData) {
      parsedUsers.add(ImageModel.fromJson(roleData));
    }
    return parsedUsers;
  }

  Future<List<ImageModel>> getImages() async {
    int size = 20, page = _index;
    var jsonData = json.encode(
        <String, dynamic>{"size": size, "page": page, "tags": selectedTags});
    final response = await httpHelper.postRequest(
        "http://localhost:23333/api/image", jsonData);
    if (response.statusCode == 200) {
      Map<String, dynamic> responseData = jsonDecode(response.toString());
      List<ImageModel> images = _parseImages(responseData["data"]["images"]);
      return images;
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
            width: MediaQuery.of(context).size.width - 60 - 200-100-100,
            child: Column(
              children: [
                FutureBuilder<List<String>>(
                    future: getTagSuggestions(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      } else {
                        // print(snapshot.data!);
                        return SearchTool(
                            onSelected: _searchTag,
                            suggestions: snapshot.data!);
                      }
                    }),
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
                            for (final i in snapshot.data!)
                              ImageWithInfo(
                                imageUrl: i.path +
                                    "\\" +
                                    i.pid.toString() +
                                    "_p" +
                                    i.pages[0].pageId.toString() +
                                    "." +
                                    i.fileType,
                                page: 0,
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
          Expanded(
            // width: 100,
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.filter_list,size: 50,),
                    Text("当前筛选条件",style: TextStyle(fontSize: 20),),
                  ],
                ),
                Container(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("已选择作者",style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            flex: 1,
                            child: Wrap(
                              spacing: 5,
                              children: [
                                Text("none",style: TextStyle(fontSize: 30),)
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("已选择tag",style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),),
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
                                        selectedTags.removeAt(i);
                                      });
                                    },
                                    selectedColor:
                                    getRandomColor(selectedTags[i].hashCode),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              ],
            ),
          )
        ],
      ),
      bottomNavigationBar: FutureBuilder(
        future: getCountAndPages(),
        builder: (context, snapshot) {
          print(snapshot.data);
          if(snapshot.hasData)
            return PageBottomBar(
              onPageChange: (value) {
                setState(() {
                  _index = value;
                  _scrollController.animateTo(0,
                      duration: Duration(milliseconds: 500),
                      curve: Curves.easeInOut);
                });
              },
              totalPages: snapshot.data!,
            );
          else
            return Center(
              child: CircularProgressIndicator(),
            );
        },
      ),
    );
  }
}
