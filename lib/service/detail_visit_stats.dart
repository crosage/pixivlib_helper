import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DetailVisitRecord {
  final int pid;
  final String title;
  final String authorName;
  final List<String> tags;
  final int visitedAt;

  const DetailVisitRecord({
    required this.pid,
    required this.title,
    required this.authorName,
    required this.tags,
    required this.visitedAt,
  });

  Map<String, dynamic> toJson() => {
        'pid': pid,
        'title': title,
        'author_name': authorName,
        'tags': tags,
        'visited_at': visitedAt,
      };

  factory DetailVisitRecord.fromJson(Map<String, dynamic> json) {
    return DetailVisitRecord(
      pid: json['pid'] ?? 0,
      title: json['title'] ?? '',
      authorName: json['author_name'] ?? '',
      tags: (json['tags'] as List? ?? const [])
          .map((item) => item.toString())
          .where((value) => value.trim().isNotEmpty)
          .toList(),
      visitedAt: json['visited_at'] ?? 0,
    );
  }
}

class DetailVisitStats extends ChangeNotifier {
  static const String _storageKey = 'pixiv_helper.detail_visit_records_v1';
  static const String _fileName = 'detail_visit_records.json';
  static const int _maxRecords = 240;

  List<DetailVisitRecord>? _cachedRecords;

  DetailVisitStats._();

  static final DetailVisitStats instance = DetailVisitStats._();

  List<DetailVisitRecord> get records =>
      List<DetailVisitRecord>.unmodifiable(_cachedRecords ?? const []);

  Future<void> record({
    required int pid,
    required String title,
    required String authorName,
    required List<String> tags,
  }) async {
    if (pid <= 0) return;

    final records = List<DetailVisitRecord>.from(await _readRecords());
    records.insert(
      0,
      DetailVisitRecord(
        pid: pid,
        title: title.trim(),
        authorName: authorName.trim(),
        tags: tags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList(),
        visitedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ),
    );

    final deduped = <int, DetailVisitRecord>{};
    for (final record in records) {
      deduped.putIfAbsent(record.pid, () => record);
      if (deduped.length >= _maxRecords) break;
    }

    final updated = deduped.values.toList(growable: false);
    _cachedRecords = updated;
    notifyListeners();

    await Future.wait([
      _writeRecordsToFile(updated),
      _writeRecordsToPrefs(updated),
    ]);
  }

  Future<List<DetailVisitRecord>> loadRecords() async {
    final cached = _cachedRecords;
    if (cached != null) {
      return List<DetailVisitRecord>.unmodifiable(cached);
    }
    return _readRecords();
  }

  Future<List<DetailVisitRecord>> _readRecords() async {
    final fromFile = await _readRecordsFromFile();
    if (fromFile != null && fromFile.isNotEmpty) {
      _cachedRecords = List<DetailVisitRecord>.from(fromFile);
      return List<DetailVisitRecord>.from(_cachedRecords!);
    }

    final fromPrefs = await _readRecordsFromPrefs();
    _cachedRecords = List<DetailVisitRecord>.from(fromPrefs);
    if (fromPrefs.isNotEmpty) {
      unawaited(_writeRecordsToFile(fromPrefs));
    }
    return fromPrefs;
  }

  Future<List<DetailVisitRecord>?> _readRecordsFromFile() async {
    try {
      final file = await _storageFile();
      if (!await file.exists()) {
        return null;
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return null;
      }
      final records = _decodeRecords(raw);
      return records.isEmpty ? null : records;
    } catch (_) {
      return null;
    }
  }

  Future<List<DetailVisitRecord>> _readRecordsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) {
        return <DetailVisitRecord>[];
      }
      return _decodeRecords(raw);
    } catch (_) {
      return <DetailVisitRecord>[];
    }
  }

  Future<void> _writeRecordsToFile(List<DetailVisitRecord> records) async {
    try {
      final file = await _storageFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode(records.map((record) => record.toJson()).toList()),
        flush: true,
      );
    } catch (_) {
    }
  }

  Future<void> _writeRecordsToPrefs(List<DetailVisitRecord> records) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(records.map((record) => record.toJson()).toList()),
      );
    } catch (_) {
    }
  }

  Future<File> _storageFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, _fileName));
  }

  List<DetailVisitRecord> _decodeRecords(String raw) {
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => DetailVisitRecord.fromJson(Map<String, dynamic>.from(item)))
          .where((record) => record.pid > 0)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
