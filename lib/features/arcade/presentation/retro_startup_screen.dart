import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/services/sound_service.dart';
import 'package:game_forge/core/services/achievement_service.dart';
import 'package:game_forge/core/widgets/crt_overlay.dart';

class RetroStartupScreen extends StatefulWidget {
  const RetroStartupScreen({super.key});

  @override
  State<RetroStartupScreen> createState() => _RetroStartupScreenState();
}

class _RetroStartupScreenState extends State<RetroStartupScreen> {
  final List<String> _biosLines = [
    'GAMEFORGE ARCADE SYSTEM v1.2.0',
    'COPYRIGHT (C) 1983-2026 GAMEFORGE INC.',
    '--------------------------------------',
    'CPU: DART-VM 64-BIT @ 2.4GHZ... OK',
    'RAM: 4096MB SYSTEM MEMORY... OK',
    'VRAM: CUSTOM 60FPS CUSTOM-PAINTER... OK',
    'SOUND SYNTHESIZER: SYNTH-8 8-BIT... OK',
    'STORAGE: DEVICE LOCAL PREFS... OK',
    'SOUND CACHE GENERATION... OK',
    'LOAD COMPLETED. SYSTEM READY.',
    '--------------------------------------',
  ];

  final List<String> _visibleLines = [];
  int _lineIndex = 0;
  bool _bootComplete = false;
  bool _coinInserted = false;
  bool _cursorVisible = true;
  Timer? _cursorTimer;
  Timer? _bootTimer;

  @override
  void initState() {
    super.initState();
    // Initialize sound engine
    SoundService.instance.init();
    
    // Start cursor blinking
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (mounted) {
        setState(() => _cursorVisible = !_cursorVisible);
      }
    });

    // Start printing BIOS lines
    _printNextLine();
  }

  @override
  void dispose() {
    _cursorTimer?.cancel();
    _bootTimer?.cancel();
    super.dispose();
  }

  void _printNextLine() {
    if (_lineIndex < _biosLines.length) {
      _bootTimer = Timer(const Duration(milliseconds: 250), () {
        if (mounted) {
          setState(() {
            _visibleLines.add(_biosLines[_lineIndex]);
            _lineIndex++;
          });
          // Play a retro computer blip sound for each printed line
          SoundService.instance.play(SoundType.snakeMove);
          _printNextLine();
        }
      });
    } else {
      if (mounted) {
        setState(() => _bootComplete = true);
      }
    }
  }

  Future<void> _insertCoinAndBoot() async {
    if (_coinInserted) return;
    setState(() => _coinInserted = true);

    // Play retro double beep coin sound
    await SoundService.instance.play(SoundType.coin);
    
    // Unlock first_coin achievement & save state
    await AchievementService.instance.insertCoin();

    // Small delay to let sound play, then route to Solo Arcade
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        context.go('/arcade'); // router redirect will handle this
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080809), // Sleek dark retro background
      body: CrtOverlay(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ..._visibleLines.map((line) => Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Text(
                                line,
                                style: GoogleFonts.pressStart2p(
                                  color: const Color(0xFFF05A28), // GameForge Orange accent
                                  fontSize: 10.0,
                                  height: 1.6,
                                ),
                              ),
                            )),
                        if (!_bootComplete)
                          Row(
                            children: [
                              Text(
                                'SYSTEM BOOTING',
                                style: GoogleFonts.pressStart2p(
                                  color: const Color(0xFFF05A28).withValues(alpha: 0.7),
                                  fontSize: 10.0,
                                ),
                              ),
                              if (_cursorVisible)
                                Text(
                                  ' █',
                                  style: GoogleFonts.pressStart2p(
                                    color: const Color(0xFFF05A28),
                                    fontSize: 10.0,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                if (_bootComplete) ...[
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BlinkingInsertCoinText(coinInserted: _coinInserted),
                        const SizedBox(height: 30),
                        GestureDetector(
                          onTap: _insertCoinAndBoot,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFF05A28),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF05A28).withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.monetization_on_outlined,
                                  color: Color(0xFFF05A28),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _coinInserted ? 'BOOTING...' : 'INSERT COIN',
                                  style: GoogleFonts.pressStart2p(
                                    color: const Color(0xFFF05A28),
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlinkingInsertCoinText extends StatefulWidget {
  final bool coinInserted;
  const _BlinkingInsertCoinText({required this.coinInserted});

  @override
  State<_BlinkingInsertCoinText> createState() => _BlinkingInsertCoinTextState();
}

class _BlinkingInsertCoinTextState extends State<_BlinkingInsertCoinText> {
  bool _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 550), (timer) {
      if (mounted) {
        setState(() => _visible = !_visible);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.coinInserted) {
      return Text(
        'COIN ACCEPTED',
        style: GoogleFonts.pressStart2p(
          color: Colors.green,
          fontSize: 14.0,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      );
    }

    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 150),
      child: Text(
        'INSERT 1 COIN TO PLAY',
        style: GoogleFonts.pressStart2p(
          color: const Color(0xFFF05A28),
          fontSize: 11.0,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
