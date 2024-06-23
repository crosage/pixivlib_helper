import 'package:flutter/material.dart';

class IconLabelButton extends StatelessWidget {
  final Function() onPress;
  final Icon icon;
  final String text;
  final bool isSelected;
  final double height;

  IconLabelButton(
      {required this.onPress,
        required this.icon,
        required this.text,
        required this.isSelected,
        this.height = 50});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPress,
      highlightColor: Colors.grey,
      splashColor: Colors.grey,
      child: Container(
        height: height,
        width: 200,
        color: isSelected ? Colors.grey[200] : Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                icon,
                SizedBox(width: 8),
                Text(text),
              ],
            ),
            Icon(Icons.chevron_right)
          ],
        ),
      ),
    );
  }
}
