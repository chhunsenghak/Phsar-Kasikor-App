import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/app_state.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phsar Kasikor - AgriMarket',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F5238),
          primary: const Color(0xFF0F5238),
          secondary: const Color(0xFF2B694D),
          background: const Color(0xFFF8F9FA),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
