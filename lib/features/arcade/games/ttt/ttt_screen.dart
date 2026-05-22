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

class TttScreen extends StatefulWidget {
  const TttScreen({super.key});

  @override
  State<TttScreen> createState() => _TttScreenState();
}

class _TttScreenState extends State<TttScreen> with SingleTickerProviderStateMixin {
  // Game phases: 'select_difficulty', 'playing'
  String _phase = 'select_difficulty';
  String _difficulty = 'medium';

  // Game state
  List<String> _board = List.filled(9, ''); // '', 'X', 'O'
  bool _playerTurn = true;
  bool _gameOver = false;
  String _gameResult = ''; // 'win', 'loss', 'draw'
  List<int> _winningLine = [];

  // Stats
  int _wins = 0;
  int _losses = 0;
  int _draws = 0;

  // Warning animation controller for Hard mode
  late AnimationController _warningController;
  late Animation<double> _warningAnimation;

  final List<List<int>> _winPatterns = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8], // Rows
    [0, 3, 6], [1, 4, 7], [2, 5, 8], // Columns
    [0, 4, 8], [2, 4, 6]             // Diagonals
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();

    _warningController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _warningAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(_warningController);
  }

  @override
  void dispose() {
    _warningController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await AchievementService.instance.getTttStats();
    setState(() {
      _wins = stats['wins'] ?? 0;
      _losses = stats['losses'] ?? 0;
      _draws = stats['draws'] ?? 0;
    });
  }

  void _startNewGame(String diff) {
    setState(() {
      _difficulty = diff;
      _phase = 'playing';
      _board = List.filled(9, '');
      _playerTurn = true;
      _gameOver = false;
      _gameResult = '';
      _winningLine.clear();
    });
    SoundService.instance.play(SoundType.gameStart);
  }

  void _onCellTap(int index) {
    if (!_playerTurn || _gameOver || _board[index].isNotEmpty) return;

    SoundService.instance.play(SoundType.buttonTap);
    HapticFeedback.lightImpact();

    setState(() {
      _board[index] = 'X';
      _playerTurn = false;
    });

    if (_checkWinState('X')) {
      _endGame('win');
      return;
    }

    if (_board.every((cell) => cell.isNotEmpty)) {
      _endGame('draw');
      return;
    }

    // Trigger AI move with a small delay for natural pacing
    Timer(const Duration(milliseconds: 500), _makeAiMove);
  }

  void _makeAiMove() {
    if (_gameOver || _playerTurn) return;

    final bestIdx = _calculateAiMove();
    if (bestIdx != -1) {
      setState(() {
        _board[bestIdx] = 'O';
      });

      SoundService.instance.play(SoundType.placeO);

      if (_checkWinState('O')) {
        _endGame('loss');
        return;
      }

      if (_board.every((cell) => cell.isNotEmpty)) {
        _endGame('draw');
        return;
      }

      setState(() {
        _playerTurn = true;
      });
    }
  }

  int _calculateAiMove() {
    if (_difficulty == 'easy') {
      return _getRandomMove();
    } else if (_difficulty == 'medium') {
      return _getMediumMove();
    } else {
      return _getHardMove();
    }
  }

  int _getRandomMove() {
    final emptyIndices = <int>[];
    for (int i = 0; i < 9; i++) {
      if (_board[i].isEmpty) emptyIndices.add(i);
    }
    if (emptyIndices.isEmpty) return -1;
    return emptyIndices[math.Random().nextInt(emptyIndices.length)];
  }

  int _getMediumMove() {
    // 1. Check if AI can win in the next move
    for (int i = 0; i < 9; i++) {
      if (_board[i].isEmpty) {
        _board[i] = 'O';
        final isWin = _checkWinWithoutState('O');
        _board[i] = '';
        if (isWin) return i;
      }
    }

    // 2. Check if player can win in the next move, and block
    for (int i = 0; i < 9; i++) {
      if (_board[i].isEmpty) {
        _board[i] = 'X';
        final isWin = _checkWinWithoutState('X');
        _board[i] = '';
        if (isWin) return i;
      }
    }

    // 3. Play random
    return _getRandomMove();
  }

  int _getHardMove() {
    int bestVal = -1000;
    int bestMove = -1;

    for (int i = 0; i < 9; i++) {
      if (_board[i].isEmpty) {
        _board[i] = 'O';
        int moveVal = _minimax(0, false);
        _board[i] = '';
        if (moveVal > bestVal) {
          bestMove = i;
          bestVal = moveVal;
        }
      }
    }
    return bestMove;
  }

  int _minimax(int depth, bool isMax) {
    if (_checkWinWithoutState('O')) return 10 - depth;
    if (_checkWinWithoutState('X')) return depth - 10;
    if (_board.every((cell) => cell.isNotEmpty)) return 0;

    if (isMax) {
      int best = -1000;
      for (int i = 0; i < 9; i++) {
        if (_board[i].isEmpty) {
          _board[i] = 'O';
          best = math.max(best, _minimax(depth + 1, false));
          _board[i] = '';
        }
      }
      return best;
    } else {
      int best = 1000;
      for (int i = 0; i < 9; i++) {
        if (_board[i].isEmpty) {
          _board[i] = 'X';
          best = math.min(best, _minimax(depth + 1, true));
          _board[i] = '';
        }
      }
      return best;
    }
  }

  bool _checkWinWithoutState(String player) {
    for (final pattern in _winPatterns) {
      if (_board[pattern[0]] == player &&
          _board[pattern[1]] == player &&
          _board[pattern[2]] == player) {
        return true;
      }
    }
    return false;
  }

  bool _checkWinState(String player) {
    for (final pattern in _winPatterns) {
      if (_board[pattern[0]] == player &&
          _board[pattern[1]] == player &&
          _board[pattern[2]] == player) {
        setState(() {
          _winningLine = pattern;
        });
        return true;
      }
    }
    return false;
  }

  void _endGame(String result) {
    setState(() {
      _gameOver = true;
      _gameResult = result;
    });

    if (result == 'win') {
      SoundService.instance.play(SoundType.lineHighlight);
      SoundService.instance.play(SoundType.winFanfare);
      HapticFeedback.mediumImpact();
    } else if (result == 'loss') {
      SoundService.instance.play(SoundType.loseSound);
      HapticFeedback.vibrate();
    } else {
      SoundService.instance.play(SoundType.drawSound);
    }

    AchievementService.instance.saveTttResult(
      result: result,
      difficulty: _difficulty,
    ).then((_) => _loadStats());
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
          'TIC TAC TOE',
          style: GoogleFonts.pressStart2p(
            fontSize: 12,
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
    } else {
      return _buildGameArea();
    }
  }

  Widget _buildDifficultySelector() {
    final isHard = _difficulty == 'hard';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '⭕ VS ❌',
              style: const TextStyle(fontSize: 48),
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
                          ? const Color(0xFFF05A28).withOpacity(0.1)
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
            // Unbeatable Warning
            AnimatedBuilder(
              animation: _warningAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: isHard ? _warningAnimation.value : 0.0,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Text(
                      '⚠️ UNBEATABLE MODE ACTIVE\nMINIMAX ALGORITHM ENGAGED',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.pressStart2p(
                        fontSize: 8,
                        color: AppColors.error,
                        height: 1.5,
                      ),
                    ),
                  ),
                );
              },
            ),
            SizedBox(
              width: 220,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _startNewGame(_difficulty),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF05A28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'START GAME',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'WINS: $_wins  |  LOSSES: $_losses  |  DRAWS: $_draws',
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Score Panel
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            children: [
              Text(
                'DIFFICULTY: ${_difficulty.toUpperCase()}',
                style: GoogleFonts.shareTechMono(fontSize: 12, color: AppColors.textSecondary, letterSpacing: 1.5),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('WINS: $_wins', style: GoogleFonts.pressStart2p(fontSize: 9, color: Colors.green)),
                  const SizedBox(width: 20),
                  Text('DRAWS: $_draws', style: GoogleFonts.pressStart2p(fontSize: 9, color: Colors.orange)),
                  const SizedBox(width: 20),
                  Text('LOSSES: $_losses', style: GoogleFonts.pressStart2p(fontSize: 9, color: AppColors.error)),
                ],
              ),
            ],
          ),
        ),

        // 3x3 Grid
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF05A28).withOpacity(0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF05A28).withOpacity(0.15),
                        blurRadius: 16,
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 9,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemBuilder: (context, index) {
                        final val = _board[index];
                        final isWinningCell = _winningLine.contains(index);
                        return GestureDetector(
                          onTap: () => _onCellTap(index),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isWinningCell
                                  ? const Color(0xFFF05A28).withOpacity(0.2)
                                  : const Color(0xFF070B11),
                              border: Border.all(
                                color: isWinningCell
                                    ? const Color(0xFFF05A28)
                                    : const Color(0xFF161F2E),
                                width: isWinningCell ? 2.0 : 1.0,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                val,
                                style: GoogleFonts.pressStart2p(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: val == 'X'
                                      ? const Color(0xFFF05A28)
                                      : Colors.white,
                                  shadows: isWinningCell
                                      ? [
                                          Shadow(
                                            color: val == 'X' ? const Color(0xFFF05A28) : Colors.white,
                                            blurRadius: 12,
                                          )
                                        ]
                                      : [],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Message / Status board
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            _gameOver
                ? (_gameResult == 'win'
                    ? 'VICTORY! 🏆'
                    : _gameResult == 'loss'
                        ? 'DEFEAT! 💀'
                        : 'IT IS A DRAW!')
                : (_playerTurn ? 'YOUR TURN (❌)' : 'AI IS PLAYING (⭕)'),
            style: GoogleFonts.pressStart2p(
              fontSize: 10,
              color: _gameOver
                  ? (_gameResult == 'win'
                      ? Colors.green
                      : _gameResult == 'loss'
                          ? AppColors.error
                          : Colors.orange)
                  : Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Action controls
        Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_gameOver)
                ElevatedButton(
                  onPressed: () {
                    SoundService.instance.play(SoundType.buttonTap);
                    _startNewGame(_difficulty);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF05A28),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'PLAY AGAIN',
                    style: GoogleFonts.pressStart2p(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Opacity(
                  opacity: 0.5,
                  child: OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(
                      'PLAYING...',
                      style: GoogleFonts.pressStart2p(fontSize: 9, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              const SizedBox(width: 14),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _phase = 'select_difficulty';
                  });
                  SoundService.instance.play(SoundType.buttonBack);
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'MENU',
                  style: GoogleFonts.pressStart2p(fontSize: 9, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
