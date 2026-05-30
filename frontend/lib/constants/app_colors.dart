import 'package:flutter/material.dart';

class AppColors {
  // Dark Background Premium Scheme
  static const Color background = Color(0xFF0F0C1B);
  static const Color surface = Color(0xFF1D1B30);
  static const Color surfaceLight = Color(0xFF2B2844);
  
  static const Color primary = Color(0xFF7F3DFF);
  static const Color secondary = Color(0xFF00F5D4);
  
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9E9DB5);

  // Vibrant Ludo Colors
  static const Color red = Color(0xFFFF3366);
  static const Color green = Color(0xFF2ECC71);
  static const Color yellow = Color(0xFFF1C40F);
  static const Color blue = Color(0xFF3498DB);

  // Gradient helper
  static const Gradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7F3DFF), Color(0xFFB01DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient boardRedGradient = RadialGradient(
    colors: [Color(0xFFFF5252), Color(0xFFC62828)],
  );

  static const Gradient boardGreenGradient = RadialGradient(
    colors: [Color(0xFF69F0AE), Color(0xFF2E7D32)],
  );

  static const Gradient boardYellowGradient = RadialGradient(
    colors: [Color(0xFFFFE082), Color(0xFFF9A825)],
  );

  static const Gradient boardBlueGradient = RadialGradient(
    colors: [Color(0xFF40C4FF), Color(0xFF1565C0)],
  );
}
