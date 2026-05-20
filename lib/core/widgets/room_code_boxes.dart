import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';

/// Six single-character boxes + hidden controller sync for room codes.
class RoomCodeBoxes extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final bool autofocus;

  const RoomCodeBoxes({
    super.key,
    required this.onChanged,
    this.autofocus = true,
  });

  @override
  State<RoomCodeBoxes> createState() => _RoomCodeBoxesState();
}

class _RoomCodeBoxesState extends State<RoomCodeBoxes> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    for (final c in _controllers) {
      c.addListener(_syncCode);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.autofocus) _focusNodes[0].requestFocus();
    });
  }

  void _syncCode() {
    final code = _controllers.map((c) => c.text.toUpperCase()).join();
    widget.onChanged(code);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    final upper = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (upper.length >= 6) {
      _pasteAcross(upper);
      return;
    }
    if (upper.length > 1) {
      final newChar = upper.substring(upper.length - 1);
      _controllers[index].value = TextEditingValue(
        text: newChar,
        selection: TextSelection.collapsed(offset: newChar.length),
      );
      if (newChar.isNotEmpty && index < 5) {
        _focusNodes[index + 1].requestFocus();
      }
      _syncCode();
      return;
    }
    if (_controllers[index].text != upper) {
      _controllers[index].value = TextEditingValue(
        text: upper,
        selection: TextSelection.collapsed(offset: upper.length),
      );
    }
    if (upper.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    _syncCode();
  }

  void _pasteAcross(String raw) {
    final chars = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '').split('');
    for (var i = 0; i < 6; i++) {
      _controllers[i].text = i < chars.length ? chars[i] : '';
    }
    final nextFocus = chars.length.clamp(0, 6);
    if (nextFocus < 6) {
      _focusNodes[nextFocus].requestFocus();
    } else {
      _focusNodes[5].requestFocus();
    }
    _syncCode();
  }

  KeyEventResult _onKey(KeyEvent event, int index) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _focusNodes[index - 1].requestFocus();
        _controllers[index - 1].clear();
        _syncCode();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
            child: Focus(
              onKeyEvent: (node, event) => _onKey(event, i),
              child: TextField(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                maxLines: 1,
                textAlign: TextAlign.center,
                style: GoogleFonts.pressStart2p(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                ],
                textCapitalization: TextCapitalization.characters,
                onChanged: (v) => _onChanged(i, v),
              ),
            ),
          ),
        );
      }),
    );
  }
}
