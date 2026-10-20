import 'package:flutter/material.dart';

/// Shamba. brand palette.
///
/// Deep farm greens carry the brand, egg-yolk amber marks money and alerts,
/// and soft pig pink tags everything pig-related.
abstract final class AppColors {
  // Brand
  static const forest = Color(0xFF2F5D1E);
  static const forestDark = Color(0xFF1F4213);
  static const forestDeep = Color(0xFF14290D);
  static const lime = Color(0xFF8BC34A);
  static const limeSoft = Color(0xFFE6F2D6);
  static const amber = Color(0xFFF5B700);
  static const amberSoft = Color(0xFFFFF3CC);
  static const pink = Color(0xFFF2A7A0);
  static const pinkDeep = Color(0xFFD9726A);
  static const pinkSoft = Color(0xFFFCE7E4);

  // Neutrals (light)
  static const cream = Color(0xFFFAF8F2);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF2EFE6);
  static const outline = Color(0xFFE6E2D6);
  static const ink = Color(0xFF1E1E1E);
  static const inkSoft = Color(0xFF5C6157);
  static const inkMuted = Color(0xFF9A9E93);

  // Neutrals (dark)
  static const night = Color(0xFF0F1A0B);
  static const nightSurface = Color(0xFF172413);
  static const nightSurfaceAlt = Color(0xFF203019);
  static const nightOutline = Color(0xFF2D3F25);
  static const nightInk = Color(0xFFF1F4EC);
  static const nightInkSoft = Color(0xFFB8C2AE);

  // Semantic
  static const success = Color(0xFF3E9B4F);
  static const warning = Color(0xFFE59A00);
  static const danger = Color(0xFFD64545);
  static const dangerSoft = Color(0xFFFBE5E5);
  static const info = Color(0xFF3A7BD5);
  static const infoSoft = Color(0xFFE3EDFB);

  static const heroGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [forestDark, forest, Color(0xFF5E9A2F)]);

  static const buttonGradient = LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [forestDark, Color(0xFF4C8A28)]);
}
