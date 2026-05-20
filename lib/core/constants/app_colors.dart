import 'package:flutter/material.dart';

/// Premium dark / fire accent palette — GameForge design system.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF080809);
  static const Color surface = Color(0xFF0F0F12);
  static const Color card = Color(0xFF141418);
  static const Color card2 = Color(0xFF1C1C22);
  static const Color border = Color(0xFF26262E);

  static const Color primary = Color(0xFFF05A28);
  static const Color fire2 = Color(0xFFFF7A45);
  static const Color gold = Color(0xFFF5A623);

  static const Color textPrimary = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFFA0A0B0);
  static const Color muted = Color(0xFF505060);

  static const Color success = Color(0xFF27C96A);
  static const Color danger = Color(0xFFE84040);

  /// Semantic aliases used across legacy imports.
  static const Color error = danger;
  static const Color warning = gold;

  /// Chess / multiplayer accents (card icon wells).
  static const Color chessTint = Color(0xFF2563EB);
  static const Color ludoTint = Color(0xFF7C3AED);

  /// Retro-compat: maps old `surfaceLight` callers to elevated cards.
  static const Color surfaceLight = card2;

  /// Deprecated alias — prefer `fire2`.
  static const Color secondary = fire2;

  static const LinearGradient fireGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, fire2],
  );

  static const LinearGradient featuredCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2A1510),
      Color(0xFF141418),
      Color(0xFF1C120E),
    ],
  );

  static const Color chessSquareLight = Color(0xFF1D1D2A);
  static const Color chessSquareDark = Color(0xFF13131E);
}
