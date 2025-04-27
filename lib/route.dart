import 'package:get/get.dart';
import 'package:tagselector/pages/grid_image_view.dart';
import 'package:tagselector/pages/image_follow_page.dart';
import 'package:tagselector/pages/image_index_page.dart';
import 'package:tagselector/pages/setting_page.dart';

class AscentRoutes {
  static final List<GetPage> getPages = [
    GetPage(
      name: "/",
      page: () => ImageListPage(),
      transition: Transition.leftToRight,
    ),
    GetPage(
      name: "/following",
      page: () => FollowingPage(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: "/setting",
      page: () => SettingPage(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: "/gridView",
      page: () => ImageGrid(),
      transition: Transition.rightToLeft,
    )
  ];
}
