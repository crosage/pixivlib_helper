import 'package:flutter/material.dart' hide Page;
import 'package:tagselector/model/author_model.dart';
import 'dart:math';
import 'package:tagselector/utils.dart';
import '../model/image_model.dart';
import '../model/page_model.dart';
import '../model/tag_model.dart';
import 'dart:typed_data';
import '../service/http_helper.dart';

class ImageWithInfo extends StatefulWidget {
  final ImageModel image;
  final List<dynamic> selectedTags;
  final Function(String) onSelectedTagsChanged;
  final Function(String) onSelectedAuthor;

  const ImageWithInfo({
    super.key,
    required this.image,
    required this.selectedTags,
    required this.onSelectedTagsChanged,
    required this.onSelectedAuthor,
  });

  @override
  _ImageWithInfoState createState() => _ImageWithInfoState();
}

class _ImageWithInfoState extends State<ImageWithInfo> {
  late List<bool> _isSelected;
  late List<Color> _colors;
  int hoveredIndex = 0;
  int currentIndex = 0;

  Uint8List? _imageData;
  bool _isLoading = true;
  bool _hasError = false;

  late HttpHelper _httpHelper;

  @override
  void initState() {
    super.initState();
    _httpHelper = HttpHelper();
    _initializeState();
    _loadImage();
  }

  void _initializeState() {
    _isSelected = List.generate(widget.image.tags.length, (index) => false);
    _colors = List.generate(widget.image.tags.length, (index) => Colors.grey);
    _updateTagSelectionVisuals();
    hoveredIndex = 0;
    currentIndex = 0;
  }

  void _updateTagSelectionVisuals() {
    for (int i = 0; i < widget.image.tags.length; i++) {
      bool isSelected = widget.selectedTags.contains(widget.image.tags[i].name);
      _isSelected[i] = isSelected;
      _colors[i] = isSelected
          ? getRandomColor(widget.image.tags[i].name.hashCode)
          : Colors.grey;
    }
  }

  @override
  void didUpdateWidget(ImageWithInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image.id != oldWidget.image.id) {
      print("Image ID changed, reloading...");
      _initializeState();
      _isLoading = true;
      _hasError = false;
      _imageData = null;
      _loadImage();
    } else if (widget.selectedTags != oldWidget.selectedTags) {
      print("Selected tags changed, updating visuals...");
      setState(() {
        _updateTagSelectionVisuals();
      });
    }
    hoveredIndex = 0;
    currentIndex = 0;
  }

  Future<void> _loadImage() async {
    if (!_isLoading || _hasError) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _hasError = false;
        });
      } else {
        _isLoading = true;
        _hasError = false;
      }
    }

    String? imageUrl = widget.image.urls.regular;
    if (imageUrl == null || imageUrl.isEmpty) {
      print("Error: Image URL (${widget.image.id}) is missing or empty.");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    print("Loading image: $imageUrl");

    try {
      Uint8List? fetchedData = await _httpHelper.getImageBytesWithProxy(
        url: imageUrl,
        proxyHost: '127.0.0.1',
        proxyPort: "7890",
        headers: {'Referer': 'https://www.pixiv.net/'},
        skipBadCertificates: true,
      );

      if (mounted) {
        setState(() {
          _imageData = fetchedData;
          _isLoading = false;
          _hasError = (fetchedData == null);
          if(_hasError) print("Image loaded but data is null.");
        });
      }
    } catch (e) {
      print("Error loading image in _loadImage (${widget.image.id}): $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _handleTagSelection(int index, bool isSelected) {
    setState(() {
      _isSelected[index] = isSelected;
      _colors[index] = isSelected
          ? getRandomColor(widget.image.tags[index].name.hashCode)
          : Colors.grey;
    });
    widget.onSelectedTagsChanged(widget.image.tags[index].name);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
          side: BorderSide(
            width: 0.2,
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
                  if (_imageData != null) {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          contentPadding: EdgeInsets.all(8),
                          content: Container(
                            width: MediaQuery.of(context).size.width * 0.8,
                            height: MediaQuery.of(context).size.height * 0.8,
                            child: InteractiveViewer(
                              scaleEnabled: true,
                              maxScale: 20.0,
                              minScale: 0.1,
                              child: Image.memory(
                                  _imageData!),
                            ),
                          ),
                        );
                      },
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('图片仍在加载中...')),
                    );
                    print("Image data is null, cannot show dialog.");
                  }
                },
                child: _buildImageArea(),
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
                        widget.image.name,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                  SizedBox(height: 5),
                  Wrap(
                    spacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      InkWell(
                        onTap: () {
                          widget.onSelectedAuthor(widget.image.author.name);
                        },
                        child: Text(
                          widget.image.author.name,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          print("pid: ${widget.image.pid.toString()}");
                        },
                        child: Text(
                          "pid: ${widget.image.pid.toString()}",
                          style: const TextStyle(
                            color: Colors.grey,
                            decoration: TextDecoration.underline,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // SizedBox(height: 10),
                  // if (widget.image.pages.isNotEmpty && widget.image.pages.length > 1)
                  //   Row(
                  //     children: [
                  //       const Text(
                  //         "pages: ",
                  //         style: TextStyle(fontSize: 16),
                  //       ),
                  //       ...List.generate(
                  //           min(widget.image.pages.length, 5),
                  //               (i) => Padding(
                  //             padding: const EdgeInsets.only(right: 4.0),
                  //             child: InkWell(
                  //               onTap: () {
                  //                 setState(() {
                  //                   currentIndex = i;
                  //                   hoveredIndex = i;
                  //                 });
                  //               },
                  //               onHover: (isHovering) {
                  //                 setState(() {
                  //                   hoveredIndex = isHovering ? i : currentIndex;
                  //                 });
                  //               },
                  //               child: Container(
                  //                 width: 30,
                  //                 height: 30,
                  //                 decoration: BoxDecoration(
                  //                   color: hoveredIndex == i
                  //                       ? Colors.blueGrey
                  //                       : (currentIndex == i ? Colors.blue.shade300 : Colors.grey),
                  //                   borderRadius: BorderRadius.circular(8.0),
                  //                 ),
                  //                 child: Center(
                  //                   child: Text(
                  //                     widget.image.pages[i].pageId.toString(),
                  //                     style: const TextStyle(
                  //                         fontSize: 16, color: Colors.white),
                  //                   ),
                  //                 ),
                  //               ),
                  //             ),
                  //           )
                  //       ),
                  //       if (widget.image.pages.length > 5) Text("..."),
                  //     ],
                  //   ),
                  SizedBox(height: 10),
                  Expanded(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: [
                            const RawChip(
                              avatar: Icon(
                                Icons.tag,
                                color: Colors.blue,
                                size: 18,
                              ),
                              label: Text(
                                "Tags:",
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            for (int i = 0; i < widget.image.tags.length; i++)
                              FilterChip(
                                label: Text(
                                  widget.image.tags[i].name,
                                ),
                                selected: _isSelected[i],
                                onSelected: (isSelected) {
                                  _handleTagSelection(i, isSelected);
                                },
                                selectedColor: _colors[i],
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      )
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_hasError || _imageData == null) {
      return const Center(child: Icon(Icons.error_outline, color: Colors.red, size: 40));
    } else {
      return Image.memory(
        _imageData!,
        fit: BoxFit.contain,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            child: child,
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        },
      );
    }
  }
}