import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tagselector/components/image_with_info.dart';
import 'package:tagselector/components/page_bottombar.dart';
import 'package:tagselector/components/search_tool.dart';
import 'package:tagselector/model/search_model.dart';
import 'package:tagselector/utils.dart';
import 'dart:convert';
import '../components/grid_image_tile.dart';
import '../model/image_model.dart';
import '../service/http_helper.dart';

enum DisplayMode { list, grid }

class FollowingPage extends StatefulWidget {
  @override
  _FollowingPageState createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage> {
  SearchCriteria searchCriteria = SearchCriteria();
  ImageProvider? avatarImage;
  String userid = "42279487";
  Timer? _debounceTimer;
  final Duration _debounceDuration = const Duration(seconds: 2);
  late TextEditingController _minLikesController;
  late TextEditingController _maxLikesController;
  late TextEditingController _pageSizeController;

  HttpHelper httpHelper = HttpHelper.getInstance(
      globalProxyHost: "127.0.0.1", globalProxyPort: "7890");
  DisplayMode _currentViewMode = DisplayMode.grid;
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
    searchCriteria.page = 1;
    _scrollController = ScrollController();
    String initialMinLikes = '';
    String initialMaxLikes = '';
    String initialPageSize = '';
    _minLikesController = TextEditingController(text: initialMinLikes);
    _maxLikesController = TextEditingController(text: initialMaxLikes);
    _pageSizeController = TextEditingController(text: initialPageSize);
  }

  void _searchTag(String value) {
    setState(() {
      searchCriteria.tags.add(value);
    });
  }

  void _handleSelectedTags(String tag) {
    setState(() {
      searchCriteria.page = 1;
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
    var jsonData = json.encode(<String, dynamic>{
      "userID": userid,
      "page": searchCriteria.page,
      "mode": "all",
    });
    final response = await httpHelper.postRequest(
        "http://localhost:23333/api/pixiv/image/following", jsonData);
    if (response.statusCode == 200) {
      Map<String, dynamic> responseData = jsonDecode(response.toString());
      print("${responseData}");
      List<ImageModel> images = _parseImages(responseData["data"]["images"]);

      return images;
    } else {
      return [];
    }
  }

  void _handleSelectedAuthor(String author, ImageProvider? backgroundImage) {
    setState(() {
      if (searchCriteria.authorName == author) {
        searchCriteria.authorName = "";
        avatarImage = null;
      } else {
        searchCriteria.authorName = author;
        avatarImage = backgroundImage;
      }
      searchCriteria.page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
                  Expanded(
                    child: FutureBuilder<List<ImageModel>>(
                      future: getImages(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final images = snapshot.data!;
                          print("*********************************");
                          if (images.isEmpty) {
                            return const Center(
                              child: Text('没有找到图片。'),
                            );
                          }
                          if (_currentViewMode == DisplayMode.list) {
                            return ListView.builder(
                              controller: _scrollController,
                              itemCount: images.length,
                              itemBuilder: (context, index) {
                                final imageModel = images[index];
                                return ImageWithInfo(
                                  image: imageModel,
                                  onSelectedTagsChanged: _handleSelectedTags,
                                  onSelectedAuthor: _handleSelectedAuthor,
                                  selectedTags: searchCriteria.tags,
                                );
                              },
                            );
                          } else {
                            return GridView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(8.0),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 6,
                                crossAxisSpacing: 8.0,
                                mainAxisSpacing: 8.0,
                                childAspectRatio: 0.67,
                              ),
                              itemCount: images.length,
                              itemBuilder: (context, index) {
                                final imageModel = images[index];
                                return GridImageTile(
                                  imageModel: imageModel,
                                );
                              },
                            );
                          }
                        }
                        return Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              // width: 100,
              child: Container(
                color: Color(0xFFF5F5F5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 20,
                          ),
                          Row(
                            children: [
                              Text(
                                "选择图片排列方式",
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              if (_currentViewMode == DisplayMode.list)
                                Text("切换为网格表示"),
                              if (_currentViewMode == DisplayMode.grid)
                                Text("切换为列表表示"),
                              IconButton(
                                color: Colors.black,
                                tooltip: _currentViewMode == DisplayMode.list
                                    ? '切换到网格表示'
                                    : '切换到列表显示',
                                icon: Icon(
                                  _currentViewMode == DisplayMode.list
                                      ? Icons.grid_view
                                      : Icons.view_list,
                                  size: 28,
                                ),
                                onPressed: () {
                                  setState(() {
                                    // Toggle view mode
                                    _currentViewMode =
                                        _currentViewMode == DisplayMode.list
                                            ? DisplayMode.grid
                                            : DisplayMode.list;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
        bottomNavigationBar: PageBottomBar(
          currentPage: searchCriteria.page,
          onPageChange: (value) {
            setState(() {
              searchCriteria.page = value;
              _scrollController.animateTo(0,
                  duration: Duration(milliseconds: 500),
                  curve: Curves.easeInOut);
            });
          },
          totalPages: 1000,
        ));
  }

  @override
  void dispose() {
    _minLikesController.dispose();
    _maxLikesController.dispose();
    _pageSizeController.dispose();
    super.dispose();
  }
}
