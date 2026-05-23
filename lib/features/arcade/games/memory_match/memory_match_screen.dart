import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/crt_overlay.dart';
import 'package:game_forge/core/services/sound_service.dart';
import 'package:game_forge/core/services/achievement_service.dart';

enum MemoryTheme { animals, food, sports, gaming }

class MemoryMatchScreen extends StatefulWidget {
  const MemoryMatchScreen({super.key});

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  int _cols = 4;
  int _rows = 4;
  MemoryTheme _theme = MemoryTheme.gaming;

  List<String> _cards = [];
  List<bool> _flipped = [];
  List<bool> _matched = [];

  int _moves = 0;
  int _matches = 0;
  int _bestMoves = 0;

  int? _firstFlippedIndex;
  bool _canFlip = false;
  bool _previewing = false;
  int _previewTimer = 3;
  Timer? _countdownTimer;

  bool _gameOver = false;

  final Map<MemoryTheme, List<String>> _emojis = {
    MemoryTheme.animals: ['🐶','🐱','🐭','🐹','🐰','🦊','🐻','🐼','🐨','🐯','🦁','🐮','🐷','🐸','🐵','🐔'],
    MemoryTheme.food: ['🍎','🍐','🍊','🍋','🍌','🍉','🍇','🍓','🍈','🍒','🍑','🥭','🍍','🥥','🥝','🍅'],
    MemoryTheme.sports: ['⚽','🏀','🏈','⚾','🥎','🎾','🏐','🏉','🎱','🪀','🏓','🏸','🏒','🏑','🥍','🏏'],
    MemoryTheme.gaming: ['👾','🎮','🕹️','🎲','🎰','🧩','🎳','🎯','🏆','🥇','🃏','🎴','🎭','🎨','🎸','🎺'],
  };

