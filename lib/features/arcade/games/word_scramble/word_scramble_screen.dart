import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/crt_overlay.dart';
import 'package:game_forge/core/services/sound_service.dart';
import 'package:game_forge/core/services/achievement_service.dart';

class WordData {
  final String word;
  final String definition;
  final String category;
  WordData(this.word, this.definition, this.category);
}

class WordScrambleScreen extends StatefulWidget {
  const WordScrambleScreen({super.key});

  @override
  State<WordScrambleScreen> createState() => _WordScrambleScreenState();
}

class _WordScrambleScreenState extends State<WordScrambleScreen> {
  final List<WordData> _dictionary = [
    WordData('FLUTTER', 'An open-source UI software development kit created by Google.', 'TECH'),
    WordData('WIDGET', 'The basic building block of a Flutter app\'s user interface.', 'TECH'),
    WordData('DART', 'The programming language used to code Flutter apps.', 'TECH'),
    WordData('ARCADE', 'A venue where people play arcade games.', 'GAMING'),
    WordData('GALAXY', 'A gravitationally bound system of stars, stellar remnants, interstellar gas, dust, and dark matter.', 'SPACE'),
    WordData('CYBERPUNK', 'A subgenre of science fiction in a dystopian futuristic setting.', 'SCI-FI'),
    WordData('NEON', 'A chemical element with the symbol Ne and atomic number 10, often used in signs.', 'SCIENCE'),
    WordData('SYNTHWAVE', 'An electronic music microgenre that is based predominantly on the music associated with action, science-fiction, and horror film soundtracks of the 1980s.', 'MUSIC'),
  ];

  late WordData _currentWord;
  List<String> _scrambled = [];
  List<String?> _slots = [];
  
  int _score = 0;
  int _bestScore = 0;
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    _loadBest();
    _nextWord();
  }

  Future<void> _loadBest() async {
    final hs = await AchievementService.instance.getHighScore('word_scramble');
    if (mounted) setState(() => _bestScore = hs);
  }

  void _nextWord() {
    final random = Random();
    _currentWord = _dictionary[random.nextInt(_dictionary.length)];
    
    final chars = _currentWord.word.split('');
    chars.shuffle(random);
    
    _scrambled = chars;
    _slots = List.filled(_currentWord.word.length, null);
    _gameOver = false;
  }

  void _placeLetter(int scrIndex, int slotIndex) {
    if (_slots[slotIndex] != null) return;
    
    setState(() {
      _slots[slotIndex] = _scrambled[scrIndex];
      _scrambled[scrIndex] = '';
      SoundService.instance.play(SoundType.snakeMove);
    });
    
    _checkWin();
  }

  void _returnLetter(int slotIndex) {
    if (_slots[slotIndex] == null) return;
    
    setState(() {
      final letter = _slots[slotIndex]!;
      _slots[slotIndex] = null;
      
      // Find first empty spot in scrambled
      for (int i = 0; i < _scrambled.length; i++) {
        if (_scrambled[i] == '') {
          _scrambled[i] = letter;
          break;
        }
      }
      SoundService.instance.play(SoundType.snakeMove);
    });
  }

  void _checkWin() {
    if (_slots.contains(null)) return;
    
    final attempt = _slots.join('');
    if (attempt == _currentWord.word) {
      setState(() {
        _score += 100;
        _gameOver = true;
      });
      SoundService.instance.play(SoundType.winFanfare);
      
      if (_score > _bestScore) {
        _bestScore = _score;
        AchievementService.instance.saveHighScore('word_scramble', _score);
      }
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _nextWord());
      });
    } else {
      SoundService.instance.play(SoundType.error);
      HapticFeedback.heavyImpact();
      // Auto return all
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          for (int i = 0; i < _slots.length; i++) {
            _returnLetter(i);
          }
        });
      });
    }
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
                        Text('SCORE: $_score', style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('BEST: $_bestScore', style: GoogleFonts.pressStart2p(fontSize: 8, color: AppColors.gold)),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Category
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF05A28).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF05A28)),
                        ),
                        child: Text(_currentWord.category, style: GoogleFonts.pressStart2p(fontSize: 8, color: const Color(0xFFF05A28))),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Definition
                      Text(
                        _currentWord.definition,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.shareTechMono(fontSize: 16, color: Colors.white70, height: 1.5),
                      ),
                      
                      const SizedBox(height: 60),
                      
                      // Slots
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: List.generate(_slots.length, (index) {
                          final letter = _slots[index];
                          return GestureDetector(
                            onTap: () => _returnLetter(index),
                            child: Container(
                              width: 40,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A24),
                                border: Border.all(color: letter != null ? const Color(0xFF4FC3F7) : Colors.white24, width: 2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  letter ?? '',
                                  style: GoogleFonts.pressStart2p(fontSize: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Scrambled letters
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: List.generate(_scrambled.length, (index) {
                          final letter = _scrambled[index];
                          if (letter == '') {
                            return const SizedBox(width: 40, height: 50);
                          }
                          return GestureDetector(
                            onTap: () {
                              for (int i = 0; i < _slots.length; i++) {
                                if (_slots[i] == null) {
                                  _placeLetter(index, i);
                                  break;
                                }
                              }
                            },
                            child: Container(
                              width: 40,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A3A),
                                border: Border.all(color: const Color(0xFFF05A28), width: 2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  letter,
                                  style: GoogleFonts.pressStart2p(fontSize: 16, color: const Color(0xFFF05A28)),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      
                      if (_gameOver) ...[
                        const SizedBox(height: 40),
                        Text('CORRECT!', style: GoogleFonts.pressStart2p(fontSize: 16, color: Colors.green)),
                      ]
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
