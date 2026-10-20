import 'package:flutter/material.dart';

/// Shamba. brand palette: earthy terracotta.
///
/// Terracotta is the action colour, dark soil brown carries hero cards,
/// warm cream is the canvas, amber marks eggs/money and sage marks growth.
/// (Token names are kept from the first palette so every screen follows.)
abstract final class AppColors {
  // Brand
  static const forest = Color(0xFFC8553D); // terracotta: buttons, links, selection
  static const forestDark = Color(0xFFA8432F); // pressed terracotta
  static const forestDeep = Color(0xFF3B2A20); // soil brown: hero cards, toasts
  static const lime = Color(0xFF9CAF88); // sage: growth, "sales", positive accents
  static const limeSoft = Color(0xFFF6E5DE); // terracotta tint: selected chips, soft buttons
  static const terracottaLight = Color(0xFFE48A72); // primary on dark backgrounds
  static const sageDeep = Color(0xFF7E9468); // sales in charts
  static const amber = Color(0xFFE9A23B);
  static const amberSoft = Color(0xFFFBEFD9);
  static const pink = Color(0xFFF2A7A0);
  static const pinkDeep = Color(0xFFD9726A);
  static const pinkSoft = Color(0xFFFCE9E5);

  // Neutrals (light)
  static const cream = Color(0xFFFBF7F2);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF3ECE4);
  static const outline = Color(0xFFEDE3D8);
  static const ink = Color(0xFF2A211B);
  static const inkSoft = Color(0xFF6B5D52);
  static const inkMuted = Color(0xFFA39587);

  // Neutrals (dark)
  static const night = Color(0xFF15100C);
  static const nightSurface = Color(0xFF201812);
  static const nightSurfaceAlt = Color(0xFF2A2019);
  static const nightOutline = Color(0xFF3A2D24);
  static const nightInk = Color(0xFFF6EFE8);
  static const nightInkSoft = Color(0xFFC7B8AA);

  // Semantic
  static const success = Color(0xFF5E8C4A);
  static const warning = Color(0xFFE59A00);
  static const danger = Color(0xFFD64545);
  static const dangerSoft = Color(0xFFFBE5E5);
  static const info = Color(0xFF3A7BD5);
  static const infoSoft = Color(0xFFE3EDFB);

  /// Hero cards: nearly flat soil brown, just enough depth to not look printed.
  static const heroGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF453227), forestDeep]);

  static const buttonGradient = LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0xFFC0503A), Color(0xFFD0654A)]);
}
