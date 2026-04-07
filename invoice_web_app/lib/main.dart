import 'package:flutter/material.dart';
import 'screens/main_dashboard.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF667eea)),
        useMaterial3: true,
      ),
      home: const MainDashboard(),
    );
  }
}
