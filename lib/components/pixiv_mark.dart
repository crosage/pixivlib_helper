import 'package:flutter/material.dart';

class PixivMark extends StatelessWidget {
  final double size;
  final double radius;

  const PixivMark({
    super.key,
    this.size = 30,
    this.radius = 9,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0A84FF),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        'P',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.56,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
