import 'package:flutter/material.dart' hide Page;
import 'package:tagselector/model/author_model.dart';
import 'dart:math';
import 'dart:io';
import 'package:tagselector/utils.dart';
import '../model/page_model.dart';
import '../model/tag_model.dart';

class ImageWithInfo extends StatefulWidget {
  final String imageUrl;
  final int pid;
  final String name;
  final Author author;
  final List<Tag> tags;
  final List<Page> pages;
  final String filetype;
  final List<dynamic> selectedTags;
  final Function(String) onSelectedTagsChanged;
  final Function(String) onSelectedAuthor;

  const ImageWithInfo(
      {super.key,
      required this.imageUrl,
      required this.filetype,
      required this.pid,
      required this.name,
      required this.pages,
      required this.author,
      required this.tags,
      required this.onSelectedTagsChanged,
      required this.onSelectedAuthor,
      required this.selectedTags});

  @override
  _ImageWithInfoState createState() => _ImageWithInfoState();
}

class _ImageWithInfoState extends State<ImageWithInfo> {
  late List<bool> _isSelected;
  late List<Color> _colors;
  int hoveredIndex = 0;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _isSelected = List.generate(30, (index) => false);
    _colors = List.generate(30, (index) => Colors.grey);
    print(widget.pages);
  }

  void _handleTagSelection(int index, bool isSelected) {
    setState(() {
      _isSelected[index] = isSelected;
    });
    widget.onSelectedTagsChanged(widget.tags[index].name);
  }

  Widget buildPageItem(Page page) {
    return ListTile(
      title: Text(page.pageId.toString(),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      // subtitle: Text(page),
    );
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0), // 圆角半径
          side: BorderSide(// 边框颜色
            width: 0.2, // 边框宽度
          ),
        ),
        child: Row(
          children: [
            const SizedBox(
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

                            child: Image.file(
                              File(
                                widget.imageUrl +
                                    "\\" +
                                    widget.pid.toString() +
                                    "_p" +
                                    hoveredIndex.toString() +
                                    "."+
                                    widget.filetype,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                child: Image.file(
                    File(
                      widget.imageUrl +
                          "\\" +
                          widget.pid.toString() +
                          "_p" +
                          hoveredIndex.toString() +
                          "."+
                          widget.filetype,
                    ),
                ),
              ),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                    ],
                  ),
                  Wrap(
                    children: [
                      InkWell(
                        onTap: () {
                          widget.onSelectedAuthor(widget.author.name);
                        },
                        child: Text(
                          "${widget.author.name.toString()}",
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          print("pid: ${widget.pid.toString()}");
                        },
                        child: Text(
                          "pid: ${widget.pid.toString()}",
                          style: const TextStyle(
                            color: Colors.grey,
                            decoration: TextDecoration.underline,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text(
                        "pages: ",
                        style: TextStyle(fontSize: 16),
                      ),
                      for (int i = 0; i < widget.pages.length; i++)
                        InkWell(
                          onTap: () {
                            setState(() {
                              currentIndex = i;
                            });
                          },
                          onHover: (isHovering) {
                            setState(() {
                              hoveredIndex = isHovering ? i : currentIndex;
                            });
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: hoveredIndex == i
                                  ? Colors.blueGrey
                                  : Colors.grey,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Center(
                              child: Text(
                                widget.pages[i].pageId.toString(),
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Wrap(
                    spacing: 5,
                    runSpacing: 10,
                    children: [
                      const RawChip(
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
