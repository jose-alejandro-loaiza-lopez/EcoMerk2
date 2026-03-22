import 'package:flutter/material.dart';
import '../features/auth/login/login_page.dart';
import '../features/auth/register/register_page.dart';
import '../features/home/home_page.dart';
import '../features/busqueda/search_page.dart';
import '../features/favorites/favorites_page.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String favorites = '/favorites';
  static const String search = '/search';

  static Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginPage(),
    register: (context) => const RegisterPage(),
    home: (context) => const HomePage(),
    favorites: (context) => const FavoritesPage(),
    search: (context) => const SearchPage(),
  };
}