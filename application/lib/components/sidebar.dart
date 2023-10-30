import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  final List<IconButton> iconButtons;

  Sidebar({required this.iconButtons});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: iconButtons,
    );
  }
}
