import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:tagselector/components/modify_text.dart';

class TokenSetting extends StatefulWidget {
  @override
  _TokenSettingState createState() => _TokenSettingState();
}

class _TokenSettingState extends State<TokenSetting> {
  String access = "";
  String refresh = "";
  String updateTime = "";
  List<bool> isEdting = [];

  @override
  void initState() {
    super.initState();
    for (int i = 1; i <= 100; i++) isEdting.add(false);
  }

  Future<void> getTokens() async {
    final response =
        await http.get(Uri.parse("http://127.0.0.1:8000/api/utils/token"));
    Map<String, dynamic> map = json.decode(utf8.decode(response.bodyBytes));
    access = map["access"];
    refresh = map["refresh"];
    updateTime = map["update_time"];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(),
        Text(
          "token相关",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 30.0,
          ),
        ),
        Divider(),
        FutureBuilder(
          future: getTokens(),
          builder: (context, snapshot) {
            return Container(
              width: MediaQuery.of(context).size.width - 400,
              height: MediaQuery.of(context).size.height - 200,
              child: ListView(
                //shrinkWrap: true,
                children: [
                  Text(
                    "当前token",
                    style: TextStyle(
                      // fontWeight: FontWeight.bold,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 30),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              "当前access_token:",
                              style: TextStyle(
                                // fontWeight: FontWeight.bold,
                                fontSize: 15.0,
                              ),
                            ),
                            ModifyText(
                              hintText: access,
                              onDelete: () async {},
                              onUpdate: () {},
                            ),
                          ],
                        ),
                        Divider(),
                        Row(
                          children: [
                            Text(
                              "当前refresh_token:",
                              style: TextStyle(
                                // fontWeight: FontWeight.bold,
                                fontSize: 15.0,
                              ),
                            ),
                            ModifyText(
                              hintText: refresh,
                              onDelete: () async {},
                              onUpdate: () {},
                            ),
                          ],
                        ),
                        Divider(),
                        SizedBox(
                          height: 10,
                        ),
                        Row(children: [
                          Text(
                            "更新时间:${updateTime}",
                            style: TextStyle(
                              // fontWeight: FontWeight.bold,
                              fontSize: 15.0,
                            ),
                          )
                        ]),
                        SizedBox(
                          height: 20,
                        )
                        // Divider(),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      final response = await http.put(
                          Uri.parse("http://127.0.0.1:8000/api/utils/token"));
                      Map<String, dynamic> map =
                          json.decode(utf8.decode(response.bodyBytes));
                      setState(() {
                        access = map["access"];
                        refresh = map["refresh"];
                        updateTime = map["update_time"];
                        print(map);
                      });
                    },
                    child: Text(
                      "刷新access_token（刷新时需要开启梯子）",
                      style: TextStyle(
                        // fontWeight: FontWeight.bold,
                        fontSize: 20.0,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
