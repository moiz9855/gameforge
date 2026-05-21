import 'package:flutter/material.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_logo.dart';

/// Left-aligned GameForge logo + optional trailing widgets.
class GameForgeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? leading;
  final bool centerTitle;
  final Widget? titleOverride;

  const GameForgeAppBar({
    super.key,
    this.actions,
    this.bottom,
    this.leading,
    this.centerTitle = false,
    this.titleOverride,
  });

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading,
      automaticallyImplyLeading: false,
      centerTitle: centerTitle,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      bottom: bottom,
      titleSpacing: 16,
      title: Align(
        alignment: Alignment.centerLeft,
        child: titleOverride ?? const GameForgeLogo(fontSize: 10),
      ),
      actions: actions,
    );
  }
}
