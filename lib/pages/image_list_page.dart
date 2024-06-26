import 'package:flutter/material.dart';
import 'package:tagselector/components/image_with_info.dart';
import 'package:tagselector/components/page_bottombar.dart';
import 'package:tagselector/components/search_tool.dart';
import 'package:tagselector/model/search_model.dart';
import 'package:tagselector/utils.dart';
import 'dart:convert';
import '../model/image_model.dart';
import '../service/http_helper.dart';

class ImageListPage extends StatefulWidget {
  @override
  _ImageListPageState createState() => _ImageListPageState();
}

class _ImageListPageState extends State<ImageListPage> {
  SearchCriteria searchCriteria=SearchCriteria();
  HttpHelper httpHelper = HttpHelper();

  ScrollController _scrollController = ScrollController();

  Future<List<String>> getTagSuggestions() async {
    var jsonData = json.encode(<String, dynamic>{
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
    searchCriteria.page=1;
    _scrollController = ScrollController();
  }

  void _searchTag(String value) {
    setState(() {
      searchCriteria.tags.add(value);
    });
  }

  Future<int> getCountAndPages() async {
    int pages = 0;

    final response = await httpHelper.postRequest(
        "http://localhost:23333/api/image", searchCriteria.toJson());
    if (response.statusCode == 200) {
      Map<String, dynamic> responseData = jsonDecode(response.toString());
      pages = responseData["data"]["total"];
    }
    print("COUNT::::: ${(pages ~/ searchCriteria.pageSize) + 1}");
    return (pages ~/ searchCriteria.pageSize) + 1;
  }

  void _handleSelectedTags(String tag) {
    setState(() {
      searchCriteria.page=1;
      searchCriteria.handleTag(tag);
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
    final response = await httpHelper.postRequest(
        "http://localhost:23333/api/image", searchCriteria.toJson());
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
            width: MediaQuery.of(context).size.width - 60 - 200 - 100 - 100,
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
                          suggestions: snapshot.data!,
                        );
                      }
                    }),
                SizedBox(
                  height: 5,
                ),
                FutureBuilder<List<ImageModel>>(
                  future: getImages(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Flexible(
                        child: ListView(
                          controller: _scrollController,
                          children: [
                            for (final i in snapshot.data!)
                              ImageWithInfo(
                                imageUrl: i.path,
                                pages: i.pages,
                                pid: i.pid,
                                tags: i.tags,
                                name:i.name,
                                filetype:i.fileType,
                                author: i.author,
                                onSelectedTagsChanged: _handleSelectedTags,
                                onSelectedAuthor: (author){
                                  setState(() {
                                    if(searchCriteria.authorName==author){
                                      searchCriteria.authorName="";
                                    }else {
                                      searchCriteria.authorName=author;
                                    }
                                    searchCriteria.page=1;
                                  });
                                },
                                selectedTags: searchCriteria.tags,
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
                    Icon(
                      Icons.filter_list,
                      size: 50,
                    ),
                    Text(
                      "当前筛选条件",
                      style: TextStyle(fontSize: 20),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12.0)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "已选择作者",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            flex: 1,
                            child: Wrap(
                              spacing: 5,
                              children: [
                                Text(
                                  searchCriteria.authorName,
                                  style: TextStyle(fontSize: 24),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20,),
                Container(
                  decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12.0)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "已选择tag",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Flexible(
                            flex: 1,
                            child: Wrap(
                              spacing: 5,
                              children: [
                                for (int i = 0; i < searchCriteria.tags.length; i++)
                                  FilterChip(
                                    label: Text(searchCriteria.tags[i]),
                                    selected: true,
                                    onSelected: (isSelected) {
                                      setState(() {
                                        searchCriteria.removeTag(searchCriteria.tags[i]);
                                      });
                                    },
                                    selectedColor: getRandomColor(
                                        searchCriteria.tags[i].hashCode),
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
          if (snapshot.hasData) {
            return PageBottomBar(
              currentPage: searchCriteria.page,
              onPageChange: (value) {
                setState(() {
                  searchCriteria.page=value;
                  _scrollController.animateTo(0,
                      duration: Duration(milliseconds: 500),
                      curve: Curves.easeInOut);
                });
              },
              totalPages: snapshot.data!,
            );
          } else
            return Center(
              child: CircularProgressIndicator(),
            );
        },
      ),
    );
  }
}
