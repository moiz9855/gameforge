import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';

enum _Dir { up, down, left, right }

class SnakeScreen extends StatefulWidget {
  const SnakeScreen({super.key});

  @override
  State<SnakeScreen> createState() => _SnakeScreenState();
}

class _SnakeScreenState extends State<SnakeScreen> {
  static const int _cols = 20;
  static const int _rows = 20;

  List<int> _snake = [];
  int _food = 0;
  _Dir _dir = _Dir.right;
  _Dir _nextDir = _Dir.right;
  int _score = 0;
  int _highScore = 0;
  bool _gameOver = false;
  Timer? _timer;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadHigh();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHigh() async {
    final p = await SharedPreferences.getInstance();
    setState(() => _highScore = p.getInt('snake_hs') ?? 0);
  }

  Future<void> _saveHigh() async {
    if (_score > _highScore) {
      final p = await SharedPreferences.getInstance();
      await p.setInt('snake_hs', _score);
      setState(() => _highScore = _score);
    }
  }

  void _start() {
    _timer?.cancel();
    const mid = (_rows ~/ 2) * _cols + _cols ~/ 2;
    setState(() {
      _snake = [mid, mid - 1, mid - 2];
      _dir = _Dir.right;
      _nextDir = _Dir.right;
      _score = 0;
      _gameOver = false;
    });
    _placeFood();
    _timer = Timer.periodic(const Duration(milliseconds: 140), (_) => _tick());
    _focusNode.requestFocus();
  }

  void _placeFood() {
    final rng = Random();
    int f;
    do {
      f = rng.nextInt(_rows * _cols);
    } while (_snake.contains(f));
    setState(() => _food = f);
  }

  void _tick() {
    if (_gameOver) return;
    setState(() {
      _dir = _nextDir;
      final head = _snake.first;
      final r = head ~/ _cols;
      final c = head % _cols;
      int nr = r, nc = c;
      switch (_dir) {
        case _Dir.up:    nr--; break;
        case _Dir.down:  nr++; break;
        case _Dir.left:  nc--; break;
        case _Dir.right: nc++; break;
      }
      if (nr < 0 || nr >= _rows || nc < 0 || nc >= _cols) {
        _endGame(); return;
      }
      final newHead = nr * _cols + nc;
      if (_snake.contains(newHead)) { _endGame(); return; }
      _snake.insert(0, newHead);
      if (newHead == _food) {
        _score++;
        _placeFood();
      } else {
        _snake.removeLast();
      }
    });
  }

  void _endGame() {
    _timer?.cancel();
    _gameOver = true;
    _saveHigh();
  }

  void _turn(_Dir d) {
    if (d == _Dir.up    && _dir == _Dir.down)  return;
    if (d == _Dir.down  && _dir == _Dir.up)    return;
    if (d == _Dir.left  && _dir == _Dir.right) return;
    if (d == _Dir.right && _dir == _Dir.left)  return;
    _nextDir = d;
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:    _turn(_Dir.up);    break;
      case LogicalKeyboardKey.arrowDown:  _turn(_Dir.down);  break;
      case LogicalKeyboardKey.arrowLeft:  _turn(_Dir.left);  break;
      case LogicalKeyboardKey.arrowRight: _turn(_Dir.right); break;
      default: break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GameForgeAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textSecondary,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('BEST: $_highScore',
                    style: const TextStyle(color: AppColors.fire2, fontSize: 11, letterSpacing: 1)),
                Text('SCORE: $_score',
                    style: const TextStyle(color: AppColors.primary, fontSize: 14,
                        fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
          ),
        ],
      ),
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _onKey,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Stack(
                  children: [
                    // Board
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1117),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 20, spreadRadius: 2),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: CustomPaint(
                          painter: _BoardPainter(
                            snake: _snake,
                            food: _food,
                            cols: _cols,
                            rows: _rows,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    // Game Over overlay
                    if (_gameOver)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('GAME OVER', style: TextStyle(
                                color: AppColors.error, fontSize: 32,
                                fontWeight: FontWeight.w900, letterSpacing: 4,
                              )),
                              const SizedBox(height: 12),
                              Text('Score: $_score', style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 20)),
                              if (_score >= _highScore && _score > 0)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text('NEW HIGH SCORE!', style: TextStyle(
                                    color: AppColors.warning, fontWeight: FontWeight.bold)),
                                ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _start,
                                icon: const Icon(Icons.replay, color: Colors.white),
                                label: const Text('PLAY AGAIN',
                                    style: TextStyle(color: Colors.white,
                                        fontWeight: FontWeight.bold, letterSpacing: 2)),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // D-Pad
            _DPad(onDir: _turn),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  final List<int> snake;
  final int food;
  final int cols;
  final int rows;

  _BoardPainter({required this.snake, required this.food, required this.cols, required this.rows});

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    // Grid lines (subtle)
    final gridPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;
    for (int r = 0; r <= rows; r++) {
      canvas.drawLine(Offset(0, r * cellH), Offset(size.width, r * cellH), gridPaint);
    }
    for (int c = 0; c <= cols; c++) {
      canvas.drawLine(Offset(c * cellW, 0), Offset(c * cellW, size.height), gridPaint);
    }

    // Food
    final foodR = food ~/ cols;
    final foodC = food % cols;
    final foodPaint = Paint()..color = AppColors.fire2;
    final foodRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(foodC * cellW + 2, foodR * cellH + 2, cellW - 4, cellH - 4),
      const Radius.circular(4),
    );
    canvas.drawRRect(foodRect, foodPaint);

    // Glow on food
    final glowPaint = Paint()
      ..color = AppColors.fire2.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(foodRect, glowPaint);

    // Snake body
    for (int i = 0; i < snake.length; i++) {
      final sr = snake[i] ~/ cols;
      final sc = snake[i] % cols;
      final t = 1.0 - (i / snake.length) * 0.5; // fade tail
      final snakePaint = Paint()
        ..color = (i == 0 ? AppColors.primary : AppColors.primary.withValues(alpha: t));
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(sc * cellW + 1, sr * cellH + 1, cellW - 2, cellH - 2),
        Radius.circular(i == 0 ? 5 : 3),
      );
      canvas.drawRRect(rect, snakePaint);
    }

    // Head glow
    if (snake.isNotEmpty) {
      final hr = snake[0] ~/ cols;
      final hc = snake[0] % cols;
      final headGlow = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(hc * cellW, hr * cellH, cellW, cellH),
          const Radius.circular(5),
        ),
        headGlow,
      );
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) => true;
}

class _DPad extends StatelessWidget {
  final void Function(_Dir) onDir;
  const _DPad({required this.onDir});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        children: [
          // Up
          Align(
            alignment: Alignment.topCenter,
            child: _DBtn(icon: Icons.arrow_upward, onTap: () => onDir(_Dir.up)),
          ),
          // Down
          Align(
            alignment: Alignment.bottomCenter,
            child: _DBtn(icon: Icons.arrow_downward, onTap: () => onDir(_Dir.down)),
          ),
          // Left
          Align(
            alignment: Alignment.centerLeft,
            child: _DBtn(icon: Icons.arrow_back, onTap: () => onDir(_Dir.left)),
          ),
          // Right
          Align(
            alignment: Alignment.centerRight,
            child: _DBtn(icon: Icons.arrow_forward, onTap: () => onDir(_Dir.right)),
          ),
          // Center dot
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _DBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8),
          ],
        ),
        child: Icon(icon, color: AppColors.fire2, size: 24),
      ),
    );
  }
}
