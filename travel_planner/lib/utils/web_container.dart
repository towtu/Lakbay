import 'package:flutter/material.dart';

class WebContainer extends StatelessWidget {
  final Widget child;
  const WebContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600), // Keeps it phone-sized on web
        child: child,
      ),
    );
  }
}