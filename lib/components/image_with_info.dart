import 'package:flutter/material.dart';
import 'package:tagselector/model/author_model.dart';
import 'dart:math';
import 'dart:io';
import 'package:tagselector/utils.dart';
import 'package:webview_flutter/webview_flutter.dart';


import '../model/tag_model.dart';

class ImageWithInfo extends StatefulWidget {
  final String imageUrl;
  final int page;
  final int pid;
  final Author author;
  final List<Tag> tags;
  final List<dynamic> selectedTags;
  final Function(String) onSelectedTagsChanged;

  const ImageWithInfo(
      {super.key,
      required this.imageUrl,
      required this.page,
      required this.pid,
      required this.author,
      required this.tags,
      required this.onSelectedTagsChanged,
      required this.selectedTags});

  @override
  _ImageWithInfoState createState() => _ImageWithInfoState();
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
    widget.onSelectedTagsChanged(widget.tags[index].name);
  }

  @override
  Widget build(BuildContext context) {
    _isSelected = List.generate(30, (index) => false);
    _colors = List.generate(30, (index) => Colors.grey);
    for (int i = 0; i < widget.tags.length; i++) {
      if (widget.selectedTags.contains(widget.tags[i].name)) {
        _colors[i] = getRandomColor(widget.tags[i].name.hashCode);
        _isSelected[i] = true;
      }
    }
    return Container(
      height: 300,
      child: Card(
        child: Row(
          children: [
            SizedBox(
              width: 20,
            ),
            Expanded(
              child: InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        content: Container(
                          width: 2000,
                          child: InteractiveViewer(
                              scaleEnabled: true,
                              maxScale: 20.0,
                              minScale: 0.1,
                              child: Image.file(File(widget.imageUrl))),
                        ),
                      );
                    },
                  );
                },
                child: Image.file(
                  File(widget.imageUrl),
                ),
              ),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          print("author: ${widget.author.name.toString()}");
                        },
                        child: Text(
                          "${widget.author.name.toString()}",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                      SizedBox(width: 5,),
                      InkWell(
                        onTap: () {
                          print("pid: ${widget.pid.toString()}");
                        },
                        child: Text(
                          "pid: ${widget.pid.toString()}",
                          style: TextStyle(
                            color: Colors.grey,
                            decoration: TextDecoration.underline,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      // SizedBox(width: 10),
                      // InkWell(
                      //   onTap: () {
                      //     // 点击事件处理逻辑
                      //     print("page: ${widget.page.toString()}");
                      //   },
                      //   child: Text(
                      //     "page: ${widget.page.toString()}",
                      //     style: TextStyle(
                      //         color: Colors.blue,
                      //         decoration: TextDecoration.underline),
                      //   ),
                      // ),
                      // SizedBox(width: 10),
                    ],
                  ),
//                   InkWell(
//                     onTap: () {
//                       launchUrlString(
//                           "https://www.pixiv.net/artworks/${widget.pid.toString()}");
//                     },
//                     child: RawChip(
//                       avatar: Icon(
//                         Icons.image,
//                         color: Colors.blue,
//                       ),
//                       label: Text(
//                         "pid:" + widget.pid.toString(),
// //                    style: TextStyle(color: Colors.blue),
//                       ),
//                     ),
//                   ),
//                   SizedBox(
//                     height: 5,
//                   ),
//                   RawChip(
//                     avatar: Icon(
//                       Icons.find_in_page,
//                       color: Colors.blue,
//                     ),
//                     label: Text(
//                       "page:" + widget.page.toString(),
// //                    style: TextStyle(color: Colors.blue),
//                     ),
//                   ),
//                   SizedBox(
//                     height: 5,
//                   ),
//                   RawChip(
//                     avatar: Icon(
//                       Icons.person,
//                       color: Colors.blue,
//                     ),
//                     label: Text(
//                       "author:" + widget.author.toString(),
//                     ),
//                   ),
//                   SizedBox(
//                     height: 5,
//                   ),
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
                          label: Text(
                            widget.tags[i].name,
                          ),
                          selected: _isSelected[i],
                          onSelected: (isSelected) {
                            _handleTagSelection(i, isSelected);
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
      ),
    );
  }
}
