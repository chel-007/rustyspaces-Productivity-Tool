import 'package:flutter/material.dart';
import 'home_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RustySpaces',
      theme: ThemeData(
        primaryColor: Colors.grey[300],
        scaffoldBackgroundColor: Colors.grey[400],   // Lighter grey for accent
      ),
      home: HomePage(),
    );
  }
}
