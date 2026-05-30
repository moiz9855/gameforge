// Pure Dart — no Flutter dependencies
// Classic 15×15 Ludo board logic — v2 with dynamic active player tracking

// ─── Path & Positions ────────────────────────────────────────────────────────

/// 52 main-path cells as (row, col) on a 15×15 grid, clockwise.
const List<(int, int)> kMainPath = [
  // Player-0 (Cyan) exits here going right
  (6, 1), (6, 2), (6, 3), (6, 4), (6, 5),
  // Up left column
  (5, 6), (4, 6), (3, 6), (2, 6), (1, 6), (0, 6),
  // Top edge
  (0, 7), (0, 8),
  // Down right column
  (1, 8), (2, 8), (3, 8), (4, 8), (5, 8),
  // Right across (Player-1 Magenta exits at index 13)
  (6, 9), (6, 10), (6, 11), (6, 12), (6, 13), (6, 14),
  // Right edge
  (7, 14), (8, 14),
  // Left across bottom of top-right
  (8, 13), (8, 12), (8, 11), (8, 10), (8, 9),
  // Down right column (Player-2 Yellow exits at index 26)
  (9, 8), (10, 8), (11, 8), (12, 8), (13, 8), (14, 8),
  // Bottom edge
  (14, 7), (14, 6),
  // Up left column (Player-3 Purple exits at index 39)
  (13, 6), (12, 6), (11, 6), (10, 6), (9, 6),
  // Left across
  (8, 5), (8, 4), (8, 3), (8, 2), (8, 1), (8, 0),
  // Left edge
  (7, 0), (6, 0),
];

/// Home tracks (6 cells leading to center) per player.
const List<List<(int, int)>> kHomeTracks = [
  // Player 0 (Cyan): right along row 7
  [(7, 1), (7, 2), (7, 3), (7, 4), (7, 5), (7, 6)],
  // Player 1 (Magenta): down along col 7
  [(1, 7), (2, 7), (3, 7), (4, 7), (5, 7), (6, 7)],
  // Player 2 (Yellow): left along row 7
  [(7, 13), (7, 12), (7, 11), (7, 10), (7, 9), (7, 8)],
  // Player 3 (Purple): up along col 7
  [(13, 7), (12, 7), (11, 7), (10, 7), (9, 7), (8, 7)],
];

/// Each player's starting index on kMainPath.
const List<int> kPlayerStarts = [0, 13, 26, 39];

/// Home-track entry: absolute main-path index just before home turn.
const List<int> kHomeEntry = [51, 11, 24, 37];

/// Safe squares (star squares in classic Ludo).
const Set<int> kSafeIndices = {0, 8, 13, 21, 26, 34, 39, 47};

// ─── Colors ──────────────────────────────────────────────────────────────────
const kPlayerColors = [
  0xFFE53935, // Red — top-left home
  0xFF2563EB, // Blue — top-right home
  0xFFFFD54F, // Yellow — bottom-right home
  0xFF27C96A, // Green — bottom-left home
];

const kPlayerNames = ['Red', 'Blue', 'Yellow', 'Green'];

// ─── Domain Models ───────────────────────────────────────────────────────────

enum TokenStatus { base, active, home }

class LudoToken {
  final int playerIdx;
  final int tokenIdx;

  /// -1 = in base, 0-51 = absolute main-path index, 52-57 = home track 0-5
  final int position;
  final TokenStatus status;

  const LudoToken({
    required this.playerIdx,
    required this.tokenIdx,
    this.position = -1,
    this.status = TokenStatus.base,
  });

  bool get isHome => status == TokenStatus.home;
  bool get isBase => status == TokenStatus.base;
  bool get isActive => status == TokenStatus.active;

  /// (row, col) on the 15×15 grid. Returns null if in base/home finish.
  (int, int)? get gridPos {
    if (isBase) return null;
    if (isHome && position >= 52) {
      final homeIdx = position - 52;
      return kHomeTracks[playerIdx][homeIdx];
    }
    if (position >= 0 && position < 52) return kMainPath[position];
    return null;
  }

