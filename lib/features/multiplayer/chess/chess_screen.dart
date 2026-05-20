import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';
import 'chess_logic.dart';
import 'chess_notifier.dart';

class ChessScreen extends ConsumerStatefulWidget {
  final String roomCode;
  final bool isCreator;
  const ChessScreen(
      {super.key, required this.roomCode, required this.isCreator});

  @override
  ConsumerState<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends ConsumerState<ChessScreen> {
  Pos? _selected;
  List<Pos> _highlights = [];
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chessRoomProvider.notifier).state = widget.roomCode;
      ref.read(chessIsCreatorProvider.notifier).state = widget.isCreator;
      ref.read(whiteTimerProvider.notifier).state = 600;
      ref.read(blackTimerProvider.notifier).state = 600;
      _startClock();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final chess = ref.read(chessNotifierProvider);
      if (chess.gameOver) {
        _clockTimer?.cancel();
        return;
      }
      if (chess.turn == PieceColor.white) {
        final t = ref.read(whiteTimerProvider);
        if (t <= 0) {
          ref.read(chessNotifierProvider.notifier).updateState(chess.copyWith(
                gameOver: true,
                winner: PieceColor.black,
                statusMsg: 'Black wins on time!',
              ));
          _clockTimer?.cancel();
        } else {
          ref.read(whiteTimerProvider.notifier).state = t - 1;
        }
      } else {
        final t = ref.read(blackTimerProvider);
        if (t <= 0) {
          ref.read(chessNotifierProvider.notifier).updateState(chess.copyWith(
                gameOver: true,
                winner: PieceColor.white,
                statusMsg: 'White wins on time!',
              ));
          _clockTimer?.cancel();
        } else {
          ref.read(blackTimerProvider.notifier).state = t - 1;
        }
      }
    });
  }

  void _onTap(Pos pos, ChessNotifier notifier, ChessState state) {
    if (state.gameOver || !notifier.isMyTurn) return;
    if (_selected == null) {
      final piece = state.board[pos.r][pos.c];
      if (piece != null && piece.color == notifier.myColor) {
        final moves = legalMoves(state, pos);
        setState(() {
          _selected = pos;
          _highlights = moves;
        });
      }
    } else {
      if (_highlights.contains(pos)) {
        notifier.makeMove(_selected!, pos);
        setState(() {
          _selected = null;
          _highlights = [];
        });
      } else {
        final piece = state.board[pos.r][pos.c];
        if (piece != null && piece.color == notifier.myColor) {
          final moves = legalMoves(state, pos);
          setState(() {
            _selected = pos;
            _highlights = moves;
          });
        } else {
          setState(() {
            _selected = null;
            _highlights = [];
          });
        }
      }
    }
  }

  String _fmt(int s) {
    final m = s ~/ 60, sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chessNotifierProvider);
    final notifier = ref.read(chessNotifierProvider.notifier);
    final whiteTime = ref.watch(whiteTimerProvider);
    final blackTime = ref.watch(blackTimerProvider);
    final myColor = notifier.myColor;
    final flip = myColor == PieceColor.black;

    final oppTurn =
        flip ? PieceColor.white : PieceColor.black;
    final oppActive =
        state.turn == oppTurn && !state.gameOver;

    final myTurnActive = state.turn == myColor && !state.gameOver;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GameForgeAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textSecondary,
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!state.gameOver)
            TextButton(
              onPressed: () => notifier.forfeit(),
              child: Text(
                'RESIGN',
                style: GoogleFonts.rajdhani(
                  color: AppColors.danger,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'CHESS',
                      style: GoogleFonts.rajdhani(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        fontSize: 22,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        widget.roomCode,
                        style: GoogleFonts.pressStart2p(
                          fontSize: 11,
                          color: AppColors.fire2,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _TimerBar(
                label: flip ? 'OPPONENT · WHITE' : 'OPPONENT · BLACK',
                time: flip ? _fmt(whiteTime) : _fmt(blackTime),
                isActiveTurn: oppActive,
                isMine: false,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _buildBoard(state, notifier, flip),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  state.statusMsg,
                  style: GoogleFonts.inter(
                    color: AppColors.fire2,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _TimerBar(
                label:
                    myColor == PieceColor.white ? 'YOU · WHITE' : 'YOU · BLACK',
                time: myColor == PieceColor.white
                    ? _fmt(whiteTime)
                    : _fmt(blackTime),
                isActiveTurn: myTurnActive,
                isMine: true,
              ),
              const SizedBox(height: 8),
            ],
          ),
          if (state.gameOver)
            _GameOverOverlay(state: state, myColor: myColor),
        ],
      ),
    );
  }

  Widget _buildBoard(ChessState state, ChessNotifier notifier, bool flip) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = constraints.maxWidth / 8;
        final pieceSize = cellSize * 0.78;
        final dotSize = cellSize * 0.28;

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                childAspectRatio: 1,
              ),
              itemCount: 64,
              itemBuilder: (_, idx) {
                final displayR = idx ~/ 8;
                final displayC = idx % 8;
                final r = flip ? 7 - displayR : displayR;
                final c = flip ? 7 - displayC : displayC;
                final pos = Pos(r, c);
                final piece = state.board[r][c];
                final isLight = (r + c) % 2 == 0;
                final isSelected = _selected == pos;
                final isHighlight = _highlights.contains(pos);

                Color bg;
                if (isSelected) {
                  bg = AppColors.primary.withValues(alpha: 0.82);
                } else if (isHighlight) {
                  bg = AppColors.primary.withValues(alpha: 0.42);
                } else {
                  bg = isLight
                      ? AppColors.chessSquareLight
                      : AppColors.chessSquareDark;
                }

                return GestureDetector(
                  onTap: () => _onTap(pos, notifier, state),
                  child: Container(
                    width: cellSize,
                    height: cellSize,
                    color: bg,
                    alignment: Alignment.center,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isHighlight && piece == null)
                          Container(
                            width: dotSize,
                            height: dotSize,
                            decoration: BoxDecoration(
                              color: AppColors.fire2.withValues(alpha: 0.95),
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (isHighlight && piece != null)
                          Container(
                            width: cellSize - 4,
                            height: cellSize - 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.95),
                                width: 3,
                              ),
                            ),
                          ),
                        if (piece != null)
                          Text(
                            piece.symbol,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: pieceSize,
                              height: 1.0,
                              shadows: [
                                Shadow(
                                  color: piece.color == PieceColor.white
                                      ? Colors.white.withValues(alpha: 0.45)
                                      : Colors.black.withValues(alpha: 0.65),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _TimerBar extends StatelessWidget {
  final String label;
  final String time;
  final bool isActiveTurn;
  final bool isMine;

  const _TimerBar({
    required this.label,
    required this.time,
    required this.isActiveTurn,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color labelColor;
    Color timeColor;

    if (!isMine) {
      bg = AppColors.surface;
      labelColor = AppColors.textSecondary;
      timeColor = AppColors.muted;
    } else if (isActiveTurn) {
      bg = AppColors.primary.withValues(alpha: 0.14);
      labelColor = AppColors.primary;
      timeColor = AppColors.primary;
    } else {
      bg = AppColors.surface;
      labelColor = AppColors.textSecondary;
      timeColor = AppColors.muted;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      color: bg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.rajdhani(
              color: labelColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              fontSize: 15,
            ),
          ),
          Text(
            time,
            style: GoogleFonts.pressStart2p(
              color: timeColor,
              fontSize: 18,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  final ChessState state;
  final PieceColor myColor;

  const _GameOverOverlay({required this.state, required this.myColor});

  @override
  Widget build(BuildContext context) {
    final won = state.winner == myColor;
    final isDraw = state.winner == null;

    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(28),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isDraw ? '🤝' : won ? '🏆' : '😞',
                style: const TextStyle(fontSize: 52),
              ),
              const SizedBox(height: 12),
              Text(
                isDraw ? 'DRAW' : won ? 'YOU WIN!' : 'YOU LOSE',
                style: GoogleFonts.rajdhani(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  color: isDraw
                      ? AppColors.gold
                      : won
                          ? AppColors.success
                          : AppColors.danger,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                state.statusMsg,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => context.go('/chess-lobby'),
                  child: Text(
                    'PLAY AGAIN',
                    style: GoogleFonts.rajdhani(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => context.go('/'),
                  child: Text(
                    'BACK',
                    style: GoogleFonts.rajdhani(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
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
