import 'package:flutter/material.dart';

class SocialButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap; // Change to nullable
  final double size;

  const SocialButton({
    super.key,
    required this.icon,
    required this.color,
    this.onTap, // Now accepts null
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap, // InkWell already accepts nullable callbacks
      // ... rest of your widget implementation
    );
  }
}
