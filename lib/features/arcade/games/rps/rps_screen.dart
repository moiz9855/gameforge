import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';
import 'package:game_forge/core/widgets/crt_overlay.dart';
import 'package:game_forge/core/services/sound_service.dart';
import 'package:game_forge/core/services/achievement_service.dart';

class RpsScreen extends StatefulWidget {
  const RpsScreen({super.key});

  @override
  State<RpsScreen> createState() => _RpsScreenState();
}

class _RpsScreenState extends State<RpsScreen> {
  // Game phases: 'select_difficulty', 'playing', 'match_over'
  String _phase = 'select_difficulty';
  String _difficulty = 'medium';

  // Round states: 'idle', 'thinking', 'reveal'
  String _roundState = 'idle';

  int _playerWins = 0;
  int _aiWins = 0;
  int _currentRound = 1;
  final int _maxRounds = 5; // Best of 5

  String? _playerChoice; // 'R', 'P', 'S'
  String? _aiChoice; // 'R', 'P', 'S'
  String _roundResult = ''; // 'win', 'lose', 'draw'
  String _tauntMessage = '';
  
  // Stats
  int _bestStreak = 0;
  int _sessionStreak = 0;

  // History tracking for Hard AI
  final List<String> _playerHistory = [];
  final Map<String, Map<String, int>> _transitions = {
    'R': {'R': 0, 'P': 0, 'S': 0},
    'P': {'R': 0, 'P': 0, 'S': 0},
    'S': {'R': 0, 'P': 0, 'S': 0},
  };
  String? _lastPlayerMove;

  // AI Thinking Animation State
  Timer? _thinkingTimer;
  int _thinkingIndex = 0;
  final List<String> _thinkingEmojis = ['🤜', '🖐️', '✌️'];

  final List<String> _aiTaunts = [
    "Predictable human! 🤖",
    "Is that your best? 😈",
    "I read you like an open book! 🧠",
    "A logical calculation. Easy! 👾",
    "Too slow! Try harder. ⚡",
    "My algorithms are superior! 👑",
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _thinkingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await AchievementService.instance.getRpsStats();
    final streak = await AchievementService.instance.getRpsCurrentStreak();
    setState(() {
      _bestStreak = stats['best_streak'] ?? 0;
      _sessionStreak = streak;
    });
  }

  void _startNewMatch(String diff) {
    setState(() {
      _difficulty = diff;
      _phase = 'playing';
      _roundState = 'idle';
      _playerWins = 0;
      _aiWins = 0;
      _currentRound = 1;
      _playerChoice = null;
      _aiChoice = null;
      _roundResult = '';
      _tauntMessage = '';
      _playerHistory.clear();
      _transitions.forEach((key, map) {
        map.updateAll((k, v) => 0);
      });
      _lastPlayerMove = null;
    });
    SoundService.instance.play(SoundType.gameStart);
  }

