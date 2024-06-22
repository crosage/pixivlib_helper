import 'package:flutter/material.dart';
import 'package:tagselector/model/author_model.dart';
import 'dart:math';
import 'dart:io';
import 'package:tagselector/utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
    final selectedTags = _getSelectedTags();
    widget.onSelectedTagsChanged(widget.tags[index].name);
  }

  List<String> _getSelectedTags() {
    final selectedTags = <String>[];
    for (int i = 0; i < widget.tags.length; i++) {
      if (_isSelected[i]) {
        selectedTags.add(widget.tags[i].name);
      }
    }
    return selectedTags;
  }

  @override
  Widget build(BuildContext context) {
    _isSelected = List.generate(30, (index) => false);
    _colors = List.generate(30, (index) => Colors.grey);
    for (int i = 0; i < widget.tags.length; i++) {
      if (widget.selectedTags.contains(widget.tags[i])) {
        _colors[i] = getRandomColor(widget.tags[i].hashCode);
        _isSelected[i] = true;
      }
    }
    return Container(
      color: Color(0xFF2E2E48),
      height: 300,
      child: Card(
        color: Color(0xFF464667),
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
                        });
                  },
                  child: Image.file(
                    File(widget.imageUrl),
                    //fit: BoxFit.fitHeight,
                  )),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      launchUrlString(
                          "https://www.pixiv.net/artworks/${widget.pid.toString()}");
                    },
                    child: RawChip(
                      avatar: Icon(
                        Icons.image,
                        color: Colors.blue,
                      ),
                      label: Text(
                        "pid:" + widget.pid.toString(),
                        style: TextStyle(color: Colors.white),
//                    style: TextStyle(color: Colors.blue),
                      ),
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
                      style: TextStyle(color: Colors.white),
//                    style: TextStyle(color: Colors.blue),
                    ),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  RawChip(
                    avatar: Icon(
                      Icons.person,
                      color: Colors.blue,
                    ),
                    label: Text(
                      "author:" + widget.author.toString(),
                      style: TextStyle(color: Colors.white),
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
                          style: TextStyle(color: Colors.white),
//                        style: TextStyle(color: Colors.blue),
                        ),
                      ),
                      for (int i = 0; i < widget.tags.length; i++)
                        FilterChip(
                          label: Text(
                            widget.tags[i].name,
                            style: TextStyle(color: Colors.white),
                          ),
                          selected: _isSelected[i],
                          onSelected: (isSelected) {
                            _handleTagSelection(i, isSelected);
                          },
                          backgroundColor: Colors.grey,
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
