import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/crt_overlay.dart';
import 'package:game_forge/core/services/sound_service.dart';
import 'drawing_canvas.dart';

class DrawScreen extends StatefulWidget {
  final String roomCode;
  final bool isCreator;
  final int maxPlayers;

  const DrawScreen({
    super.key,
    required this.roomCode,
    required this.isCreator,
    required this.maxPlayers,
  });

  @override
  State<DrawScreen> createState() => _DrawScreenState();
}

class _DrawScreenState extends State<DrawScreen> {
  RealtimeChannel? _channel;
  final List<DrawingPoint?> _points = [];
  final List<Map<String, dynamic>> _chatMessages = [];
  final List<Map<String, String>> _players = [];
  final Map<String, int> _scores = {};
  
  String _gameStatus = 'selecting_word'; // selecting_word, drawing, scoreboard, gameOver
  String? _currentWord;
  List<String> _wordOptions = [];
  String _currentDrawerId = '';
  String _currentDrawerName = '';
  
  int _roundNumber = 1;
  int _timerValue = 80;


  bool _hasGuessedCorrectly = false;
  bool _opponentLeft = false;
  final Set<String> _roundCorrectGuessers = {};

  final TextEditingController _guessController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  // Canvas settings (for drawer)
  Color _activeColor = Colors.white;
  double _activeSize = 4.0;
  bool _isEraser = false;

  final List<Color> _palette = [
    Colors.white, Colors.black, Colors.red, Colors.green,
    Colors.blue, Colors.yellow, Colors.orange, Colors.purple,
    Colors.pink, Colors.cyan, Colors.brown, Colors.teal,
    Colors.amber, Colors.lime, Colors.indigo, Colors.grey,
  ];

  final List<String> _allWords = [
    "DOG", "CAT", "LION", "ELEPHANT", "GIRAFFE", "ZEBRA", "PANDA", "MONKEY",
    "PIZZA", "BURGER", "SUSHI", "PASTA", "TACO", "DONUT", "ICE CREAM", "COFFEE",
    "SOCCER", "BASKETBALL", "TENNIS", "BASEBALL", "GOLF", "SWIMMING", "BOXING",
    "PARIS", "TOKYO", "LONDON", "EGYPT", "BEACH", "FOREST", "DESERT", "CITY",
    "BATMAN", "AVENGERS", "TITANIC", "AVATAR", "FROZEN", "MATRIX", "CHAIR",
    "TABLE", "PHONE", "LAPTOP", "CLOCK", "LAMP", "KEY", "BOTTLE", "RUNNING",
    "FLYING", "CRYING", "SMILING", "LAUGHING", "JUMPING", "SLEEPING"
  ];

  String get _myId => Supabase.instance.client.auth.currentUser?.id ?? '';
  String get _myName {
    final email = Supabase.instance.client.auth.currentUser?.email ?? 'Player';
    return email.split('@')[0].toUpperCase();
  }
  bool get _isMyTurn => _myId == _currentDrawerId;

  @override
  void initState() {
    super.initState();
    _subscribeAndSetup();
  }

