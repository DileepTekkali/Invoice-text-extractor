import 'package:flutter/material.dart';

class ResultView extends StatelessWidget {
  final String text;

  ResultView({required this.text});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Text(
        text.isEmpty ? "No data yet" : text,
        style: TextStyle(fontSize: 16),
      ),
    );
  }
}