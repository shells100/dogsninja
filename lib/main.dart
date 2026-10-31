import 'package:flutter/material.dart';

import 'dependencies.dart';
import 'network/dogs_api.dart';
import 'screens/dogs_screen.dart';

void main() {
  configureDependencies();
  runApp(DogsApp(api: getIt<DogsApi>()));
}

class DogsApp extends StatelessWidget {
  const DogsApp({super.key, required this.api});

  final DogsApi api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Породы собак',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF245C46)),
        scaffoldBackgroundColor: const Color(0xFFF7F7F0),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(),
        ),
      ),
      home: DogsScreen(api: api),
    );
  }
}
