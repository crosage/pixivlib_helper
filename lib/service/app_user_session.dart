import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tagselector/model/app_user_model.dart';
import 'package:tagselector/service/api_service.dart';

class AppUserSession extends ChangeNotifier {
  AppUserSession._();

  static final AppUserSession instance = AppUserSession._();
  static const String _rememberedUserIdKey = 'pixiv_helper.remembered_user_id';
  static const String _knownUserIdsKey = 'pixiv_helper.known_user_ids';

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
    final rememberedUserId = await _loadRememberedUserId();
    final knownUserIds = await _loadKnownUserIds();
    _users = _visibleUsersForLocalClient(response.users, knownUserIds);
    _activeUser = _findRememberedUser(response.users, rememberedUserId);
    _authenticated =
        _activeUser != null && _activeUser!.pixivUserId.trim().isNotEmpty;
    notifyListeners();
  }

  Future<void> switchUser(int userId) async {
    final response = await ApiService.instance.switchAppUser(userId);
    final activeUser = response.activeUser;
    if (activeUser != null && activeUser.id > 0) {
      await _rememberUserId(activeUser.id);
      await _addKnownUserId(activeUser.id);
    }
    final rememberedUserId = activeUser?.id ?? await _loadRememberedUserId();
    final knownUserIds = await _loadKnownUserIds();
    _users = _visibleUsersForLocalClient(response.users, knownUserIds);
    _activeUser = _findRememberedUser(response.users, rememberedUserId);
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
    final activeUser = response.activeUser;
    if (activeUser != null && activeUser.id > 0) {
      await _rememberUserId(activeUser.id);
      await _addKnownUserId(activeUser.id);
    }
    final rememberedUserId = activeUser?.id ?? await _loadRememberedUserId();
    final knownUserIds = await _loadKnownUserIds();
    _users = _visibleUsersForLocalClient(response.users, knownUserIds);
    _activeUser = _findRememberedUser(response.users, rememberedUserId);
    _authenticated = _activeUser != null;
    notifyListeners();
  }

  Future<void> logout() async {
    final response = await ApiService.instance.logoutCurrentUser();
    final currentUserId = _activeUser?.id;
    await _clearRememberedUserId();
    if (currentUserId != null && currentUserId > 0) {
      await _removeKnownUserId(currentUserId);
    }
    final knownUserIds = await _loadKnownUserIds();
    _users = _visibleUsersForLocalClient(response.users, knownUserIds);
    _activeUser = null;
    _authenticated = false;
    notifyListeners();
  }

  Future<int?> _loadRememberedUserId() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getInt(_rememberedUserIdKey);
    if (value == null || value <= 0) {
      return null;
    }
    return value;
  }

  Future<void> _rememberUserId(int userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_rememberedUserIdKey, userId);
  }

  Future<void> _clearRememberedUserId() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_rememberedUserIdKey);
  }

  Future<Set<int>> _loadKnownUserIds() async {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_knownUserIdsKey) ?? const [];
    return values
        .map((value) => int.tryParse(value))
        .whereType<int>()
        .where((value) => value > 0)
        .toSet();
  }

  Future<void> _saveKnownUserIds(Set<int> userIds) async {
    final preferences = await SharedPreferences.getInstance();
    final values = userIds.map((value) => '$value').toList()..sort();
    await preferences.setStringList(_knownUserIdsKey, values);
  }

  Future<void> _addKnownUserId(int userId) async {
    final userIds = await _loadKnownUserIds();
    userIds.add(userId);
    await _saveKnownUserIds(userIds);
  }

  Future<void> _removeKnownUserId(int userId) async {
    final userIds = await _loadKnownUserIds();
    userIds.remove(userId);
    await _saveKnownUserIds(userIds);
  }

  AppUserModel? _findRememberedUser(
    List<AppUserModel> users,
    int? rememberedUserId,
  ) {
    if (rememberedUserId == null) {
      return null;
    }
    for (final user in users) {
      if (user.id == rememberedUserId) {
        return user;
      }
    }
    return null;
  }

  List<AppUserModel> _visibleUsersForLocalClient(
    List<AppUserModel> users,
    Set<int> knownUserIds,
  ) {
    if (knownUserIds.isEmpty) {
      return const [];
    }
    return users.where((user) => knownUserIds.contains(user.id)).toList();
  }
}
