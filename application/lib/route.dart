import 'package:get/get.dart';
import 'package:tagselector/pages/image_list_page.dart';
import 'package:tagselector/pages/setting_page.dart';

class AscentRoutes {
  static final List<GetPage> getPages = [
    GetPage(
      name: "/",
      page: () => ImageListPage(),
    ),
    GetPage(
      name: "/setting",
      page: () => SettingPage(),
    ),
  ];
}
