import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/crt_overlay.dart';
import 'package:game_forge/core/services/sound_service.dart';
import 'trivia_questions.dart';

class TriviaScreen extends StatefulWidget {
  final String roomCode;
  final bool isCreator;
  final String category;

  const TriviaScreen({
    super.key,
    required this.roomCode,
    required this.isCreator,
    required this.category,
  });

  @override
  State<TriviaScreen> createState() => _TriviaScreenState();
}

class _TriviaScreenState extends State<TriviaScreen> {
  RealtimeChannel? _channel;
  List<TriviaQuestion> _questions = [];
  int _currentQuestionIndex = 0;
  
  int _myScore = 0;
  int _opponentScore = 0;

  int? _mySelectedAnswer;
  double? _myAnswerTime;
  
  int? _opponentSelectedAnswer;
  double? _opponentAnswerTime;

  bool _showingResult = false;
  bool _gameOver = false;
  bool _opponentLeft = false;

  int _timerValue = 15;
  Timer? _countdownTimer;

  String get _myRole => widget.isCreator ? 'host' : 'guest';
  String get _opponentRole => widget.isCreator ? 'guest' : 'host';

  @override
  void initState() {
    super.initState();
    _loadQuestionsAndSubscribe();
  }

  Future<void> _loadQuestionsAndSubscribe() async {
    final client = Supabase.instance.client;
    
    try {
      final res = await client.from('trivia_rooms').select('questions').eq('room_code', widget.roomCode).single();
      final qJson = res['questions'] as List;
      _questions = qJson.map((q) => TriviaQuestion.fromJson(q as Map<String, dynamic>)).toList();
    } catch (_) {
      // Fallback offline list
      final qList = triviaQuestionsBank
          .where((q) => widget.category == 'random' || q.category == widget.category)
          .toList()
        ..shuffle();
      _questions = qList.take(10).toList();
    }

    if (_questions.isEmpty) {
      _questions = triviaQuestionsBank.take(10).toList();
    }

    setState(() {});
    _subscribe();
    _startQuestionTimer();
  }

