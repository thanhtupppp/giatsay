import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user.dart';
import '../../config/constants.dart';
import '../database/database_helper.dart';

class AuthService {
  static final AuthService instance = AuthService._init();
  AuthService._init();

  User? _currentUser;
  User? get currentUser => _currentUser;

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  // Public method for password hashing (used in settings)
  String hashPasswordPublic(String password) {
    return _hashPassword(password);
  }

  Future<User?> login(String username, String password) async {
    try {
      final db = DatabaseHelper.instance;
      final hashedPassword = _hashPassword(password);

      final results = await db.query(
        'users',
        where: 'username = ? AND is_active = 1',
        whereArgs: [username],
      );

      if (results.isEmpty) {
        return null;
      }

      final userData = results.first;
      
      // Check password
      if (userData['password_hash'] != hashedPassword) {
        return null;
      }

      _currentUser = User.fromMap(userData);

      // Save session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.keyUserId, _currentUser!.id!);
      await prefs.setString(AppConstants.keyUsername, _currentUser!.username);
      await prefs.setString(AppConstants.keyUserRole, _currentUser!.role);

      return _currentUser;
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyUserId);
    await prefs.remove(AppConstants.keyUsername);
    await prefs.remove(AppConstants.keyUserRole);
  }

  Future<bool> isLoggedIn() async {
    if (_currentUser != null) return true;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(AppConstants.keyUserId);

    if (userId == null) return false;

    // Try to restore session
    try {
      final db = DatabaseHelper.instance;
      final results = await db.query(
        'users',
        where: 'id = ? AND is_active = 1',
        whereArgs: [userId],
      );

      if (results.isEmpty) return false;

      _currentUser = User.fromMap(results.first);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<User?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(AppConstants.keyUserId);

    if (userId == null) return null;

    try {
      final db = DatabaseHelper.instance;
      final results = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (results.isEmpty) return null;

      _currentUser = User.fromMap(results.first);
      return _currentUser;
    } catch (e) {
      return null;
    }
  }

  Future<User?> register({
    required String username,
    required String password,
    required String fullName,
    required String role,
    String? phone,
    String? email,
  }) async {
    try {
      final db = DatabaseHelper.instance;

      // Check if username already exists
      final existing = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [username],
      );

      if (existing.isNotEmpty) {
        throw Exception('Tên đăng nhập đã tồn tại');
      }

      final hashedPassword = _hashPassword(password);
      final user = User(
        username: username,
        passwordHash: hashedPassword,
        fullName: fullName,
        role: role,
        phone: phone,
        email: email,
      );

      final id = await db.insert('users', user.toMap());
      return user.copyWith(id: id);
    } catch (e) {
      return null;
    }
  }

  Future<bool> changePassword(int userId, String oldPassword, String newPassword) async {
    try {
      final db = DatabaseHelper.instance;
      final hashedOldPassword = _hashPassword(oldPassword);
      final hashedNewPassword = _hashPassword(newPassword);

      final results = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (results.isEmpty) return false;

      final user = User.fromMap(results.first);
      if (user.passwordHash != hashedOldPassword) return false;

      await db.update(
        'users',
        {
          'password_hash': hashedNewPassword,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [userId],
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  bool hasPermission(String requiredRole) {
    if (_currentUser == null) return false;

    // Admin has all permissions
    if (_currentUser!.role == AppConstants.roleAdmin) return true;

    // Check specific role
    if (requiredRole == AppConstants.roleAdmin) {
      return _currentUser!.role == AppConstants.roleAdmin;
    }

    if (requiredRole == AppConstants.roleManager) {
      return _currentUser!.role == AppConstants.roleAdmin ||
          _currentUser!.role == AppConstants.roleManager;
    }

    return true; // Employee level
  }
}
