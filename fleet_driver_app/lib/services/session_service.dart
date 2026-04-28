import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/admin/admin_dashboard.dart';
import '../screens/common/select_role_screen.dart';
import '../screens/driver/dashboard_screen.dart';

class SessionService {
  static const String _tokenKey = 'token';
  static const String _roleKey = 'role';
  static const String _nameKey = 'name';
  static const String _userIdKey = 'user_id';

  static Future<void> saveDriverSession({
    required String token,
    required String name,
    required int userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_roleKey, 'DRIVER');
    await prefs.setString(_nameKey, name);
    await prefs.setInt(_userIdKey, userId);
  }

  static Future<void> saveAdminSession({
    required String token,
    required String name,
    required int userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_roleKey, 'ADMIN');
    await prefs.setString(_nameKey, name);
    await prefs.setInt(_userIdKey, userId);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_userIdKey);
  }

  static Future<Widget> resolveHome() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey)?.trim() ?? '';

    if (token.isEmpty) {
      return const SelectRoleScreen();
    }

    final role = (prefs.getString(_roleKey) ?? 'DRIVER').trim().toUpperCase();
    final savedName = prefs.getString(_nameKey)?.trim() ?? '';
    final userId = prefs.getInt(_userIdKey) ?? 0;

    if (role == 'ADMIN') {
      return const AdminDashboardScreen();
    }

    return DashboardScreen(
      driverName: savedName.isEmpty ? 'Driver' : savedName,
      driverId: userId,
    );
  }
}
