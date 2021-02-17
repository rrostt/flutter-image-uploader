import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthModel extends ChangeNotifier {
  String _token;

  String get token => _token;

  Future<void> init() async {
    var prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  Future<void> setToken(String token) async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);

    _token = token;
    notifyListeners();
  }
}
