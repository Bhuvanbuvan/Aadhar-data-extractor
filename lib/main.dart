import 'package:flutter/material.dart';
import 'package:textreading/home_page/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aadhaar Text Extractor',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const AadhaarExtractorPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
