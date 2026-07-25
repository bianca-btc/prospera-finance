import 'package:flutter/material.dart';

/// Logo do Prospera (tigela + plumas) usado no header do app.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_transparent.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(Icons.savings_rounded, size: size),
    );
  }
}
