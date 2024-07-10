import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:tagselector/utils.dart';

import '../model/tag_model.dart';

class TagCountPage extends StatefulWidget {
  @override
  _TagCountPageState createState() => _TagCountPageState();
}

class _TagCountPageState extends State<TagCountPage> {
  List<ExtendedTag> tagData = [];

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    final url = 'http://127.0.0.1:23333/api/tag/tag-statistics';
    final response = await http.get(Uri.parse(url));
    print(response.statusCode);
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      final tagsJson = jsonData['data']['tags'];
      List<ExtendedTag> allTags = tagsJson.map<ExtendedTag>((tagJson) => ExtendedTag.fromJson(tagJson)).toList();

      allTags.sort((a, b) => b.count.compareTo(a.count));

      List<ExtendedTag> topTags = allTags.length > 40 ? allTags.sublist(0, 40) : allTags;

      int sumCounts = 0;
      if (allTags.length > 40) {
        for (var i = 40; i < allTags.length; i++) {
          sumCounts += allTags[i].count;
        }
        topTags.add(ExtendedTag(id:0,name: 'Other', count: sumCounts));
      }

      setState(() {
        tagData = topTags;
      });
    } else {
      throw Exception('Failed to load data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('tag统计'),
      ),
      body: Center(
        child: tagData.isEmpty
            ? CircularProgressIndicator()
            : SfCircularChart(
          title: ChartTitle(text: 'tag统计'),
          legend: Legend(isVisible: true),
          series: <PieSeries<ExtendedTag, String>>[
            PieSeries<ExtendedTag, String>(
              dataSource: tagData,
              pointColorMapper: (ExtendedTag data, _) => getRandomColor(data.name.hashCode),
              xValueMapper: (ExtendedTag data, _) => data.name,
              yValueMapper: (ExtendedTag data, _) => data.count.toDouble(),
              dataLabelSettings: DataLabelSettings(isVisible: true),

            )
          ],
        ),
      ),
    );
  }
}
