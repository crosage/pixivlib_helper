import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tagselector/components/setting_button.dart';
import 'package:tagselector/pages/setting_page.dart';

class Sidebar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          onPressed: () {
            Get.toNamed("/setting");
          },
          icon: Icon(Icons.settings),
        ),
      ],
    );
  }
}