  void _subscribe() {
    final client = Supabase.instance.client;
    final ch = client.channel('trivia:${widget.roomCode}');
    _channel = ch;

    ch
      .onBroadcast(
        event: 'answer',
        callback: (payload) {
          if (_gameOver || !mounted) return;
          final data = payload['payload'] ?? payload;
          final sender = data['role'] as String;
          if (sender == _opponentRole) {
            setState(() {
              _opponentSelectedAnswer = data['index'] as int?;
              _opponentAnswerTime = (data['timeSpent'] as num?)?.toDouble();
            });
            _checkBothAnswered();
          }
        },
      )
      .onPresenceSync((_) {
        if (_gameOver || !mounted) return;
        final presenceState = _channel?.presenceState();
        if (presenceState != null) {
          final roles = <String>{};
          for (final singleState in presenceState) {
            for (final p in singleState.presences) {
              final role = p.payload['role'];
              if (role is String) roles.add(role);
            }
          }
          if (roles.length == 1 && roles.contains(_myRole)) {
            setState(() {
              _opponentLeft = true;
              _gameOver = true;
              _myScore += 500; // forfeit bonus
            });
            _countdownTimer?.cancel();
            _saveFinalStats(true);
          }
        }
      })
      .subscribe((status, [err]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await ch.track({'role': _myRole});
        }
      });
  }

  void _startQuestionTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _timerValue = 15;
      _showingResult = false;
      _mySelectedAnswer = null;
      _myAnswerTime = null;
      _opponentSelectedAnswer = null;
      _opponentAnswerTime = null;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timerValue > 1) {
          _timerValue--;
        } else {
          _timerValue = 0;
          _countdownTimer?.cancel();
          _revealResult();
        }
      });
    });
  }

  void _submitAnswer(int index) {
    if (_mySelectedAnswer != null || _showingResult || _gameOver) return;

    SoundService.instance.play(SoundType.buttonTap);
    final timeSpent = 15.0 - _timerValue;
    setState(() {
      _mySelectedAnswer = index;
      _myAnswerTime = timeSpent;
    });

    _channel?.sendBroadcastMessage(
      event: 'answer',
      payload: {
        'role': _myRole,
        'index': index,
        'timeSpent': timeSpent,
      },
    );

    _checkBothAnswered();
  }

  void _checkBothAnswered() {
    if (_mySelectedAnswer != null && _opponentSelectedAnswer != null) {
      _countdownTimer?.cancel();
      _revealResult();
    }
  }

  void _revealResult() {
    if (_showingResult) return;
    setState(() => _showingResult = true);

    final currentQuestion = _questions[_currentQuestionIndex];
    final correctIdx = currentQuestion.correctAnswerIndex;

    int myPts = 0;
    int oppPts = 0;

    // Check my answer
    final myCorrect = _mySelectedAnswer == correctIdx;
    final oppCorrect = _opponentSelectedAnswer == correctIdx;

    if (myCorrect && oppCorrect) {
      if ((_myAnswerTime ?? 15.0) < (_opponentAnswerTime ?? 15.0)) {
        myPts = 100;
        oppPts = 50;
      } else {
        myPts = 50;
        oppPts = 100;
      }
    } else {
      if (myCorrect) myPts = 100;
      if (oppCorrect) oppPts = 100;
    }

    setState(() {
      _myScore += myPts;
      _opponentScore += oppPts;
    });

    if (myCorrect) {
      SoundService.instance.play(SoundType.coin);
    } else {
      SoundService.instance.play(SoundType.error);
    }

    // Update DB
    _updateDbProgress();

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_currentQuestionIndex < 9) {
        setState(() {
          _currentQuestionIndex++;
        });
        _startQuestionTimer();
      } else {
        setState(() {
          _gameOver = true;
        });
        _saveFinalStats(_myScore >= _opponentScore);
      }
    });
  }

  Future<void> _updateDbProgress() async {
    try {
      final client = Supabase.instance.client;
      final payload = widget.isCreator
          ? {
              'player1_score': _myScore,
              'player2_score': _opponentScore,
              'current_question': _currentQuestionIndex + 1,
            }
          : {
              'player1_score': _opponentScore,
              'player2_score': _myScore,
              'current_question': _currentQuestionIndex + 1,
            };
      await client.from('trivia_rooms').update(payload).eq('room_code', widget.roomCode);
    } catch (_) {}
  }

  Future<void> _saveFinalStats(bool won) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        await client.from('user_game_progress').insert({
          'user_id': userId,
          'game_id': 'trivia',
          'score': _myScore,
          'completed': true,
          'won': won,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}
  }

  void _playAgain() {
    SoundService.instance.play(SoundType.gameStart);
    context.go('/trivia-lobby');
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CrtOverlay(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  if (!_gameOver) ...[
                    _buildTimerBar(),
                    const SizedBox(height: 18),
                    _buildQuestionArea(currentQuestion),
                    const SizedBox(height: 24),
                    _buildAnswersList(currentQuestion),
                  ],
                  if (_gameOver) Expanded(child: _buildGameOverScreen()),
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'GAMEFORGE PIXEL',
                style: GoogleFonts.pressStart2p(fontSize: 9, color: AppColors.primary),
              ),
              Text(
                'Q: ${_currentQuestionIndex + 1}/10',
                style: GoogleFonts.pressStart2p(fontSize: 9, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PlayerScoreBar(
                  name: widget.isCreator ? 'YOU (Host)' : 'YOU (Guest)',
                  score: _myScore,
                  isLeading: _myScore >= _opponentScore,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _PlayerScoreBar(
                  name: widget.isCreator ? 'OPPONENT' : 'OPPONENT',
                  score: _opponentScore,
                  isLeading: _opponentScore >= _myScore,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBar() {
    final progress = _timerValue / 15.0;
    return Container(
      width: double.infinity,
      height: 6,
      color: Colors.white10,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: _timerValue > 5 ? AppColors.primary : AppColors.error,
            boxShadow: [
              BoxShadow(
                color: (_timerValue > 5 ? AppColors.primary : AppColors.error).withValues(alpha: 0.35),
                blurRadius: 6,
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionArea(TriviaQuestion q) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
              ),
              child: Text(
                q.category.toUpperCase(),
                style: GoogleFonts.pressStart2p(fontSize: 8, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            q.question,
            style: GoogleFonts.rajdhani(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswersList(TriviaQuestion q) {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: q.options.length,
        itemBuilder: (context, index) {
          final isMyPick = _mySelectedAnswer == index;
          final isOpponentPick = _opponentSelectedAnswer == index;
          final isCorrect = q.correctAnswerIndex == index;

          Color btnColor = AppColors.card;
          Color borderColor = AppColors.border;

          if (_showingResult) {
            if (isCorrect) {
              btnColor = Colors.green.withValues(alpha: 0.2);
              borderColor = Colors.green;
            } else if (isMyPick) {
              btnColor = Colors.red.withValues(alpha: 0.2);
              borderColor = Colors.red;
            }
          } else {
            if (isMyPick) {
              borderColor = AppColors.primary;
              btnColor = AppColors.primary.withValues(alpha: 0.12);
            }
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: ElevatedButton(
              onPressed: () => _submitAnswer(index),
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: borderColor,
                    width: isMyPick ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      q.options[index],
                      style: GoogleFonts.rajdhani(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (isMyPick)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text('👈 You', style: TextStyle(fontSize: 12)),
                    ),
                  if (_showingResult && isOpponentPick)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text('👉 Opponent', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGameOverScreen() {
    final won = _myScore >= _opponentScore;
    final text = won ? 'YOU WIN! 🧠' : 'SO CLOSE! 😅';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.pressStart2p(
              fontSize: 22,
              color: won ? AppColors.gold : AppColors.error,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Text(
                  'FINAL STANDINGS',
                  style: GoogleFonts.pressStart2p(fontSize: 10, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('YOU', style: GoogleFonts.rajdhani(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('$_myScore', style: GoogleFonts.pressStart2p(fontSize: 20, color: AppColors.primary)),
                      ],
                    ),
                    const Text('VS', style: TextStyle(color: Colors.white24, fontSize: 24)),
                    Column(
                      children: [
                        Text('OPPONENT', style: GoogleFonts.rajdhani(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('$_opponentScore', style: GoogleFonts.pressStart2p(fontSize: 20, color: Colors.white54)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'QUESTION DETAILS',
            style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          ...List.generate(_questions.length, (idx) {
            final q = _questions[idx];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Q${idx + 1}: ${q.question}', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 6),
                  Text('Correct answer: ${q.options[q.correctAnswerIndex]}', style: GoogleFonts.rajdhani(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _playAgain,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text('PLAY AGAIN', style: GoogleFonts.pressStart2p(fontSize: 11, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () => context.go('/'),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.border)),
              child: Text('BACK TO HOME', style: GoogleFonts.pressStart2p(fontSize: 9, color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
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
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.15),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                'OPPONENT LEFT!',
                style: GoogleFonts.pressStart2p(
                  fontSize: 10,
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Opponent left the match. You Win by default!',
                textAlign: TextAlign.center,
                style: GoogleFonts.rajdhani(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.go('/'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                child: Text('BACK TO MENU', style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerScoreBar extends StatelessWidget {
  final String name;
  final int score;
  final bool isLeading;
  final Color color;

  const _PlayerScoreBar({
    required this.name,
    required this.score,
    required this.isLeading,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLeading ? AppColors.primary : AppColors.border,
          width: isLeading ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name.toUpperCase(),
                  style: GoogleFonts.rajdhani(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (isLeading) const Text('👑', style: TextStyle(fontSize: 10)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$score',
            style: GoogleFonts.pressStart2p(
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
