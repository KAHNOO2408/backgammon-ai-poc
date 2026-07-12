import 'package:flutter/material.dart';
import 'screens/game_screen.dart';

void main() {
  runApp(const BackgammonApp());
}

class BackgammonApp extends StatelessWidget {
  const BackgammonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Backgammon',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const GameScreen(),
    );
  }
}
