import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tagselector/components/elevated_button.dart';
import 'package:tagselector/components/sidebar.dart';
import 'package:tagselector/pages/image_list_page.dart';
import 'package:tagselector/pages/setting_liblist.dart';
import 'package:tagselector/pages/setting_taglist.dart';

class SettingPage extends StatefulWidget {
  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final List<Widget> _pages = [
    TagList(),
    LibList(),
  ];
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF5bc2e7),
        title: Text('pixiv_helper'),
      ),
      body: Row(
        children: [
          Sidebar(
            iconButtons: [
              IconButton(
                onPressed: () {
                  Get.toNamed("/");
                },
                icon: Icon(Icons.table_rows),
              ),
              IconButton(
                onPressed: () {
                  Get.toNamed("/gridView");
                },
                icon: Icon(Icons.apps_outlined),
              ),
            ],
          ),
          VerticalDivider(),
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconLabelButton(
                  onPress: () {
                    setState(() {
                      print("******");
                      index = 0;
                    });
                  },
                  icon: Icon(
                    Icons.label,
                    // color: Colors.blueAccent,
                  ),
                  text: "Tag列表"),
              Divider(),
              IconLabelButton(
                  onPress: () {
                    setState(() {
                      index = 1;
                    });
                  },
                  icon: Icon(
                    Icons.warehouse,
                    // color: Colors.blueAccent,
                  ),
                  text: "仓库列表"),
              Divider(),
              IconLabelButton(
                  onPress: () {
                    setState(() {
                      index = 2;
                    });
                  },
                  icon: Icon(
                    Icons.cookie,
                    // color: Colors.blueAccent,
                  ),
                  text: "Pixiv token"),
            ],
          ),
          VerticalDivider(),
          _pages[index]
        ],
      ),
    );
  }
}
