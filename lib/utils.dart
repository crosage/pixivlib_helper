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

String formatUnixTimestamp(int seconds) {
  if (seconds <= 0) {
    return '';
  }

  final dateTime = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '${dateTime.year}-$month-$day $hour:$minute';
}
