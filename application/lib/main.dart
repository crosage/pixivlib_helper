import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tagselector/ImageWithInfo.dart';
import 'package:tagselector/SearchTools.dart';
import 'package:tagselector/SetupIcon.dart';
import 'package:tagselector/utils.dart';
import 'package:tagselector/ImageWithInfo.dart';

void main() {
  runApp(MyApp());
}

//一行展示已选择的Tag
//下面多个ImageWithInfo组件
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late List<String> selectedTags;
  ScrollController _scrollController = ScrollController();
  late int total;
  late int _index;
  bool isEdting = false;
  int pages = 0;

  @override
  void initState() {
    super.initState();
    selectedTags = [];
    _index = 0;
    _scrollController = ScrollController();
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

  void _lastPage() {
    setState(() {
      _index = _index > 0 ? _index - 1 : 0;
      print(_index);
      print("now:index");
      _scrollController.animateTo(0,
          duration: Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  void _nextPage() {
    setState(() {
      _index = _index + 1;
      print(_index);
      _scrollController.animateTo(0,
          duration: Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  //todo 应该添加对是否有该tag的判断
  void _searchTag(String value) {
//    final response=await http.get(Uri.parse('http://127.0.0.1:8000/api/lib/i'));
    setState(() {
      selectedTags.add(value);
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
      print(pages);
      List<dynamic> imageWithInfo = [];
      for (final image in images) {
        int pid = image['pid'];
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
    return MaterialApp(
        title: 'pixiv_helper',
        home: Scaffold(
          appBar: AppBar(
            title: Text('pixiv_helper'),
          ),
          body: Column(
            children: [
              Container(height: 96, child: SearchBar(onSearchTag: _searchTag)),
              Row(
                children: [
                  Expanded(
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
                  Expanded(
                    flex: 0,
                    child: dropDownButton(),
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
                    return Expanded(
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

                  // return other widget when snapshot does not have data yet
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                },
              ),
            ],
          ),
          bottomNavigationBar: BottomAppBar(
            child: FutureBuilder(
                future: getImages(),
                builder: (context, snapshot) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                          onPressed: _lastPage, icon: Icon(Icons.arrow_back)),
                      Container(
                          width: 50,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: (_index + 1).toString(),
                            ),
                            textAlign: TextAlign.center,
                            onSubmitted: (value) {
                              _index = int.parse(value) - 1;
                              print("index:now");
                              print(_index);
                              setState(() {});
                            },
                          )),
                      IconButton(
                          onPressed: _nextPage,
                          icon: Icon(Icons.arrow_forward)),
                      SizedBox(
                        width: 233,
                      ),
                      Text("共" + pages.toString() + "页")
                    ],
                  );
                }),
          ),
        ));
  }
}
