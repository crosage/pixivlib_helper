import 'package:flutter/material.dart';
import 'dart:math';

Color getRandomColor(int seed) {
  final random = Random(seed);
  int r, g, b;
  do {
    r = random.nextInt(256);
    g = random.nextInt(256);
    b = random.nextInt(256);
  } while (r + g + b <= 600);
  return Color.fromARGB(
    255,
    r,
    g,
    b,
  );
}