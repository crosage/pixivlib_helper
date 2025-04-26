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
  SearchCriteria searchCriteria = SearchCriteria();
  ImageProvider? avatarImage;
  HttpHelper httpHelper = HttpHelper.getInstance(
      globalProxyHost: "127.0.0.1", globalProxyPort: "7890");

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
    final response = await httpHelper.postRequest(
        "http://localhost:23333/api/image", searchCriteria.toJson());
    // print("${response.statusCode}");
    if (response.statusCode == 200) {
      Map<String, dynamic> responseData = jsonDecode(response.toString());
      // print("${responseData}");
      List<ImageModel> images = _parseImages(responseData["data"]["images"]);

      return images;
    } else {
      return [];
    }
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
                FutureBuilder<List<ImageModel>>(
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
                      return Flexible(
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: images.length,
                          itemBuilder: (context, index) {
                            final imageModel = images[index];
                            return ImageWithInfo(
                              image: imageModel,
                              onSelectedTagsChanged: _handleSelectedTags,
                              onSelectedAuthor: (author, backgroundImage) {
                                setState(() {
                                  if (searchCriteria.authorName == author) {
                                    searchCriteria.authorName = "";
                                  } else {
                                    searchCriteria.authorName = author;
                                    avatarImage = backgroundImage;
                                  }
                                  searchCriteria.page = 1;
                                });
                              },
                              selectedTags: searchCriteria.tags,
                            );
                          },
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
                          height: 10,
                        ),
                        Row(
                          children: [
                            IconButton(
                              color: Colors.grey,
                              icon: Icon(
                                Icons.filter_alt_outlined,
                                // color: Colors.blue,
                                size: 50,
                              ),
                              onPressed: () {},
                            ),
                            Text(
                              "当前筛选条件",
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 10,
                            ),
                            Text(
                              "已选择作者",
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            if (searchCriteria.authorName != "")
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 25,
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: avatarImage,
                                    child: (avatarImage == null)
                                        ? Icon(Icons.person_outline,
                                            size: 25, color: Colors.grey[400])
                                        : null,
                                  ),
                                  SizedBox(
                                    width: 10,
                                  ),
                                  Text(
                                    searchCriteria.authorName,
                                    style: textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Spacer(),
                                  IconButton(
                                      onPressed: () => {
                                            setState(() {
                                              searchCriteria.authorName = "";
                                            })
                                          },
                                      icon: Icon(
                                        Icons.do_disturb_on_rounded,
                                        color: Colors.red,
                                      ))
                                ],
                              )
                            else
                              Row(
                                children: [Text("无已选择作者")],
                              ),
                          ],
                        ),
                        SizedBox(
                          height: 20,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "已选择tag",
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            Wrap(
                              spacing: 5,
                              children: [
                                for (int i = 0;
                                    i < searchCriteria.tags.length;
                                    i++)
                                  FilterChip(
                                    label: Text(searchCriteria.tags[i]),
                                    selected: true,
                                    labelStyle: TextStyle(fontSize: 11),
                                    onSelected: (isSelected) {
                                      setState(() {
                                        searchCriteria
                                            .removeTag(searchCriteria.tags[i]);
                                      });
                                    },
                                    shape: StadiumBorder(),
                                    selectedColor: getRandomColor(
                                            searchCriteria.tags[i].hashCode)
                                        .withOpacity(0.3),
                                  ),
                              ],
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
      bottomNavigationBar: FutureBuilder(
        future: getCountAndPages(),
        builder: (context, snapshot) {
          print(snapshot.data);
          if (snapshot.hasData) {
            return PageBottomBar(
              currentPage: searchCriteria.page,
              onPageChange: (value) {
                setState(() {
                  searchCriteria.page = value;
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
