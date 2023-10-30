import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tagselector/components/elevated_button.dart';
import 'package:tagselector/components/sidebar.dart';
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
          Sidebar(
            iconButtons: [
              IconButton(
                onPressed: () {
                  Get.toNamed("/setting");
                },
                icon: Icon(Icons.settings),
              ),
              IconButton(
                onPressed: () {
                  Get.toNamed("/");
                },
                icon: Icon(Icons.list),
              ),
              IconButton(
                onPressed: () {
                  Get.toNamed("/gridView");
                },
                icon: Icon(Icons.apps_outlined),
              ),
            ],
          ),
          Column(
            children: [
              IconLabelButton(
                  onPress: () {},
                  icon: Icon(
                    Icons.label,
                    color: Colors.blueAccent,
                  ),
                  text: "Tag列表"),
              Divider(),
              IconLabelButton(
                  onPress: () {},
                  icon: Icon(
                    Icons.warehouse,
                    color: Colors.blueAccent,
                  ),
                  text: "仓库列表"),
              Divider(),
              IconLabelButton(
                  onPress: () {},
                  icon: Icon(
                    Icons.cookie,
                    color: Colors.blueAccent,
                  ),
                  text: "Pixiv token"),
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
