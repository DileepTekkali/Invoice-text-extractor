import 'package:flutter/material.dart';
import 'screens/landing_page.dart';

void main() {
  runApp(const InvoiceWebApp());
}

class InvoiceWebApp extends StatelessWidget {
  const InvoiceWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Invoice Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F6FEB)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7FAFD),
      ),
      home: const LandingPage(),
    );
  }
}
