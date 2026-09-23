import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tagselector/model/image_url_model.dart';

enum DownloadQuality {
  original('原图', '完整画质'),
  regular('标准图', '较省流量'),
  small('小图', '适合快速保存'),
  thumb('缩略图', '节省流量'),
  mini('迷你图', '最小文件');

  const DownloadQuality(this.label, this.description);

  final String label;
  final String description;

  String urlFor(ImageUrlsModel urls) => switch (this) {
        DownloadQuality.original => urls.original,
        DownloadQuality.regular => urls.regular,
        DownloadQuality.small => urls.small,
        DownloadQuality.thumb => urls.thumb,
        DownloadQuality.mini => urls.mini,
      };
}

class DownloadQualityStore extends ChangeNotifier {
  DownloadQualityStore._();

  static const _storageKey = 'pixiv_helper.download_quality_v1';
  static final instance = DownloadQualityStore._();

  DownloadQuality _quality = DownloadQuality.original;
  Future<void> _pendingSave = Future<void>.value();

  DownloadQuality get quality => _quality;

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getString(_storageKey);
      _quality = DownloadQuality.values.firstWhere(
        (quality) => quality.name == stored,
        orElse: () => DownloadQuality.original,
      );
    } catch (_) {
      _quality = DownloadQuality.original;
    }
    notifyListeners();
  }

  Future<void> setQuality(DownloadQuality quality) {
    final save = _pendingSave.then((_) async {
      if (_quality == quality) return;
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setString(_storageKey, quality.name)) {
        throw StateError('无法保存下载品质设置');
      }
      _quality = quality;
      notifyListeners();
    });
    _pendingSave = save.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return save;
  }
}
