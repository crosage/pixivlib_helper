import 'package:flutter/material.dart';

class IconLabelButton extends StatelessWidget {
  final Function() onPress;
  final Icon icon;
  final String text;
  double height;

  IconLabelButton(
      {required this.onPress,
      required this.icon,
      required this.text,
      this.height = 50});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        onPress();
      },
      child: Container(
        height: height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [icon, Text(text)],
        ),
      ),
    );
  }
}
