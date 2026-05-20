import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';

/// Compact Press Start 2P logo — white fill + orange offset shadow.
class GameForgeLogo extends StatelessWidget {
  final double fontSize;

  const GameForgeLogo({super.key, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    return Text(
      'GAMEFORGE',
      style: GoogleFonts.pressStart2p(
        fontSize: fontSize,
        color: Colors.white,
        height: 1.2,
        shadows: const [
          Shadow(
            offset: Offset(2, 2),
            blurRadius: 0,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
