import 'package:get/get.dart';
import 'package:tagselector/pages/grid_image_view.dart';
import 'package:tagselector/pages/image_list_page.dart';
import 'package:tagselector/pages/setting_page.dart';

class AscentRoutes {
  static final List<GetPage> getPages = [
    GetPage(
      name: "/",
      page: () => ImageListPage(),
      transition: Transition.leftToRight,
    ),
    GetPage(
      name: "/setting",
      page: () => SettingPage(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: "/gridView",
      page: () => ImageGrid(),
    )
  ];
}
