import 'package:flutter/material.dart';

class ImageBottomBar extends StatelessWidget {
  final int totalPages;
  final int nowPage;
  final Function(int) onPageChange;

  ImageBottomBar({
    required this.totalPages,
    required this.nowPage,
    required this.onPageChange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(

    );
  }
}
