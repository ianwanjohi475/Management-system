import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive_ce.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/ids.dart';
import '../data/models/models.dart';
import '../data/storage/local_db.dart';

/// Accounts live on this device. Passwords are salted and stretched; never stored raw.
class AuthController extends ChangeNotifier {
  late Box<String> _accounts;
  late Box _settings;

  UserAccount? _user;
  UserAccount? get user => _user;
  bool get isLoggedIn => _user != null;

  bool get onboardingSeen => _settings.get('onboardingSeen', defaultValue: false) == true;
  ThemeMode get themeMode => ThemeMode.values.firstWhere((m) => m.name == _settings.get('themeMode'), orElse: () => ThemeMode.light);
  String? get lastEmail => _settings.get('lastEmail') as String?;

  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  Future<void> init() async {
    _accounts = await LocalDb.open('accounts');
    _settings = await LocalDb.openRaw('settings');
    final current = _settings.get('currentUser') as String?;
    if (current != null) _user = _read(current);
  }

  UserAccount? _read(String id) {
    final raw = _accounts.get(id);
    if (raw == null) return null;
    try {
      return UserAccount.fromJson(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Iterable<UserAccount> get _all sync* {
    for (final k in _accounts.keys) {
      final u = _read('$k');
      if (u != null) yield u;
    }
  }

  UserAccount? _byEmail(String email) {
    final e = email.trim().toLowerCase();
    for (final u in _all) {
      if (u.email == e) return u;
    }
    return null;
  }

  static String _salt() {
    final r = Random.secure();
    return base64UrlEncode(List.generate(16, (_) => r.nextInt(256)));
  }

  static String _hash(String password, String salt) {
    List<int> bytes = utf8.encode('$salt:$password');
    for (var i = 0; i < 2000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Encode(bytes);
  }

  Future<void> setOnboardingSeen() => _settings.put('onboardingSeen', true);

  Future<void> setThemeMode(ThemeMode mode) async {
    await _settings.put('themeMode', mode.name);
    notifyListeners();
  }

  Future<UserAccount> signUp({required String name, required String email, required String phone, required String password}) async {
    final e = email.trim().toLowerCase();
    if (_byEmail(e) != null) {
      throw const AuthException('An account with this email already exists. Try logging in instead.');
    }
    final salt = _salt();
    final user = UserAccount(
      id: newId(),
      name: name.trim(),
      email: e,
      phone: phone.trim(),
      passwordHash: _hash(password, salt),
      salt: salt,
      createdAt: DateTime.now(),
    );
    await _save(user);
    await _setSession(user, remember: true);
    return user;
  }

  Future<UserAccount> login(String email, String password, {bool remember = true}) async {
    final now = DateTime.now();
    if (_lockedUntil != null && now.isBefore(_lockedUntil!)) {
      final s = _lockedUntil!.difference(now).inSeconds + 1;
      throw AuthException('Too many attempts. Try again in $s seconds.');
    }
    // A short pause makes guessing passwords slow.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final user = _byEmail(email);
    if (user == null) {
      _registerFailure();
      throw const AuthException('No account found with that email. Check it or create an account.');
    }
    if (_hash(password, user.salt) != user.passwordHash) {
      _registerFailure();
      final left = 5 - _failedAttempts;
      throw AuthException(left > 0 ? 'Incorrect password. $left ${left == 1 ? 'attempt' : 'attempts'} left.' : 'Too many attempts. Try again in 30 seconds.');
    }
    _failedAttempts = 0;
    _lockedUntil = null;
    await _setSession(user, remember: remember);
    return user;
  }

  void _registerFailure() {
    _failedAttempts++;
    if (_failedAttempts >= 5) {
      _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
      _failedAttempts = 0;
    }
  }

  /// Offline reset: the email and phone number together prove ownership.
  Future<void> resetPassword({required String email, required String phone, required String newPassword}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final user = _byEmail(email);
    final digits = RegExp(r'\d');
    String norm(String p) {
      final d = digits.allMatches(p).map((m) => m[0]).join();
      return d.length > 9 ? d.substring(d.length - 9) : d;
    }

    if (user == null || norm(user.phone) != norm(phone)) {
      throw const AuthException("Those details don't match any account on this phone.");
    }
    final salt = _salt();
    await _save(user.copyWith(passwordHash: _hash(newPassword, salt), salt: salt));
  }

  Future<void> changePassword(String current, String next) async {
    final u = _user;
    if (u == null) throw const AuthException('Please log in again.');
    if (_hash(current, u.salt) != u.passwordHash) {
      throw const AuthException('Your current password is incorrect.');
    }
    final salt = _salt();
    final updated = u.copyWith(passwordHash: _hash(next, salt), salt: salt);
    await _save(updated);
    _user = updated;
    notifyListeners();
  }

  Future<void> updateProfile({required String name, required String phone}) async {
    final u = _user;
    if (u == null) return;
    final updated = u.copyWith(name: name.trim(), phone: phone.trim());
    await _save(updated);
    _user = updated;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    final u = _user;
    if (u == null) return;
    await _accounts.delete(u.id);
    await logout();
  }

  Future<void> logout() async {
    _user = null;
    await _settings.delete('currentUser');
    notifyListeners();
  }

  Future<void> _save(UserAccount u) async {
    try {
      await _accounts.put(u.id, jsonEncode(u.toJson()));
    } catch (e) {
      throw StorageException('Could not save your account on this phone.', cause: e);
    }
  }

  Future<void> _setSession(UserAccount user, {required bool remember}) async {
    _user = user;
    await _settings.put('lastEmail', user.email);
    if (remember) {
      await _settings.put('currentUser', user.id);
    } else {
      await _settings.delete('currentUser');
    }
    notifyListeners();
  }
}
