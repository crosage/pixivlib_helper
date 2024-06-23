import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tagselector/components/elevated_button.dart';
import 'package:tagselector/pages/image_list_page.dart';
import 'package:tagselector/pages/setting_liblist.dart';
import 'package:tagselector/pages/setting_pixivtoken.dart';
import 'package:tagselector/pages/setting_taglist.dart';

class SettingPage extends StatefulWidget {
  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final List<Widget> _pages = [TagList(), LibList()];
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          VerticalDivider(),
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconLabelButton(
                onPress: () {
                  setState(() {
                    index = 0;
                  });
                },
                icon: Icon(Icons.label),
                text: "Tag列表",
                isSelected: index == 0, // 判断是否被选中
              ),
              Divider(),
              IconLabelButton(
                onPress: () {
                  setState(() {
                    index = 1;
                  });
                },
                icon: Icon(Icons.warehouse),
                text: "仓库列表",
                isSelected: index == 1, // 判断是否被选中
              ),
            ],
          ),
          VerticalDivider(),
          Expanded(child: _pages[index]), // 使用 Expanded 以确保 _pages 填满剩余空间
        ],
      ),
    );
  }
}