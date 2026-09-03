import 'package:flutter/material.dart';

class CustomText extends StatelessWidget {
  final String text;
  final double size;
  final FontWeight weight;

  const CustomText(
    this.text, {
    super.key,
    this.size = 14,
    this.weight = FontWeight.normal,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: size, fontWeight: weight),
    );
  }
}
