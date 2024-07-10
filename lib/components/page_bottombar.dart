import 'package:flutter/material.dart';

class PageBottomBar extends StatefulWidget {
  final Function(int) onPageChange;
  final int totalPages;
  final int currentPage;

  PageBottomBar({
    required this.onPageChange,
    required this.totalPages,
    required this.currentPage,
  });

  @override
  _PageBottomBarState createState() => _PageBottomBarState();
}
class _PageBottomBarState extends State<PageBottomBar> {
  final TextEditingController bottomPageController = TextEditingController();

  @override
  void didUpdateWidget(PageBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPage != oldWidget.currentPage) {
      bottomPageController.text = widget.currentPage.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () {
              if (widget.currentPage > 1) {
                widget.onPageChange(widget.currentPage - 1);
              }
            },
            icon: Icon(Icons.chevron_left),
          ),
          Container(
            width: 50,
            child: TextField(
              controller: bottomPageController,
              decoration: InputDecoration(
                hintText: widget.currentPage.toString(),
              ),
              textAlign: TextAlign.center,
              onSubmitted: (value) {
                int newPageIndex = int.tryParse(value) ?? widget.currentPage;
                if (newPageIndex > 0 && newPageIndex <= widget.totalPages) {
                  widget.onPageChange(newPageIndex);
                }
              },
            ),
          ),
          IconButton(
            onPressed: () {
              if (widget.currentPage < widget.totalPages) {
                widget.onPageChange(widget.currentPage + 1);
              }
            },
            icon: Icon(Icons.chevron_right),
          ),
          SizedBox(width: 20),
          Text("共${widget.totalPages}页"),
        ],
      ),
    );
  }
}