import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tagselector/ImageWithInfo.dart';
import 'package:tagselector/SetupIcon.dart';
import 'package:tagselector/utils.dart';

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

  @override
  void initState() {
    super.initState();
    selectedTags = [];
    _index = 0;
    _scrollController = ScrollController();
  }

  void _handleSelectedTags(String tag) {
    setState(() {
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
      _scrollController.animateTo(0,
          duration: Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  void _nextPage() {
    setState(() {
      _index = _index + 1;
      _scrollController.animateTo(0,
          duration: Duration(milliseconds: 500), curve: Curves.easeInOut);
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
    //print(response.statusCode);
    if (response.statusCode == 200) {
      Map<String, dynamic> map = json.decode(utf8.decode(response.bodyBytes));
      final List<dynamic> images = map['images'];
      List<dynamic> imageWithInfo = [];
      //print(images);
      for (final image in images) {
        int pid = image['pid'];
        int page = image['page'];
        String author=image['author'];
        String imageUrl = image['path'] + "\\" + image['name'];
        //print(pid);
        final resp = await http.get(
            Uri.parse('http://localhost:8000/api/image/' + pid.toString()));
        //print(resp.statusCode);
        //print("**************");
        List<dynamic> tags = json.decode(utf8.decode(resp.bodyBytes))['tags'];
        //print(tags);
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(onPressed: _lastPage, icon: Icon(Icons.arrow_back)),
                Text((_index + 1).toString()),
                IconButton(
                    onPressed: _nextPage, icon: Icon(Icons.arrow_forward)),
              ],
            ),
          ),
        ));
  }
}
