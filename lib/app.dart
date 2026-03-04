import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'app_theme.dart';
import 'screens/auth/login_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notes',
      debugShowCheckedModeBanner: false,

      // ── Localizations (required by flutter_quill) ──
      localizationsDelegates: const [
        FlutterQuillLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
      ],

      // ── Light theme ──
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: AppTheme.indigo,
          secondary: AppTheme.violet,
          surface: AppTheme.lightSurface,
          background: AppTheme.lightBg,
        ),
        scaffoldBackgroundColor: AppTheme.lightBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppTheme.lightBg,
          elevation: 0,
          iconTheme: IconThemeData(color: AppTheme.lightText),
          titleTextStyle: TextStyle(
            color: AppTheme.lightText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        dividerColor: AppTheme.lightBorder,
        cardColor: AppTheme.lightCard,
      ),

      // ── Dark theme ──
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: AppTheme.indigo,
          secondary: AppTheme.violet,
          surface: AppTheme.darkCard,
          background: AppTheme.darkBg,
        ),
        scaffoldBackgroundColor: AppTheme.darkBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppTheme.darkBg,
          elevation: 0,
          iconTheme: IconThemeData(color: AppTheme.darkText),
          titleTextStyle: TextStyle(
            color: AppTheme.darkText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        dividerColor: AppTheme.darkBorder,
        cardColor: AppTheme.darkCard,
      ),

      themeMode: ThemeMode.system,
      home: const LoginScreen(),
    );
  }
}