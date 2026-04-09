import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../views/auth/login_page.dart';
import '../views/auth/register_page.dart';
import '../views/home/home_page.dart';
import '../views/home/chat_page.dart';
import '../views/home/profile_page.dart';
import '../views/search/search_page.dart';
import '../views/favorites/favorites_page.dart';
import '../main.dart'; // For AuthCheck
import '../widgets/main_wrapper.dart';

class AppRoutes {
  static const String initial = '/'; // AuthCheck handles redirect
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String favorites = '/favorites';
  static const String search = '/search';
  static const String chat = '/chat';
  static const String profile = '/profile';

  static final GoRouter router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: initial,
        builder: (context, state) => const AuthCheck(),
      ),
      GoRoute(
        path: login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: register,
        builder: (context, state) => const RegisterPage(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainWrapper(child: child);
        },
        routes: [
          GoRoute(
            path: home,
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: favorites,
            builder: (context, state) => const FavoritesPage(),
          ),
          GoRoute(
            path: search,
            builder: (context, state) {
              final query = state.extra as String?;
              return SearchPage(key: UniqueKey(), initialQuery: query);
            },
          ),
          GoRoute(
            path: chat,
            builder: (context, state) => const ChatPage(),
          ),
          GoRoute(
            path: profile,
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
    ],
  );
}