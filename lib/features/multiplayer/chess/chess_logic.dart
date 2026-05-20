// Pure Dart chess logic — no Flutter dependencies

enum PieceType { king, queen, rook, bishop, knight, pawn }

enum PieceColor { white, black }

class ChessPiece {
  final PieceType type;
  final PieceColor color;
  const ChessPiece(this.type, this.color);

  String get symbol {
    const white = ['♔', '♕', '♖', '♗', '♘', '♙'];
    const black = ['♚', '♛', '♜', '♝', '♞', '♟'];
    final idx = PieceType.values.indexOf(type);
    return color == PieceColor.white ? white[idx] : black[idx];
  }

  Map<String, dynamic> toJson() => {
        'type': type.index,
        'color': color.index,
      };

  factory ChessPiece.fromJson(Map<String, dynamic> j) =>
      ChessPiece(PieceType.values[j['type'] as int], PieceColor.values[j['color'] as int]);
}

class Pos {
  final int r, c;
  const Pos(this.r, this.c);
  bool get valid => r >= 0 && r < 8 && c >= 0 && c < 8;

  @override
  bool operator ==(Object o) => o is Pos && r == o.r && c == o.c;

  @override
  int get hashCode => r * 8 + c;

  Map<String, dynamic> toJson() => {'r': r, 'c': c};
  factory Pos.fromJson(Map<String, dynamic> j) => Pos(j['r'] as int, j['c'] as int);
}

class ChessState {
  final List<List<ChessPiece?>> board;
  final PieceColor turn;
  final bool gameOver;
  final PieceColor? winner; // null = stalemate
  final String statusMsg;

  const ChessState({
    required this.board,
    required this.turn,
    this.gameOver = false,
    this.winner,
    this.statusMsg = '',
  });

  ChessState copyWith({
    List<List<ChessPiece?>>? board,
    PieceColor? turn,
    bool? gameOver,
    PieceColor? winner,
    bool clearWinner = false,
    String? statusMsg,
  }) =>
      ChessState(
        board: board ?? this.board,
        turn: turn ?? this.turn,
        gameOver: gameOver ?? this.gameOver,
        winner: clearWinner ? null : (winner ?? this.winner),
        statusMsg: statusMsg ?? this.statusMsg,
      );

  static ChessState initial() {
    final b = List.generate(8, (_) => List<ChessPiece?>.filled(8, null, growable: false),
        growable: false);

    void place(int r, int c, PieceType t, PieceColor col) => b[r][c] = ChessPiece(t, col);

    const order = [
      PieceType.rook,
      PieceType.knight,
      PieceType.bishop,
      PieceType.queen,
      PieceType.king,
      PieceType.bishop,
      PieceType.knight,
      PieceType.rook,
    ];
    for (int c = 0; c < 8; c++) {
      place(0, c, order[c], PieceColor.black);
      place(1, c, PieceType.pawn, PieceColor.black);
      place(6, c, PieceType.pawn, PieceColor.white);
      place(7, c, order[c], PieceColor.white);
    }
    return ChessState(board: b, turn: PieceColor.white);
  }

  /// Deep copy board
  static List<List<ChessPiece?>> _copyBoard(List<List<ChessPiece?>> b) =>
      List.generate(8, (r) => List<ChessPiece?>.from(b[r]));
}

// ────────────────────────────────────────────────────────────────
// Move generation
// ────────────────────────────────────────────────────────────────

List<Pos> legalMoves(ChessState state, Pos from) {
  final piece = state.board[from.r][from.c];
  if (piece == null || piece.color != state.turn) return [];
  return _pseudoMoves(state, from, piece)
      .where((to) => !_inCheckAfter(state, from, to, piece.color))
      .toList();
}

