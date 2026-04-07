import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/landing_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