  @override
  void initState() {
    super.initState();
    _loadBest();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBest() async {
    final hs = await AchievementService.instance.getHighScore('memory_match');
    if (mounted) setState(() => _bestMoves = hs);
  }

  void _startGame() {
    final pairCount = (_cols * _rows) ~/ 2;
    final available = List<String>.from(_emojis[_theme]!);
    available.shuffle();
    
    final selected = available.take(pairCount).toList();
    _cards = [...selected, ...selected];
    _cards.shuffle();

    _flipped = List.filled(_cards.length, false);
    _matched = List.filled(_cards.length, false);
    _moves = 0;
    _matches = 0;
    _gameOver = false;
    _firstFlippedIndex = null;
    
    _startPreview();
  }

  void _startPreview() {
    setState(() {
      _previewing = true;
      _canFlip = false;
      _previewTimer = 2;
      for (int i = 0; i < _flipped.length; i++) {
        _flipped[i] = true;
      }
    });
    
    SoundService.instance.play(SoundType.gameStart);

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_previewTimer > 0) {
          _previewTimer--;
          SoundService.instance.play(SoundType.snakeMove);
        } else {
          timer.cancel();
          _previewing = false;
          _canFlip = true;
          for (int i = 0; i < _flipped.length; i++) {
            _flipped[i] = false;
          }
        }
      });
    });
  }

  void _flipCard(int index) {
    if (!_canFlip || _flipped[index] || _matched[index]) return;

    SoundService.instance.play(SoundType.snakeMove);
    setState(() {
      _flipped[index] = true;
      
      if (_firstFlippedIndex == null) {
        _firstFlippedIndex = index;
      } else {
        _moves++;
        _canFlip = false;
        
        final first = _firstFlippedIndex!;
        if (_cards[first] == _cards[index]) {
          // Match
          SoundService.instance.play(SoundType.coin);
          _matched[first] = true;
          _matched[index] = true;
          _matches++;
          _firstFlippedIndex = null;
          _canFlip = true;
          _checkWin();
        } else {
          // No match
          SoundService.instance.play(SoundType.wallHit);
          Future.delayed(const Duration(milliseconds: 800), () {
            if (!mounted) return;
            setState(() {
              _flipped[first] = false;
              _flipped[index] = false;
              _firstFlippedIndex = null;
              _canFlip = true;
            });
          });
        }
      }
    });
  }

  void _checkWin() {
    if (_matches == (_cols * _rows) ~/ 2) {
      _gameOver = true;
      SoundService.instance.play(SoundType.winFanfare);
      if (_bestMoves == 0 || _moves < _bestMoves) {
        _bestMoves = _moves;
        AchievementService.instance.saveHighScore('memory_match', _moves);
      }
    }
  }

  Widget _buildSetup() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        color: Colors.black.withValues(alpha: 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🃏', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('MEMORY MATCH', style: GoogleFonts.pressStart2p(fontSize: 16, color: const Color(0xFFF05A28))),
            const SizedBox(height: 32),
            
            Text('GRID SIZE', style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white70)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _optionBtn('4x3', () => setState((){_cols=4; _rows=3;}), _cols==4 && _rows==3),
                const SizedBox(width: 8),
                _optionBtn('4x4', () => setState((){_cols=4; _rows=4;}), _cols==4 && _rows==4),
                const SizedBox(width: 8),
                _optionBtn('5x4', () => setState((){_cols=4; _rows=5;}), _cols==4 && _rows==5),
              ],
            ),
            
            const SizedBox(height: 24),
            Text('THEME', style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white70)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: MemoryTheme.values.map((t) {
                return _optionBtn(t.name.toUpperCase(), () => setState(()=>_theme=t), _theme==t);
              }).toList(),
            ),

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF05A28),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: Text('START GAME', style: GoogleFonts.pressStart2p(fontSize: 12, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionBtn(String label, VoidCallback onTap, bool isSelected) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF05A28) : const Color(0xFF1A1A24),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? const Color(0xFFF05A28) : Colors.white24),
        ),
        child: Text(label, style: GoogleFonts.pressStart2p(fontSize: 8, color: isSelected ? Colors.white : Colors.white70)),
      ),
    );
  }

  Widget _buildCard(int index) {
    final isFlipped = _flipped[index];
    final isMatched = _matched[index];

    return GestureDetector(
      onTap: () => _flipCard(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isMatched 
              ? Colors.green.withValues(alpha: 0.2) 
              : isFlipped ? const Color(0xFF2A2A3A) : const Color(0xFFF05A28).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isMatched ? Colors.green : isFlipped ? Colors.white54 : const Color(0xFFF05A28),
            width: 2,
          ),
        ),
        child: Center(
          child: isFlipped || isMatched 
              ? Text(_cards[index], style: const TextStyle(fontSize: 32)) 
              : const Icon(Icons.help_outline, color: Color(0xFFF05A28), size: 24),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CrtOverlay(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('MOVES: $_moves', style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('BEST: ${_bestMoves > 0 ? _bestMoves : '-'}', style: GoogleFonts.pressStart2p(fontSize: 8, color: AppColors.gold)),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _cards.isEmpty
                    ? _buildSetup()
                    : Stack(
                        children: [
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: AspectRatio(
                                aspectRatio: _cols / _rows,
                                child: GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: _cols,
                                    childAspectRatio: 1.0,
                                  ),
                                  itemCount: _cards.length,
                                  itemBuilder: (context, index) => _buildCard(index),
                                ),
                              ),
                            ),
                          ),
                          if (_previewing)
                            Center(
                              child: Text('$_previewTimer', 
                                style: GoogleFonts.pressStart2p(fontSize: 80, color: const Color(0xFFF05A28).withValues(alpha: 0.8))),
                            ),
                          if (_gameOver)
                            Container(
                              color: Colors.black.withValues(alpha: 0.8),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('CLEARED IN $_moves MOVES!', style: GoogleFonts.pressStart2p(fontSize: 12, color: Colors.green)),
                                    const SizedBox(height: 24),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() => _cards = []);
                                      },
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF05A28)),
                                      child: Text('PLAY AGAIN', style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
