import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ImageWithInfo extends StatefulWidget {
  final String imageUrl;
  final int page;
  final int pid;
  final List<dynamic> tags;
  final Function(List<String>) onSelectedTagsChanged;

  const ImageWithInfo({
    super.key,
    required this.imageUrl,
    required this.page,
    required this.pid,
    required this.tags,
    required this.onSelectedTagsChanged,
  });

  @override
  State<ImageWithInfo> createState() => _ImageWithInfoState();
}

class _ImageWithInfoState extends State<ImageWithInfo> {
  late List<bool> _isSelected;
  late List<Color> _colors;

  @override
  void initState() {
    super.initState();
    _isSelected = List.generate(30, (index) => false);
    _colors = List.generate(30, (index) => Colors.grey);
  }

  void _handleTagSelection(int index, bool isSelected) {
    setState(() {
      _isSelected[index] = isSelected;
    });
    final selectedTags = _getSelectedTags();
    widget.onSelectedTagsChanged(selectedTags);
  }

  List<String> _getSelectedTags() {
    final selectedTags = <String>[];
    for (int i = 0; i < widget.tags.length; i++) {
      if (_isSelected[i]) {
        selectedTags.add(widget.tags[i]);
      }
    }
    return selectedTags;
  }

  Color _getRandomColor() {
    final random = Random();
    int r, g, b;
    do {
      r = random.nextInt(256);
      g = random.nextInt(256);
      b = random.nextInt(256);
    } while (r + g + b <= 600);
    return Color.fromARGB(
      255,
      r,
      g,
      b,
    );
  }

  @override
  Widget build(BuildContext context) {
    _isSelected = List.generate(30, (index) => false);
    _colors = List.generate(30, (index) => Colors.grey);
    return Container(
      height: 200,
      child: Row(
        children: [
          SizedBox(
            width: 20,
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.0),
              child: Image.file(
                File(widget.imageUrl),
                //fit: BoxFit.fitHeight,
              ),
            ),
          ),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RawChip(
                  avatar: Icon(
                    Icons.image,
                    color: Colors.blue,
                  ),
                  label: Text(
                    "pid:" + widget.pid.toString(),
//                    style: TextStyle(color: Colors.blue),
                  ),
                ),
                SizedBox(
                  height: 5,
                ),
                RawChip(
                  avatar: Icon(
                    Icons.find_in_page,
                    color: Colors.blue,
                  ),
                  label: Text(
                    "page:" + widget.page.toString(),
//                    style: TextStyle(color: Colors.blue),
                  ),
                ),
                SizedBox(
                  height: 5,
                ),
                Wrap(
                  spacing: 5,
                  runSpacing: 10,
                  children: [
                    RawChip(
                      avatar: Icon(
                        Icons.tag,
                        color: Colors.blue,
                      ),
                      label: Text(
                        "Tags:",
//                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                    for (int i = 0; i < widget.tags.length; i++)
                      FilterChip(
                        label: Text(widget.tags[i]),
                        selected: _isSelected[i],
                        onSelected: (isSelected) {
                          _handleTagSelection(i, isSelected);
                          if (isSelected) _colors[i] = _getRandomColor();
                        },
                        selectedColor: _colors[i],
                      ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

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

  void _handleSelectedTags(List<String> tags) {
    setState(() {
      selectedTags = tags;
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
    print(selectedTags);
    var jsonData = json.encode(<String, dynamic>{
      "limit": limit,
      "offset": offset,
      "tag": selectedTags
    });
    final response = await http
        .post(Uri.parse('http://localhost:8000/api/image'), body: jsonData);
    if (response.statusCode == 200) {
      Map<String, dynamic> map = json.decode(response.body);
      final List<dynamic> images = map['images'];
      List<dynamic> imageWithInfo = [];
      for (final image in images) {
        int pid = image['pid'];
        int page = image['page'];
        String imageUrl = image['path'] + "\\" + image['name'];
        final resp = await http.get(
            Uri.parse('http://localhost:8000/api/image/' + pid.toString()));
        List<dynamic> tags = json.decode(utf8.decode(resp.bodyBytes))['tags'];
        imageWithInfo.add(ImageWithInfo(
          imageUrl: imageUrl,
          page: page,
          pid: pid,
          tags: tags,
          onSelectedTagsChanged: _handleSelectedTags,
        ));
      }
      return imageWithInfo;
    } else {
      print("WWWWWWWRRRRROOOOONNGGGGGGG Happened");
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
              FutureBuilder<List<dynamic>>(
                //key: Key(generateRandomString(6)),
                future: getImages(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Expanded(
                      child: ListView(
                        controller: _scrollController,
                        children: [
                          for (final i in snapshot.data!)
                            ImageWithInfo(
                              //key: Key(generateRandomString(6)),
                              imageUrl: i.imageUrl,
                              page: i.page,
                              pid: i.pid,
                              tags: i.tags,
                              onSelectedTagsChanged: _handleSelectedTags,
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

String generateRandomString(int len) {
  var r = Random();
  return String.fromCharCodes(List.generate(len, (index) => r.nextInt(33) + 89));
}
