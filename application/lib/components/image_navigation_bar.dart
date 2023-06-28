import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MyBottomAppBar extends StatefulWidget {
  final Function nextPage;
  final Function lastPage;

  const MyBottomAppBar({
    super.key,
    required this.nextPage,
    required this.lastPage,
  });

  @override
  _MyBottomAppBarState createState() => _MyBottomAppBarState();
}

class _MyBottomAppBarState extends State<MyBottomAppBar> {
  int _index = 0;
  bool isEdting = false;

  void _lastPage() {
    _index = _index > 0 ? _index - 1 : 0;
    widget.lastPage();
  }

  void _nextPage() {
    _index = _index + 1;
    widget.nextPage();
  }

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(onPressed: _lastPage, icon: Icon(Icons.arrow_back)),
          Container(
            width: 30,
            child: isEdting == true
                ? TextField(
                    decoration: InputDecoration(
                      hintText: (_index + 1).toString(),
                    ),
                  )
                : Text((_index + 1).toString()),
          ),
          IconButton(onPressed: _nextPage, icon: Icon(Icons.arrow_forward)),
        ],
      ),
    );
  }
}
