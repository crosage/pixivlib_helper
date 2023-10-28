import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tagselector/route.dart';

void main() async {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      initialRoute: "/",
      title: "TagSelector",
      getPages: AscentRoutes.getPages,
    );
  }
}
