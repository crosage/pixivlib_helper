import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tagselector/model/app_user_model.dart';
import 'package:tagselector/service/api_service.dart';

class AppUserSession extends ChangeNotifier {
  AppUserSession._();

  static final AppUserSession instance = AppUserSession._();

  static const _activeUserIdKey = 'active_app_user_id_v1';

  List<AppUserModel> _users = const [];
  AppUserModel? _activeUser;
  bool _initialized = false;
  bool _authenticated = false;

  List<AppUserModel> get users => _users;
  AppUserModel? get activeUser => _activeUser;
  int? get activeUserId => _activeUser?.id;
  bool get initialized => _initialized;
  bool get isAuthenticated => _authenticated && _activeUser != null;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    await reload();
    _initialized = true;
    notifyListeners();
  }

  Future<void> reload() async {
    final response = await ApiService.instance.fetchAppUsers();
    _users = response.users;
    _activeUser = response.activeUser;
    _authenticated =
        _activeUser != null && _activeUser!.pixivUserId.trim().isNotEmpty;
    await _persistActiveUserId(_activeUser?.id);
    notifyListeners();
  }

  Future<void> switchUser(int userId) async {
    final response = await ApiService.instance.switchAppUser(userId);
    _users = response.users;
    _activeUser = response.activeUser;
    _authenticated =
        _activeUser != null && _activeUser!.pixivUserId.trim().isNotEmpty;
    await _persistActiveUserId(_activeUser?.id);
    notifyListeners();
  }

  Future<void> createUser({
    required String name,
    String pixivUserId = '',
    bool setActive = true,
  }) async {
    final response = await ApiService.instance.createAppUser(
      name: name,
      pixivUserId: pixivUserId,
      setActive: setActive,
    );
    _users = response.users;
    _activeUser = response.activeUser;
    _authenticated =
        _activeUser != null && _activeUser!.pixivUserId.trim().isNotEmpty;
    await _persistActiveUserId(_activeUser?.id);
    notifyListeners();
  }

  Future<void> loginWithSession({
    required String session,
    String name = '',
  }) async {
    final response = await ApiService.instance.loginWithSession(
      session: session,
      name: name,
    );
    _users = response.users;
    _activeUser = response.activeUser;
    _authenticated = _activeUser != null;
    await _persistActiveUserId(_activeUser?.id);
    notifyListeners();
  }

  Future<int?> loadPersistedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_activeUserIdKey);
  }

  Future<void> _persistActiveUserId(int? userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId == null || userId <= 0) {
      await prefs.remove(_activeUserIdKey);
      return;
    }
    await prefs.setInt(_activeUserIdKey, userId);
  }
}
