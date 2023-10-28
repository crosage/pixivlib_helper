import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tagselector/pages/image_list_page.dart';

class SettingPage extends StatefulWidget {
  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF5bc2e7),
        title: Text('pixiv_helper'),
      ),
      body: Row(
        children: [
          Column(
            children: [
              IconButton(
                onPressed: () {
                  Get.to(
                    () => ImageListPage(),
                    transition: Transition.leftToRight,
                    duration: Duration(milliseconds: 500),
                  );
                },
                icon: Icon(Icons.settings),
              ),
            ],
          ),
          Column(
            children: [
              Text("data"),
            ],
          )
        ],
      ),
    );
  }
}
