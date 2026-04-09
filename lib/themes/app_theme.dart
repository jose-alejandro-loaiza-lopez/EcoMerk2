import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get defaultTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    );
  }
}