  void _subscribeAndSetup() {
    final client = Supabase.instance.client;
    final ch = client.channel('draw:${widget.roomCode}');
    _channel = ch;

    ch
      .onPresenceSync((_) {
        if (!mounted) return;
        final presenceState = _channel?.presenceState();
        if (presenceState != null) {
          final List<Map<String, String>> currentPlayers = [];
          for (final singleState in presenceState) {
            for (final p in singleState.presences) {
              final id = p.payload['id'] as String?;
              final name = p.payload['name'] as String?;
              if (id != null && name != null) {
                currentPlayers.add({'id': id, 'name': name});
              }
            }
          }
          setState(() {
            _players
              ..clear()
              ..addAll(currentPlayers);
            for (var p in _players) {
              _scores.putIfAbsent(p['id']!, () => 0);
            }
          });

          if (_players.length == 1 && _currentDrawerId.isNotEmpty) {
            setState(() {
              _opponentLeft = true;
            });
            _countdownTimer?.cancel();
          }
        }
      })
      .onBroadcast(
        event: 'draw_stroke',
        callback: (payload) {
          if (_isMyTurn || !mounted) return;
          final data = payload['payload'] ?? payload;
          final type = data['type'] as String;

          setState(() {
            if (type == 'start') {
              final double px = (data['x'] as num).toDouble();
              final double py = (data['y'] as num).toDouble();
              final double size = (data['size'] as num).toDouble();
              final int colorVal = data['color'] as int;

              final paint = Paint()
                ..color = Color(colorVal)
                ..strokeWidth = size
                ..strokeCap = StrokeCap.round
                ..style = PaintingStyle.stroke;

              _points.add(DrawingPoint(offset: Offset(px, py), paint: paint));
            } else if (type == 'update') {
              final double px = (data['x'] as num).toDouble();
              final double py = (data['y'] as num).toDouble();
              final lastPoint = _points.lastWhere((p) => p != null);
              
              _points.add(DrawingPoint(offset: Offset(px, py), paint: lastPoint!.paint));
            } else if (type == 'end') {
              _points.add(null);
            } else if (type == 'clear') {
              _points.clear();
            }
          });
        },
      )
      .onBroadcast(
        event: 'guess_message',
        callback: (payload) {
          if (!mounted) return;
          final data = payload['payload'] ?? payload;
          setState(() {
            _chatMessages.add(data);
          });
          _scrollChatToEnd();
        },
      )
      .onBroadcast(
        event: 'correct_guess',
        callback: (payload) {
          if (!mounted) return;
          final data = payload['payload'] ?? payload;
          final guesserId = data['guesserId'] as String;
          final guesserName = data['guesserName'] as String;
          final pts = data['points'] as int;

          setState(() {
            _roundCorrectGuessers.add(guesserId);
            _scores[guesserId] = (_scores[guesserId] ?? 0) + pts;
            _scores[_currentDrawerId] = (_scores[_currentDrawerId] ?? 0) + 10;
            _chatMessages.add({
              'sender': 'SYSTEM',
              'text': '✓ $guesserName guessed it!',
              'isCorrect': true,
            });
          });
          _scrollChatToEnd();

          if (_roundCorrectGuessers.length >= _players.length - 1) {
            _endRound();
          }
        },
      )
      .onBroadcast(
        event: 'word_selected',
        callback: (payload) {
          if (!mounted) return;
          final data = payload['payload'] ?? payload;
          setState(() {
            _currentWord = data['word'] as String;
            _gameStatus = 'drawing';
            _timerValue = 80;
            _points.clear();
            _roundCorrectGuessers.clear();
            _hasGuessedCorrectly = false;
          });
          _startDrawingTimer();
        },
      )
      .onBroadcast(
        event: 'next_turn',
        callback: (payload) {
          if (!mounted) return;
          final data = payload['payload'] ?? payload;
          _setupTurn(data['drawerId'] as String, data['round'] as int);
        },
      )
      .subscribe((status, [err]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await ch.track({
            'id': _myId,
            'name': _myName,
          });
          if (widget.isCreator) {
            Timer(const Duration(seconds: 1), () => _initGameFlow());
          }
        }
      });
  }

  void _initGameFlow() {
    if (_players.isEmpty) return;
    _setupTurn(_players[0]['id']!, 1);
  }

  void _setupTurn(String drawerId, int round) {
    final drawer = _players.firstWhere((p) => p['id'] == drawerId);
    
    // Choose 3 random words
    final words = List.from(_allWords)..shuffle();
    final options = List<String>.from(words.take(3));

    setState(() {
      _currentDrawerId = drawerId;
      _currentDrawerName = drawer['name']!;
      _roundNumber = round;
      _gameStatus = 'selecting_word';
      _wordOptions = options;
      _currentWord = null;
      _hasGuessedCorrectly = false;
      _roundCorrectGuessers.clear();
      _points.clear();
      _timerValue = 15;
    });

    _startSelectionTimer();

    // Broadcast next turn info
    if (widget.isCreator) {
      _channel?.sendBroadcastMessage(
        event: 'next_turn',
        payload: {
          'drawerId': drawerId,
          'round': round,
        },
      );
    }
  }

  Timer? _countdownTimer;

  void _startSelectionTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timerValue > 1) {
          _timerValue--;
        } else {
          _countdownTimer?.cancel();
          if (_isMyTurn) {
            _selectWord(_wordOptions[0]);
          }
        }
      });
    });
  }

  void _selectWord(String word) {
    _countdownTimer?.cancel();
    _channel?.sendBroadcastMessage(
      event: 'word_selected',
      payload: {'word': word},
    );
    setState(() {
      _currentWord = word;
      _gameStatus = 'drawing';
      _timerValue = 80;
    });
    _startDrawingTimer();
  }

  void _startDrawingTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timerValue > 1) {
          _timerValue--;
        } else {
          _countdownTimer?.cancel();
          _endRound();
        }
      });
    });
  }

  void _endRound() {
    _countdownTimer?.cancel();
    setState(() {
      _gameStatus = 'scoreboard';
      _timerValue = 5;
    });

    SoundService.instance.play(SoundType.winFanfare);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timerValue > 1) {
          _timerValue--;
        } else {
          _countdownTimer?.cancel();
          _advanceGame();
        }
      });
    });
  }

  void _advanceGame() {
    if (!widget.isCreator) return;
    
    // Find next drawer
    final currentIdx = _players.indexWhere((p) => p['id'] == _currentDrawerId);
    final nextIdx = currentIdx + 1;
    
    if (nextIdx < _players.length) {
      _setupTurn(_players[nextIdx]['id']!, _roundNumber);
    } else {
      // Completed round, check if game is finished
      if (_roundNumber < 3) {
        _setupTurn(_players[0]['id']!, _roundNumber + 1);
      } else {
        // Game Over!
        _channel?.sendBroadcastMessage(event: 'game_over', payload: {});
        setState(() {
          _gameStatus = 'gameOver';
        });
        _saveGameStats();
      }
    }
  }

  Future<void> _saveGameStats() async {
    try {
      final client = Supabase.instance.client;
      final highestScore = _scores.values.fold(0, (maxVal, element) => element > maxVal ? element : maxVal);
      final won = _scores[_myId] == highestScore;

      await client.from('user_game_progress').insert({
        'user_id': _myId,
        'game_id': 'draw_guess',
        'score': _scores[_myId] ?? 0,
        'completed': true,
        'won': won,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  void _sendGuess() {
    final text = _guessController.text.trim().toUpperCase();
    if (text.isEmpty || _hasGuessedCorrectly || _isMyTurn) return;

    _guessController.clear();

    if (text == _currentWord) {
      setState(() {
        _hasGuessedCorrectly = true;
      });

      final points = _roundCorrectGuessers.isEmpty
          ? 100
          : (_roundCorrectGuessers.length == 1 ? 80 : 60);

      _channel?.sendBroadcastMessage(
        event: 'correct_guess',
        payload: {
          'guesserId': _myId,
          'guesserName': _myName,
          'points': points,
        },
      );
      SoundService.instance.play(SoundType.coin);
    } else {
      _channel?.sendBroadcastMessage(
        event: 'guess_message',
        payload: {
          'sender': _myName,
          'text': text,
        },
      );
      SoundService.instance.play(SoundType.buttonTap);
    }
  }

  // Draw callbacks
  void _onStrokeStart(Offset localPos) {
    if (!_isMyTurn) return;
    final color = _isEraser ? const Color(0xFF0F172A) : _activeColor;
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = _activeSize
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    setState(() {
      _points.add(DrawingPoint(offset: localPos, paint: paint));
    });

    _channel?.sendBroadcastMessage(
      event: 'draw_stroke',
      payload: {
        'type': 'start',
        'x': localPos.dx,
        'y': localPos.dy,
        'size': _activeSize,
        'color': color.toARGB32(),
      },
    );
  }

  void _onStrokeUpdate(Offset localPos) {
    if (!_isMyTurn) return;
    final lastPoint = _points.lastWhere((p) => p != null);

    setState(() {
      _points.add(DrawingPoint(offset: localPos, paint: lastPoint!.paint));
    });

    _channel?.sendBroadcastMessage(
      event: 'draw_stroke',
      payload: {
        'type': 'update',
        'x': localPos.dx,
        'y': localPos.dy,
      },
    );
  }

  void _onStrokeEnd() {
    if (!_isMyTurn) return;
    setState(() {
      _points.add(null);
    });
    _channel?.sendBroadcastMessage(
      event: 'draw_stroke',
      payload: {'type': 'end'},
    );
  }

  void _clearCanvas() {
    if (!_isMyTurn) return;
    setState(() {
      _points.clear();
    });
    _channel?.sendBroadcastMessage(
      event: 'draw_stroke',
      payload: {'type': 'clear'},
    );
  }

  String _getWordBlanks() {
    if (_currentWord == null) return '';
    if (_isMyTurn || _hasGuessedCorrectly) return _currentWord!;

    final chars = _currentWord!.split('');
    final list = <String>[];
    
    // Reveal letters based on timer
    for (int i = 0; i < chars.length; i++) {
      if (_timerValue <= 40 && i == 0) {
        list.add(chars[i]);
      } else if (_timerValue <= 20 && i == chars.length - 1) {
        list.add(chars[i]);
      } else {
        list.add('_');
      }
    }
    return list.join(' ');
  }

  void _scrollChatToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _channel?.unsubscribe();
    _guessController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Widget _buildOpponentLeftOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.success, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                'Opponent left! You Win! 🏆',
                textAlign: TextAlign.center,
                style: GoogleFonts.pressStart2p(
                  fontSize: 12,
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                child: Text('EXIT TO LOBBY', style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white)),
              ),
            ],
          ),
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
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  if (_gameStatus == 'selecting_word') _buildWordSelectionView(),
                  if (_gameStatus == 'drawing') _buildGameplayView(),
                  if (_gameStatus == 'scoreboard') _buildScoreboardView(),
                  if (_gameStatus == 'gameOver') _buildGameOverView(),
                ],
              ),
              if (_opponentLeft) _buildOpponentLeftOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () {
              SoundService.instance.play(SoundType.buttonBack);
              context.go('/');
            },
          ),
          Text(
            'GAMEFORGE PIXEL',
            style: GoogleFonts.pressStart2p(fontSize: 9, color: AppColors.primary),
          ),
          Text(
            'ROUND $_roundNumber/3',
            style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildWordSelectionView() {
    return Expanded(
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isMyTurn ? 'SELECT A WORD' : 'WAITING FOR DRAWER...',
                style: GoogleFonts.pressStart2p(fontSize: 12, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text(
                'Drawer is: $_currentDrawerName',
                style: GoogleFonts.rajdhani(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              if (_isMyTurn)
                ..._wordOptions.map((w) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _selectWord(w),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      child: Text(
                        w,
                        style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white),
                      ),
                    ),
                  );
                })
              else ...[
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  'Timer: $_timerValue',
                  style: GoogleFonts.pressStart2p(fontSize: 9, color: AppColors.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameplayView() {
    return Expanded(
      child: Column(
        children: [
          // Word Blanks and Timer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getWordBlanks(),
                  style: GoogleFonts.pressStart2p(
                    fontSize: 13,
                    letterSpacing: 2,
                    color: _hasGuessedCorrectly ? AppColors.success : Colors.white,
                  ),
                ),
                Text(
                  '⏱️ $_timerValue',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 10,
                    color: _timerValue <= 15 ? AppColors.error : Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Canvas Area
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DrawingCanvas(
                isDrawer: _isMyTurn,
                activeColor: _activeColor,
                activeSize: _activeSize,
                isEraser: _isEraser,
                points: _points,
                onStrokeStart: _onStrokeStart,
                onStrokeUpdate: _onStrokeUpdate,
                onStrokeEnd: _onStrokeEnd,
              ),
            ),
          ),

          // Controls / Palette for Drawer
          if (_isMyTurn) _buildDrawingControls(),

          // Chat / Guess feed
          Expanded(
            flex: 2,
            child: _buildChatAndGuesses(),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingControls() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
      ),
      child: Column(
        children: [
          // Tool size and erase
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.delete_forever, color: AppColors.error),
                onPressed: _clearCanvas,
              ),
              IconButton(
                icon: Icon(Icons.gesture, color: _isEraser ? Colors.white24 : AppColors.primary),
                onPressed: () => setState(() => _isEraser = false),
              ),
              IconButton(
                icon: Icon(Icons.cleaning_services_rounded, color: _isEraser ? AppColors.primary : Colors.white24),
                onPressed: () => setState(() => _isEraser = true),
              ),
              const Spacer(),
              ...[2.0, 4.0, 8.0, 12.0].map((sz) {
                final isSelected = _activeSize == sz;
                return GestureDetector(
                  onTap: () => setState(() => _activeSize = sz),
                  child: Container(
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? AppColors.primary : Colors.white24),
                    ),
                    child: Center(
                      child: Container(
                        width: sz,
                        height: sz,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 6),
          // Colors
          SizedBox(
            height: 35,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _palette.length,
              itemBuilder: (context, index) {
                final col = _palette[index];
                final isSelected = _activeColor == col;
                return GestureDetector(
                  onTap: () => setState(() {
                    _activeColor = col;
                    _isEraser = false;
                  }),
                  child: Container(
                    width: 25,
                    height: 25,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: col,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.orange : Colors.white24,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatAndGuesses() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _chatScrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                final msg = _chatMessages[index];
                final isSystem = msg['sender'] == 'SYSTEM';
                final isCorrect = msg['isCorrect'] == true;

                if (isSystem) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      msg['text']!,
                      style: GoogleFonts.pressStart2p(
                        fontSize: 8,
                        color: isCorrect ? AppColors.success : Colors.white60,
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        "${msg['sender']}: ",
                        style: GoogleFonts.rajdhani(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 14,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          msg['text']!,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (!_isMyTurn && !_hasGuessedCorrectly)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _guessController,
                      style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'TYPE YOUR GUESS...',
                        hintStyle: GoogleFonts.pressStart2p(fontSize: 7, color: Colors.white30),
                        filled: true,
                        fillColor: const Color(0x40000000),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendGuess(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                    onPressed: _sendGuess,
                  ),
                ],
              ),
            ),
          if (_hasGuessedCorrectly)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.green.withValues(alpha: 0.12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text(
                    'YOU GUESSED CORRECTLY!',
                    style: GoogleFonts.pressStart2p(fontSize: 8, color: AppColors.success),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreboardView() {
    return Expanded(
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ROUND SCORES',
                style: GoogleFonts.pressStart2p(fontSize: 12, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'Secret Word was: $_currentWord',
                style: GoogleFonts.rajdhani(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _players.length,
                itemBuilder: (context, index) {
                  final p = _players[index];
                  final score = _scores[p['id']] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          p['name']!,
                          style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white),
                        ),
                        Text(
                          '$score PTS',
                          style: GoogleFonts.pressStart2p(fontSize: 8, color: AppColors.primary),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Next round starts in: $_timerValue s',
                style: GoogleFonts.pressStart2p(fontSize: 7, color: Colors.white30),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverView() {
    final entries = _scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final winnerId = entries.isNotEmpty ? entries.first.key : '';
    final winnerName = _players.firstWhere((p) => p['id'] == winnerId, orElse: () => {'name': 'Player'})['name'];

    return Expanded(
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👑', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                'WINNER: $winnerName! 🏆',
                textAlign: TextAlign.center,
                style: GoogleFonts.pressStart2p(fontSize: 12, color: AppColors.gold, height: 1.4),
              ),
              const SizedBox(height: 24),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final e = entries[index];
                  final name = _players.firstWhere((p) => p['id'] == e.key, orElse: () => {'name': 'Player'})['name'];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${index + 1}. $name',
                          style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white),
                        ),
                        Text(
                          '${e.value} PTS',
                          style: GoogleFonts.pressStart2p(fontSize: 8, color: AppColors.primary),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    SoundService.instance.play(SoundType.gameStart);
                    context.go('/draw-lobby');
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: Text(
                    'PLAY AGAIN',
                    style: GoogleFonts.pressStart2p(fontSize: 9, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => context.go('/'),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.border)),
                  child: Text(
                    'BACK TO MENU',
                    style: GoogleFonts.pressStart2p(fontSize: 9, color: AppColors.textSecondary),
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