  void _onPlayerSelect(String choice) {
    if (_roundState != 'idle') return;

    SoundService.instance.play(SoundType.buttonTap);
    HapticFeedback.lightImpact();

    setState(() {
      _playerChoice = choice;
      _roundState = 'thinking';
    });

    SoundService.instance.play(SoundType.aiReveal);

    // Start AI Thinking cycle
    int count = 0;
    _thinkingTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      setState(() {
        _thinkingIndex = (_thinkingIndex + 1) % _thinkingEmojis.length;
      });
      count++;
      if (count >= 8) {
        // 1.2s thinking complete
        timer.cancel();
        _evaluateRound();
      }
    });
  }

  void _evaluateRound() {
    final aiMove = _getAiMove();
    _recordPlayerMove(_playerChoice!);

    String result;
    if (_playerChoice == aiMove) {
      result = 'draw';
    } else if ((_playerChoice == 'R' && aiMove == 'S') ||
        (_playerChoice == 'P' && aiMove == 'R') ||
        (_playerChoice == 'S' && aiMove == 'P')) {
      result = 'win';
    } else {
      result = 'lose';
    }

    setState(() {
      _aiChoice = aiMove;
      _roundResult = result;
      _roundState = 'reveal';
      
      if (result == 'win') {
        _playerWins++;
        SoundService.instance.play(SoundType.winFanfare);
      } else if (result == 'lose') {
        _aiWins++;
        _tauntMessage = _aiTaunts[math.Random().nextInt(_aiTaunts.length)];
        SoundService.instance.play(SoundType.loseSound);
      } else {
        SoundService.instance.play(SoundType.drawSound);
      }
    });

    // Delay before starting next round or ending match
    Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;

      if (_playerWins >= 3 || _aiWins >= 3 || _currentRound >= _maxRounds) {
        _endMatch();
      } else {
        setState(() {
          _currentRound++;
          _roundState = 'idle';
          _playerChoice = null;
          _aiChoice = null;
          _roundResult = '';
          _tauntMessage = '';
        });
      }
    });
  }

  void _endMatch() {
    final playerWon = _playerWins > _aiWins;
    if (playerWon) {
      _sessionStreak++;
      SoundService.instance.play(SoundType.achievement);
    } else {
      _sessionStreak = 0;
      SoundService.instance.play(SoundType.gameOver);
    }

    AchievementService.instance.setRpsCurrentStreak(_sessionStreak);
    AchievementService.instance.saveRpsMatchResult(
      won: playerWon,
      currentStreak: _sessionStreak,
    );

    setState(() {
      _phase = 'match_over';
    });
    _loadStats();
  }

  void _recordPlayerMove(String move) {
    if (_lastPlayerMove != null) {
      final trans = _transitions[_lastPlayerMove]!;
      trans[move] = (trans[move] ?? 0) + 1;
    }
    _playerHistory.add(move);
    _lastPlayerMove = move;
  }

  String _predictPlayerMove() {
    if (_playerHistory.isEmpty || _lastPlayerMove == null) {
      return _randomMove();
    }
    final nextMoves = _transitions[_lastPlayerMove]!;
    int rCount = nextMoves['R'] ?? 0;
    int pCount = nextMoves['P'] ?? 0;
    int sCount = nextMoves['S'] ?? 0;

    if (rCount == 0 && pCount == 0 && sCount == 0) {
      return _randomMove();
    }

    if (rCount >= pCount && rCount >= sCount) {
      return 'R';
    } else if (pCount >= rCount && pCount >= sCount) {
      return 'P';
    } else {
      return 'S';
    }
  }

  String _randomMove() {
    final moves = ['R', 'P', 'S'];
    return moves[math.Random().nextInt(3)];
  }

  String _getAiMove() {
    if (_difficulty == 'easy') {
      return _randomMove();
    } else if (_difficulty == 'medium') {
      // 50% random, 50% guess counter to last move
      if (math.Random().nextDouble() < 0.5) {
        return _randomMove();
      } else {
        if (_playerHistory.isEmpty) return _randomMove();
        final lastMove = _playerHistory.last;
        return _getWinningMove(lastMove);
      }
    } else {
      // Hard AI prediction
      final predictedMove = _predictPlayerMove();
      return _getWinningMove(predictedMove);
    }
  }

  String _getWinningMove(String playerMove) {
    if (playerMove == 'R') return 'P';
    if (playerMove == 'P') return 'S';
    return 'R';
  }

  String _getEmoji(String? choice) {
    if (choice == 'R') return '🤜';
    if (choice == 'P') return '🖐️';
    if (choice == 'S') return '✌️';
    return '❓';
  }

  String _getName(String? choice) {
    if (choice == 'R') return 'ROCK';
    if (choice == 'P') return 'PAPER';
    if (choice == 'S') return 'SCISSORS';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GameForgeAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textSecondary,
          onPressed: () {
            SoundService.instance.play(SoundType.buttonBack);
            Navigator.pop(context);
          },
        ),
        titleOverride: Text(
          'ROCK PAPER SCISSORS',
          style: GoogleFonts.pressStart2p(
            fontSize: 10,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: CrtOverlay(
        child: Column(
          children: [
            Expanded(
              child: _buildPhaseContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseContent() {
    if (_phase == 'select_difficulty') {
      return _buildDifficultySelector();
    } else if (_phase == 'playing') {
      return _buildGameArea();
    } else {
      return _buildMatchOver();
    }
  }

  Widget _buildDifficultySelector() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '🤜 VS 🤖',
              style: TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'CHOOSE DIFFICULTY',
              style: GoogleFonts.pressStart2p(
                fontSize: 14,
                color: const Color(0xFFF05A28),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ...['easy', 'medium', 'hard'].map((diff) {
              final isSelected = _difficulty == diff;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: SizedBox(
                  width: 220,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _difficulty = diff);
                      SoundService.instance.play(SoundType.difficultySelect);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isSelected ? const Color(0xFFF05A28) : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                      backgroundColor: isSelected
                          ? const Color(0xFFF05A28).withValues(alpha: 0.1)
                          : const Color(0xFF0D1117),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      diff.toUpperCase(),
                      style: GoogleFonts.pressStart2p(
                        fontSize: 10,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            SizedBox(
              width: 220,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _startNewMatch(_difficulty),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF05A28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'START MATCH',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'BEST STREAK: $_bestStreak  |  CURRENT: $_sessionStreak',
              style: GoogleFonts.shareTechMono(
                fontSize: 14,
                color: AppColors.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameArea() {
    return Column(
      children: [
        // Top Panel: Round indicators & Score
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                'ROUND $_currentRound / $_maxRounds',
                style: GoogleFonts.pressStart2p(fontSize: 10, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              // Round Dots (Best of 5 rounds)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_maxRounds, (index) {
                  // Figure out who won this round in history
                  // For simplicity we show active dots
                  final isCurrent = index == _currentRound - 1;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCurrent ? const Color(0xFFF05A28) : AppColors.border,
                        width: 2,
                      ),
                      color: index < _playerWins
                          ? Colors.green
                          : (index < _playerWins + _aiWins ? AppColors.error : Colors.transparent),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('PLAYER: $_playerWins', style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white)),
                  Text('AI: $_aiWins', style: GoogleFonts.pressStart2p(fontSize: 10, color: AppColors.error)),
                ],
              ),
            ],
          ),
        ),
        
        // Center Area: AI vs Player Choice Reveal
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // AI Choice Slot
                  Column(
                    children: [
                      Text(
                        'AI (DIFFICULTY: ${_difficulty.toUpperCase()})',
                        style: GoogleFonts.shareTechMono(fontSize: 12, color: AppColors.textSecondary, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1117),
                          border: Border.all(color: AppColors.border, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: _roundState == 'thinking'
                              ? Text(_thinkingEmojis[_thinkingIndex], style: const TextStyle(fontSize: 48))
                              : _roundState == 'reveal'
                                  ? Text(_getEmoji(_aiChoice), style: const TextStyle(fontSize: 48))
                                  : const Text('🤖', style: TextStyle(fontSize: 44)),
                        ),
                      ),
                      if (_roundState == 'reveal') ...[
                        const SizedBox(height: 6),
                        Text(
                          _getName(_aiChoice),
                          style: GoogleFonts.pressStart2p(fontSize: 8, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                  
                  // Interactive Speech Bubble / Status text
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 32.0),
                    child: Container(
                      height: 70,
                      alignment: Alignment.center,
                      child: _roundState == 'thinking'
                          ? Text(
                              'AI IS DECIDING...',
                              style: GoogleFonts.pressStart2p(fontSize: 8, color: const Color(0xFFF05A28)),
                            )
                          : _roundState == 'reveal'
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _roundResult == 'win'
                                          ? 'YOU WON THE ROUND!'
                                          : _roundResult == 'lose'
                                              ? 'AI WON THE ROUND!'
                                              : 'ROUND DRAW!',
                                      style: GoogleFonts.pressStart2p(
                                        fontSize: 10,
                                        color: _roundResult == 'win'
                                            ? Colors.green
                                            : _roundResult == 'lose'
                                                ? AppColors.error
                                                : Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_roundResult == 'lose' && _tauntMessage.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        _tauntMessage,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.rajdhani(
                                          color: Colors.white70,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ]
                                )
                              : Text(
                                  'MAKE YOUR CHOICE!',
                                  style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white70),
                                ),
                    ),
                  ),

                  // Player Choice Slot
                  Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1117),
                          border: Border.all(
                            color: _playerChoice != null ? const Color(0xFFF05A28) : AppColors.border,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: _playerChoice != null
                              ? Text(_getEmoji(_playerChoice), style: const TextStyle(fontSize: 48))
                              : const Text('⚡', style: TextStyle(fontSize: 40, color: Color(0xFFF05A28))),
                        ),
                      ),
                      if (_playerChoice != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _getName(_playerChoice),
                          style: GoogleFonts.pressStart2p(fontSize: 8, color: const Color(0xFFF05A28)),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'PLAYER CHOICE',
                        style: GoogleFonts.shareTechMono(fontSize: 12, color: AppColors.textSecondary, letterSpacing: 1.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom Controls: Action Buttons
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton('R', '🤜', 'ROCK'),
                _buildActionButton('P', '🖐️', 'PAPER'),
                _buildActionButton('S', '✌️', 'SCISSORS'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String val, String emoji, String label) {
    final disabled = _roundState != 'idle';
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Column(
        children: [
          ElevatedButton(
            onPressed: disabled ? null : () => _onPlayerSelect(val),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D1117),
              foregroundColor: const Color(0xFFF05A28),
              side: const BorderSide(color: Color(0xFFF05A28), width: 1.5),
              fixedSize: const Size(64, 64),
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchOver() {
    final playerWon = _playerWins > _aiWins;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              playerWon ? 'VICTORY 🏆' : 'DEFEAT 💀',
              style: GoogleFonts.pressStart2p(
                fontSize: 20,
                color: playerWon ? Colors.green : AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'FINAL SCORE',
              style: GoogleFonts.shareTechMono(
                fontSize: 16,
                color: AppColors.textSecondary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'YOU $_playerWins  -  $_aiWins AI',
              style: GoogleFonts.pressStart2p(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            if (playerWon) ...[
              Text(
                'CURRENT WIN STREAK: $_sessionStreak',
                style: GoogleFonts.pressStart2p(fontSize: 8, color: const Color(0xFFF05A28)),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'BEST WIN STREAK: $_bestStreak',
              style: GoogleFonts.pressStart2p(fontSize: 8, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 220,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _startNewMatch(_difficulty),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF05A28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'PLAY AGAIN',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 220,
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  SoundService.instance.play(SoundType.buttonBack);
                  setState(() => _phase = 'select_difficulty');
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'BACK TO MENU',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
