import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_chat/account/account_repo.dart';

abstract class Settings {
  static const String isAccountSaved = 'isAccountSaved';
  static const String wasExtended = 'wasShort';
  static const String username = 'username';
  static const String password = 'password';
  static const String domain = 'domain';
  static const String port = 'port';
  static const String rememberMe = 'rememberMe';
  static const String wasLoggedIn = 'wasLoggedIn';

  void setAccountData(XmppAccount account);
  XmppAccount? getAccountData();
  void setBool(String setting, bool value);
  bool? getBool(String setting);
  void setString(String setting, String value);
  String? getString(String setting);
  void setInt(String setting, int value);
  int? getInt(String setting);
  void remove(String setting);
  int getDefaultPort();
  void forgetAccount();
  void init();
  Future<bool> isInitialized();
}

class SettingsImpl implements Settings {
  final Completer<bool> _initialized = Completer();
  XmppAccount? _account;
  late SharedPreferences _prefs;

  SettingsImpl() { init(); }

  @override
  void init() {
    SharedPreferences.getInstance().then((prefs) {
      _prefs = prefs;
      _initialized.complete(true);
    });
  }

  @override
  XmppAccount? getAccountData() {
    if (_account != null) return _account;
    if (_prefs.getBool(Settings.isAccountSaved) == true) {
      final u = _prefs.getString(Settings.username);
      final p = _prefs.getString(Settings.password);
      final d = _prefs.getString(Settings.domain);
      final port = _prefs.getInt(Settings.port);
      if (u != null && p != null && d != null && port != null) {
        _account = XmppAccount(u, u, d, p, port);
        return _account;
      }
    }
    return null;
  }

  @override
  void setAccountData(XmppAccount account) {
    _account = account;
    if (getBool(Settings.rememberMe) == true) {
      _prefs.setString(Settings.username, account.username);
      _prefs.setString(Settings.password, account.password);
      _prefs.setString(Settings.domain, account.domain);
      _prefs.setInt(Settings.port, account.port);
      _prefs.setBool(Settings.isAccountSaved, true);
    }
  }

  @override
  bool? getBool(String setting) => _prefs.getBool(setting);
  @override
  void setBool(String setting, bool value) => _prefs.setBool(setting, value);
  @override
  String? getString(String setting) => _prefs.getString(setting);
  @override
  void setString(String setting, String value) => _prefs.setString(setting, value);
  @override
  int? getInt(String setting) => _prefs.getInt(setting);
  @override
  void setInt(String setting, int value) => _prefs.setInt(setting, value);
  @override
  void remove(String setting) => _prefs.remove(setting);
  @override
  void forgetAccount() {
    _account = null;
    remove(Settings.isAccountSaved);
    remove(Settings.username);
    remove(Settings.password);
    remove(Settings.domain);
    remove(Settings.port);
  }
  @override
  int getDefaultPort() => 5222;
  @override
  Future<bool> isInitialized() => _initialized.future;
}
