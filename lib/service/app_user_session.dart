import 'package:flutter/foundation.dart';
import 'package:tagselector/model/app_user_model.dart';
import 'package:tagselector/service/api_service.dart';

class AppUserSession extends ChangeNotifier {
  AppUserSession._();

  static final AppUserSession instance = AppUserSession._();

  List<AppUserModel> _users = const [];
  AppUserModel? _activeUser;
  bool _initialized = false;
  bool _initializing = false;
  bool _authenticated = false;
  String? _initializationError;

  List<AppUserModel> get users => _users;
  AppUserModel? get activeUser => _activeUser;
  int? get activeUserId => _activeUser?.id;
  bool get initialized => _initialized;
  bool get initializing => _initializing;
  bool get isAuthenticated => _authenticated && _activeUser != null;
  String? get initializationError => _initializationError;

  Future<void> initialize({bool force = false}) async {
    if (_initializing) {
      return;
    }
    if (_initialized && !force) {
      return;
    }

    _initializing = true;
    _initializationError = null;
    notifyListeners();

    try {
      await reload();
    } catch (error) {
      _users = const [];
      _activeUser = null;
      _authenticated = false;
      _initializationError = error.toString();
    } finally {
      _initializing = false;
      _initialized = true;
    }

    notifyListeners();
  }

  Future<void> reload() async {
    final response = await ApiService.instance.fetchAppUsers();
    _users = response.users;
    _activeUser = response.activeUser;
    _authenticated =
        _activeUser != null && _activeUser!.pixivUserId.trim().isNotEmpty;
    notifyListeners();
  }

  Future<void> switchUser(int userId) async {
    final response = await ApiService.instance.switchAppUser(userId);
    _users = response.users;
    _activeUser = response.activeUser;
    _authenticated =
        _activeUser != null && _activeUser!.pixivUserId.trim().isNotEmpty;
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
    notifyListeners();
  }

  Future<void> logout() async {
    final response = await ApiService.instance.logoutCurrentUser();
    _users = response.users;
    _activeUser = response.activeUser;
    _authenticated =
        _activeUser != null && _activeUser!.pixivUserId.trim().isNotEmpty;
    notifyListeners();
  }
}
