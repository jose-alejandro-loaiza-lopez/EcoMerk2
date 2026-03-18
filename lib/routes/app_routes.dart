import 'package:flutter/material.dart';
import '../features/auth/login/login_page.dart';
import '../features/home/home_page.dart';

class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';

  static Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginPage(),
    home: (context) => const HomePage(),
  };
}