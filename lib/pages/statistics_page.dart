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
  int start = 0, end = 20;
  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();
  bool _isChecked = true;

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
      List<ExtendedTag> allTags = tagsJson
          .map<ExtendedTag>((tagJson) => ExtendedTag.fromJson(tagJson))
          .toList();

      allTags.sort((a, b) => b.count.compareTo(a.count));

      List<ExtendedTag> selectedTags =
      allTags.sublist(start, end > allTags.length ? allTags.length : end);

      if (_isChecked == true && end < allTags.length) {
        int sumCounts = 0;
        for (var i = end; i < allTags.length; i++) {
          sumCounts += allTags[i].count;
        }
        selectedTags.add(ExtendedTag(id: 0, name: 'Other', count: sumCounts));
      }

      setState(() {
        tagData = selectedTags;
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
      body: Column(
        children: [
          Expanded(
            child: tagData.isEmpty
                ? CircularProgressIndicator()
                : SfCircularChart(
              title: ChartTitle(text: 'tag统计'),
              legend: Legend(isVisible: true),
              series: <PieSeries<ExtendedTag, String>>[
                PieSeries<ExtendedTag, String>(
                  dataSource: tagData,
                  pointColorMapper: (ExtendedTag data, _) =>
                      getRandomColor(data.name.hashCode),
                  xValueMapper: (ExtendedTag data, _) => data.name,
                  yValueMapper: (ExtendedTag data, _) =>
                      data.count.toDouble(),
                  dataLabelSettings: DataLabelSettings(isVisible: true),
                )
              ],
            ),
          ),
          Divider(),
          Container(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Checkbox(
                  value: _isChecked,
                  onChanged: (bool? value) {
                    setState(() {
                      _isChecked = value ?? false;
                      fetchData();
                      print(_isChecked);
                    });
                  },
                ),
                Text("是否显示其他"),
                SizedBox(width: 20,),
                Text("从"),
                Container(
                  width: 50,
                  child: TextField(
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(hintText:start.toString()),
                    controller: startController,
                    onSubmitted: (value) {
                      setState(() {
                        start = int.tryParse(value) ?? 0;
                        fetchData();
                      });
                    },
                  ),
                ),
                Text("到"),
                Container(
                  width: 50,
                  child: TextField(
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(hintText:end.toString()),
                    controller: endController,
                    onSubmitted: (value) {
                      setState(() {
                        end = int.tryParse(value) ?? 20;
                        fetchData();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