  LudoToken copyWith({int? position, TokenStatus? status}) => LudoToken(
        playerIdx: playerIdx,
        tokenIdx: tokenIdx,
        position: position ?? this.position,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'pi': playerIdx,
        'ti': tokenIdx,
        'pos': position,
        'st': status.index,
      };

  factory LudoToken.fromJson(Map<String, dynamic> j) => LudoToken(
        playerIdx: j['pi'] as int,
        tokenIdx: j['ti'] as int,
        position: j['pos'] as int,
        status: TokenStatus.values[j['st'] as int],
      );
}

class LudoState {
  final int numPlayers;

  /// Ordered list of player indices still actively in the match.
  /// Turn rotation wraps strictly around this list, so 2-player games
  /// never wait for the missing corners.
  final List<int> activePlayers;

  /// Index into [activePlayers] whose turn it is.
  final int currentTurnSlot;

  final int? lastDice;
  final bool bonusTurn; // from killing or rolling 6
  final bool mustRollDice;
  final bool gameOver;
  final int? winner;
  final List<List<LudoToken>> tokens; // tokens[playerIdx][tokenIdx]
  final String statusMsg;

  const LudoState({
    required this.numPlayers,
    required this.activePlayers,
    required this.currentTurnSlot,
    required this.tokens,
    this.lastDice,
    this.bonusTurn = false,
    this.mustRollDice = true,
    this.gameOver = false,
    this.winner,
    this.statusMsg = '',
  });

  /// The actual player index whose turn it currently is.
  int get currentPlayer => activePlayers[currentTurnSlot];

  static LudoState initial(int numPlayers) {
    // 2-player: seats 0 (Red) and 1 (Blue)
    // 3-player: seats 0, 1, 2. 4-player: all four.
    final seats = List.generate(numPlayers, (i) => i);

    final tokens = List.generate(
      4,
      (pi) => List.generate(4, (ti) => LudoToken(playerIdx: pi, tokenIdx: ti)),
    );
    return LudoState(
      numPlayers: numPlayers,
      activePlayers: seats,
      currentTurnSlot: 0,
      tokens: tokens,
      statusMsg: '${kPlayerNames[seats[0]]}\'s turn — Roll the dice!',
    );
  }

  LudoState copyWith({
    List<int>? activePlayers,
    int? currentTurnSlot,
    List<List<LudoToken>>? tokens,
    int? lastDice,
    bool? bonusTurn,
    bool? mustRollDice,
    bool? gameOver,
    int? winner,
    String? statusMsg,
    bool clearDice = false,
  }) =>
      LudoState(
        numPlayers: numPlayers,
        activePlayers: activePlayers ?? this.activePlayers,
        currentTurnSlot: currentTurnSlot ?? this.currentTurnSlot,
        tokens: tokens ?? this.tokens,
        lastDice: clearDice ? null : (lastDice ?? this.lastDice),
        bonusTurn: bonusTurn ?? this.bonusTurn,
        mustRollDice: mustRollDice ?? this.mustRollDice,
        gameOver: gameOver ?? this.gameOver,
        winner: winner ?? this.winner,
        statusMsg: statusMsg ?? this.statusMsg,
      );
}

// ─── Game Logic ───────────────────────────────────────────────────────────────

/// Converts a player-relative step count to an absolute main-path index.
int _absoluteIndex(int playerIdx, int steps) {
  return (kPlayerStarts[playerIdx] + steps) % 52;
}

/// Steps from absolute position to player-relative position.
int _relativeSteps(int playerIdx, int absPos) {
  final start = kPlayerStarts[playerIdx];
  return (absPos - start + 52) % 52;
}

/// Returns moveable token indices for the current player given a dice roll.
List<int> movableTokens(LudoState state, int dice) {
  final pi = state.currentPlayer;
  final myTokens = state.tokens[pi];
  final List<int> result = [];

  for (int ti = 0; ti < 4; ti++) {
    final t = myTokens[ti];
    if (t.isHome) continue;

    if (t.isBase) {
      // Can enter only on a 6
      if (dice == 6) result.add(ti);
    } else {
      final relSteps = _relativeSteps(pi, t.position);
      final newRelSteps = relSteps + dice;
      // Check if entering/advancing home track
      if (relSteps <= 50 && newRelSteps <= 57) {
        result.add(ti);
      }
    }
  }
  return result;
}