List<Pos> _pseudoMoves(ChessState state, Pos from, ChessPiece piece) {
  final b = state.board;
  final col = piece.color;

  bool empty(Pos p) => p.valid && b[p.r][p.c] == null;
  bool enemy(Pos p) => p.valid && b[p.r][p.c] != null && b[p.r][p.c]!.color != col;
  bool canLand(Pos p) => p.valid && (b[p.r][p.c] == null || b[p.r][p.c]!.color != col);

  final moves = <Pos>[];

  switch (piece.type) {
    case PieceType.pawn:
      final dir = col == PieceColor.white ? -1 : 1;
      final startRow = col == PieceColor.white ? 6 : 1;
      final step1 = Pos(from.r + dir, from.c);
      if (step1.valid && empty(step1)) {
        moves.add(step1);
        final step2 = Pos(from.r + dir * 2, from.c);
        if (from.r == startRow && empty(step2)) moves.add(step2);
      }
      for (final dc in [-1, 1]) {
        final cap = Pos(from.r + dir, from.c + dc);
        if (enemy(cap)) moves.add(cap);
      }
      break;

    case PieceType.knight:
      for (final d in [
        [-2, -1], [-2, 1], [2, -1], [2, 1],
        [-1, -2], [-1, 2], [1, -2], [1, 2],
      ]) {
        final p = Pos(from.r + d[0], from.c + d[1]);
        if (canLand(p)) moves.add(p);
      }
      break;

    case PieceType.king:
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          final p = Pos(from.r + dr, from.c + dc);
          if (canLand(p)) moves.add(p);
        }
      }
      break;

    case PieceType.rook:
      _slide(b, from, col, [[1,0],[-1,0],[0,1],[0,-1]], moves);
      break;
    case PieceType.bishop:
      _slide(b, from, col, [[1,1],[1,-1],[-1,1],[-1,-1]], moves);
      break;
    case PieceType.queen:
      _slide(b, from, col, [[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]], moves);
      break;
  }
  return moves;
}

void _slide(List<List<ChessPiece?>> b, Pos from, PieceColor col,
    List<List<int>> dirs, List<Pos> out) {
  for (final d in dirs) {
    var p = Pos(from.r + d[0], from.c + d[1]);
    while (p.valid) {
      if (b[p.r][p.c] == null) {
        out.add(p);
      } else {
        if (b[p.r][p.c]!.color != col) out.add(p);
        break;
      }
      p = Pos(p.r + d[0], p.c + d[1]);
    }
  }
}

bool _inCheckAfter(ChessState state, Pos from, Pos to, PieceColor col) {
  final nb = ChessState._copyBoard(state.board);
  nb[to.r][to.c] = nb[from.r][from.c];
  nb[from.r][from.c] = null;
  return _isInCheck(nb, col);
}

bool _isInCheck(List<List<ChessPiece?>> b, PieceColor col) {
  // Find king
  Pos? king;
  for (int r = 0; r < 8; r++) {
    for (int c = 0; c < 8; c++) {
      final p = b[r][c];
      if (p != null && p.type == PieceType.king && p.color == col) {
        king = Pos(r, c);
        break;
      }
    }
    if (king != null) break;
  }
  if (king == null) return true;

  final opp = col == PieceColor.white ? PieceColor.black : PieceColor.white;
  final tempState = ChessState(board: b, turn: opp);
  for (int r = 0; r < 8; r++) {
    for (int c = 0; c < 8; c++) {
      final p = b[r][c];
      if (p != null && p.color == opp) {
        final moves = _pseudoMoves(tempState, Pos(r, c), p);
        if (moves.contains(king)) return true;
      }
    }
  }
  return false;
}

// ────────────────────────────────────────────────────────────────
// Apply a move → new ChessState
// ────────────────────────────────────────────────────────────────

ChessState applyMove(ChessState state, Pos from, Pos to) {
  final nb = ChessState._copyBoard(state.board);
  var piece = nb[from.r][from.c]!;

  // Pawn promotion (auto-queen)
  if (piece.type == PieceType.pawn) {
    if ((piece.color == PieceColor.white && to.r == 0) ||
        (piece.color == PieceColor.black && to.r == 7)) {
      piece = ChessPiece(PieceType.queen, piece.color);
    }
  }

  nb[to.r][to.c] = piece;
  nb[from.r][from.c] = null;

  final opp = state.turn == PieceColor.white ? PieceColor.black : PieceColor.white;
  final nextState = ChessState(board: nb, turn: opp);

  // Check for checkmate / stalemate
  final oppHasMoves = _hasAnyLegal(nextState, opp);
  final oppInCheck = _isInCheck(nb, opp);

  if (!oppHasMoves) {
    if (oppInCheck) {
      return nextState.copyWith(
          gameOver: true,
          winner: state.turn,
          statusMsg: '${state.turn.name} wins by checkmate!');
    } else {
      return nextState.copyWith(
          gameOver: true,
          clearWinner: true,
          statusMsg: 'Stalemate — draw!');
    }
  }

  final check = oppInCheck ? ' — Check!' : '';
  return nextState.copyWith(statusMsg: '${opp.name}\'s turn$check');
}

bool _hasAnyLegal(ChessState state, PieceColor col) {
  for (int r = 0; r < 8; r++) {
    for (int c = 0; c < 8; c++) {
      final p = state.board[r][c];
      if (p != null && p.color == col) {
        if (legalMoves(state, Pos(r, c)).isNotEmpty) return true;
      }
    }
  }
  return false;
}
