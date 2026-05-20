import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';
import 'ludo_logic.dart';
import 'ludo_notifier.dart';
import 'ludo_board.dart';
import 'ludo_dice.dart';

class LudoScreen extends ConsumerStatefulWidget {
  final String roomCode;
  final bool isCreator;
  final int numPlayers;
  final int myPlayerIdx;

  const LudoScreen({
    super.key,
    required this.roomCode,
    required this.isCreator,
    required this.numPlayers,
    required this.myPlayerIdx,
  });

  @override
  ConsumerState<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends ConsumerState<LudoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ludoRoomProvider.notifier).state = widget.roomCode;
      ref.read(ludoNumPlayersProvider.notifier).state = widget.numPlayers;
      ref.read(ludoMyPlayerIdxProvider.notifier).state = widget.myPlayerIdx;
      ref.read(ludoIsCreatorProvider.notifier).state = widget.isCreator;
    });
  }

  late final List<Color> _playerColors =
      kPlayerColors.map((e) => Color(e)).toList();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ludoNotifierProvider);
    final notifier = ref.read(ludoNotifierProvider.notifier);
    final isMyTurn = notifier.isMyTurn;

    final movable = (!state.mustRollDice && isMyTurn && state.lastDice != null)
        ? movableTokens(state, state.lastDice!)
        : <int>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GameForgeAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textSecondary,
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Text(
                      'CYBER LUDO',
                      style: GoogleFonts.rajdhani(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        fontSize: 22,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        widget.roomCode,
                        style: GoogleFonts.pressStart2p(
                          fontSize: 11,
                          color: AppColors.primary,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _TurnBar(
                currentPlayer: state.currentPlayer,
                colors: _playerColors,
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                child: Text(
                  state.statusMsg,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.fire2,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: LudoBoard(
                        state: state,
                        myPlayerIdx: widget.myPlayerIdx,
                        movableTokenIndices: movable,
                        onTokenTap: (pi, ti) {
                          if (pi == widget.myPlayerIdx &&
                              movable.contains(ti)) {
                            notifier.moveToken(ti);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.border.withValues(alpha: 0.65)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(state.numPlayers, (i) {
                          final active = state.currentPlayer == i;
                          final col = _playerColors[i];
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: col.withValues(alpha: active ? 0.28 : 0.07),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: col.withValues(alpha: active ? 1 : 0.35),
                                width: active ? 2 : 1,
                              ),
                              boxShadow: active
                                  ? [
                                      BoxShadow(
                                        color: col.withValues(alpha: 0.35),
                                        blurRadius: 12,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Text(
                              kPlayerNames[i],
                              style: GoogleFonts.rajdhani(
                                color: col,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    LudoDice(
                      value: state.lastDice,
                      canRoll: isMyTurn && state.mustRollDice,
                      onRoll: () => notifier.rollDice(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (state.gameOver)
            _GameOverOverlay(state: state, myIdx: widget.myPlayerIdx),
        ],
      ),
    );
  }
}

class _TurnBar extends StatelessWidget {
  final int currentPlayer;
  final List<Color> colors;

  const _TurnBar({
    required this.currentPlayer,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final color = colors[currentPlayer];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: double.infinity,
      height: 5,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0),
            color,
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  final LudoState state;
  final int myIdx;

  const _GameOverOverlay({required this.state, required this.myIdx});

  @override
  Widget build(BuildContext context) {
    final won = state.winner == myIdx;
    final accent = state.winner != null
        ? Color(kPlayerColors[state.winner!])
        : AppColors.textSecondary;

    return Container(
      color: Colors.black.withValues(alpha: 0.74),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(28),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 26,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                won ? '🏆' : '😞',
                style: const TextStyle(fontSize: 52),
              ),
              const SizedBox(height: 12),
              Text(
                won ? 'YOU WIN!' : 'YOU LOSE',
                style: GoogleFonts.rajdhani(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  color: won ? AppColors.success : AppColors.danger,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                state.statusMsg,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
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
                  onPressed: () => context.go('/ludo-lobby'),
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