/// Apply a move and return new state. Returns unchanged state if invalid.
LudoState applyMove(LudoState state, int tokenIdx, int dice) {
  final pi = state.currentPlayer;
  final token = state.tokens[pi][tokenIdx];
  bool killed = false;

  // Deep copy tokens
  final newTokens = state.tokens
      .map((row) => row.map((t) => t).toList())
      .toList();

  LudoToken updated;

  if (token.isBase) {
    // Enter board at player's start
    final enterPos = kPlayerStarts[pi];
    updated = token.copyWith(position: enterPos, status: TokenStatus.active);
  } else {
    final relSteps = _relativeSteps(pi, token.position);
    final newRelSteps = relSteps + dice;

    if (newRelSteps >= 52) {
      // Entering home track
      final homeIdx = newRelSteps - 52; // 0-5
      if (homeIdx > 5) return state; // overshoots — invalid
      updated = token.copyWith(
        position: 52 + homeIdx,
        status: homeIdx == 5 ? TokenStatus.home : TokenStatus.active,
      );
    } else {
      final newAbsPos = _absoluteIndex(pi, newRelSteps);
      updated = token.copyWith(position: newAbsPos);

      // Kill check: send opponent tokens back to base (not safe, not home track)
      if (!kSafeIndices.contains(newAbsPos)) {
        for (int opp in state.activePlayers) {
          if (opp == pi) continue;
          for (int oti = 0; oti < 4; oti++) {
            final ot = newTokens[opp][oti];
            if (ot.isActive && ot.position == newAbsPos) {
              newTokens[opp][oti] =
                  ot.copyWith(position: -1, status: TokenStatus.base);
              killed = true;
            }
          }
        }
      }
    }
  }

  newTokens[pi][tokenIdx] = updated;

  // Win check: all 4 tokens home
  final allHome = newTokens[pi].every((t) => t.isHome);
  if (allHome) {
    return state.copyWith(
      tokens: newTokens,
      gameOver: true,
      winner: pi,
      statusMsg: '${kPlayerNames[pi]} wins!',
    );
  }

  // ── Turn rotation using activePlayers ──
  final bonus = dice == 6 || killed;
  final currentSlot = state.currentTurnSlot;
  final nextSlot = bonus
      ? currentSlot
      : (currentSlot + 1) % state.activePlayers.length;
  final nextPlayer = state.activePlayers[nextSlot];
  final nextName = kPlayerNames[nextPlayer];

  final msg = bonus
      ? '${kPlayerNames[pi]} gets a bonus roll!'
      : '$nextName\'s turn — Roll the dice!';

  return state.copyWith(
    tokens: newTokens,
    currentTurnSlot: nextSlot,
    lastDice: dice,
    bonusTurn: bonus,
    mustRollDice: true,
    statusMsg: msg,
  );
}

/// Remove a player from the active turn list (called on disconnect).
/// Returns updated state — may set gameOver if only 1 remains.
LudoState removePlayer(LudoState state, int playerIdx) {
  final newActive =
      state.activePlayers.where((p) => p != playerIdx).toList();

  if (newActive.isEmpty) {
    // Shouldn't happen but guard it
    return state.copyWith(
      activePlayers: newActive,
      gameOver: true,
      statusMsg: 'No players remaining.',
    );
  }

  if (newActive.length == 1) {
    return state.copyWith(
      activePlayers: newActive,
      currentTurnSlot: 0,
      gameOver: true,
      winner: newActive[0],
      statusMsg:
          'Opponent left! You Win! 🏆',
    );
  }

  // Clamp the current slot into the new shorter list
  final newSlot = state.currentTurnSlot.clamp(0, newActive.length - 1);
  return state.copyWith(
    activePlayers: newActive,
    currentTurnSlot: newSlot,
    statusMsg:
        '${kPlayerNames[newActive[newSlot]]}\'s turn — Roll the dice!',
  );
}
