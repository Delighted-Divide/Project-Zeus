import 'package:flutter/material.dart';

class SocialButton extends StatelessWidget {
  final IconData? icon;
  final Color color;
  final Function onTap;
  final double size;
  final String? text;

  const SocialButton({
    super.key,
    this.icon,
    required this.color,
    required this.onTap,
    this.size = 24,
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child:
              text != null
                  ? Text(
                    text!,
                    style: TextStyle(
                      color: color,
                      fontSize: size,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                  : Icon(icon, color: color, size: size),
        ),
      ),
    );
  }
}
