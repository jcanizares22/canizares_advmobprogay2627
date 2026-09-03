import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/theme_provider.dart';
import 'screen/splash_screen.dart';

/// Entry point of the application.
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(builder: (context, theme, child) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'canizares_advmobprog',
        theme: ThemeData(
          brightness: Brightness.light,
          fontFamily: 'Poppins',
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: 'Poppins',
        ),
        themeMode: theme.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        home: const SplashScreen(),
      );
    });
  }
}