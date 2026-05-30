import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/gameforge_app_bar.dart';

import 'package:game_forge/features/multiplayer/meme/meme_templates.dart';

class MemeScreen extends ConsumerStatefulWidget {
  final String roomCode;
  final bool isCreator;

  const MemeScreen({
    super.key,
    required this.roomCode,
    required this.isCreator,
  });

  @override
  ConsumerState<MemeScreen> createState() => _MemeScreenState();
}

class _MemeScreenState extends ConsumerState<MemeScreen> with TickerProviderStateMixin {
  late final RealtimeChannel _channel;
  final _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _players = [];
  Map<String, int> _scores = {};
  
  String _phase = 'loading'; // caption, voting, results, game_over
  int _round = 1;
  Map<String, String>? _currentMeme;
  
  final Map<String, String> _captions = {};
  final Map<String, String> _votes = {}; // voterId -> authorId of caption
  
  String _myId = '';
  String? _myVote;
  bool _iSubmittedCaption = false;
  
  Timer? _phaseTimer;
  int _timeLeft = 0;
  int _maxTime = 60;
  
  // Host tracking
  bool _amIHost = false;
  final Set<String> _presentIds = {};
  
  final TextEditingController _captionController = TextEditingController();

  late AnimationController _pulseAnim;
  bool _opponentLeft = false;

  @override
  void initState() {
    super.initState();
    _myId = _supabase.auth.currentUser?.id ?? '';
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _initMultiplayer();
  }

  Widget _buildMemeWithCaption(String imageUrl, String caption, {required double fontSize, double? height, double? width}) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        CachedNetworkImage(
          imageUrl: imageUrl,
          height: height,
          width: width,
          fit: BoxFit.contain,
          placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Color(0xFFF05A28))),
          errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
        ),
        if (caption.isNotEmpty)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              color: Colors.black.withValues(alpha: 0.6),
              child: Text(
                caption.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.pressStart2p(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    const Shadow(offset: Offset(-1.5, -1.5), color: Colors.black),
                    const Shadow(offset: Offset(1.5, -1.5), color: Colors.black),
                    const Shadow(offset: Offset(1.5, 1.5), color: Colors.black),
                    const Shadow(offset: Offset(-1.5, 1.5), color: Colors.black),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _initMultiplayer() async {
    // 1. Fetch initial DB state
    try {
      final res = await _supabase.from('meme_rooms').select().eq('room_code', widget.roomCode).single();
      
      final dbPlayers = List<Map<String, dynamic>>.from(res['players'] as List);
      setState(() {
        _players = dbPlayers;
        if (res['scores'] != null) {
          _scores = Map<String, int>.from(res['scores']);
        } else {
          for (var p in _players) {
            _scores[p['id']] = 0;
          }
        }
      });
    } catch (e) {
      debugPrint('Error fetching room: $e');
    }

    // 2. Setup Realtime Channel
    _channel = _supabase.channel('meme:${widget.roomCode}');
    
    _channel
      .onPresenceSync((_) {
        if (!mounted) return;
        final state = _channel.presenceState();
        _presentIds.clear();
        for (final singleState in state) {
          for (final p in singleState.presences) {
            final id = p.payload['id'] as String?;
            if (id != null) _presentIds.add(id);
          }
        }
        _checkHostStatus();
      })
      .onBroadcast(event: 'new_round', callback: _onNewRound)
      .onBroadcast(event: 'caption_submitted', callback: _onCaptionSubmitted)
      .onBroadcast(event: 'voting_phase', callback: _onVotingPhase)
      .onBroadcast(event: 'vote_submitted', callback: _onVoteSubmitted)
      .onBroadcast(event: 'round_results', callback: _onRoundResults)
      .onBroadcast(event: 'game_over', callback: _onGameOver)
      .subscribe((status, [err]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await _channel.track({'id': _myId});
          // After joining, if host, start first round
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted && _amIHost && _phase == 'loading') {
              _hostStartNextRound(1);
            }
          });
        }
      });
  }
  
  void _checkHostStatus() {
    if (_presentIds.isEmpty) return;
    final sorted = _presentIds.toList()..sort();
    final amIHostNow = sorted.first == _myId;
    if (amIHostNow != _amIHost) {
      setState(() => _amIHost = amIHostNow);
      // If we became host mid-game, we could hypothetically resume logic, 
      // but for simplicity we rely on the current phase timers if we transition gracefully.
    }

    if (_players.length > 1 && _presentIds.length == 1 && _presentIds.contains(_myId)) {
      setState(() {
        _opponentLeft = true;
      });
    }
  }

  // ================= HOST LOGIC =================

  void _hostStartNextRound(int roundNum) {
    if (!_amIHost) return;
    
    // Pick random meme
    final rnd = Random();
    final meme = memeTemplates[rnd.nextInt(memeTemplates.length)];
    
    _channel.sendBroadcastMessage(event: 'new_round', payload: {
      'round': roundNum,
      'meme': meme,
    });
    
    _onNewRound({'round': roundNum, 'meme': meme});
  }
  
  void _hostCheckAllCaptions() {
    if (!_amIHost || _phase != 'caption') return;
    // Count how many present players submitted
    int submittedCount = 0;
    for (var id in _presentIds) {
      if (_captions.containsKey(id)) submittedCount++;
    }
    if (submittedCount >= _presentIds.length) {
      _hostTransitionToVoting();
    }
  }
  
  void _hostTransitionToVoting() {
    if (!_amIHost) return;
    _phaseTimer?.cancel();
    
    // Auto-fill missing captions for present players
    for (var id in _presentIds) {
      if (!_captions.containsKey(id)) {
        _captions[id] = "...";
      }
    }
    
    _channel.sendBroadcastMessage(event: 'voting_phase', payload: {
      'captions': _captions,
    });
    
    _onVotingPhase({'captions': _captions});
  }
  
  void _hostCheckAllVotes() {
    if (!_amIHost || _phase != 'voting') return;
    int voteCount = 0;
    for (var id in _presentIds) {
      if (_votes.containsKey(id)) voteCount++;
    }
    // Expected votes = present players - 1 (if you can't vote for yourself, though technically everyone votes)
    // Actually everyone votes, but if they are the only author maybe they don't? We allow everyone to vote.
    if (voteCount >= _presentIds.length) {
      _hostTransitionToResults();
    }
  }
  
  void _hostTransitionToResults() async {
    if (!_amIHost) return;
    _phaseTimer?.cancel();
    
    // Tally votes
    Map<String, int> voteTally = {};
    for (var authorId in _captions.keys) {
      voteTally[authorId] = 0;
    }
    
    for (var v in _votes.values) {
      if (voteTally.containsKey(v)) {
        voteTally[v] = voteTally[v]! + 1;
      }
    }
    
    // Calculate points: 100 for 1st, 60 for 2nd, 30 for 3rd
    // Sort authors by vote count descending
    final sortedAuthors = voteTally.keys.toList()..sort((a, b) => voteTally[b]!.compareTo(voteTally[a]!));
    
    Map<String, int> roundPoints = {};
    if (sortedAuthors.isNotEmpty && voteTally[sortedAuthors.first]! > 0) {
      int prevVotes = -1;
      int currentRank = 0;
      List<int> pointsDist = [100, 60, 30, 0];
      
      for (var author in sortedAuthors) {
        int v = voteTally[author]!;
        if (v == 0) {
          roundPoints[author] = 0;
          continue;
        }
        if (v != prevVotes) {
          currentRank++;
          prevVotes = v;
        }
        int pts = currentRank <= pointsDist.length ? pointsDist[currentRank - 1] : 0;
        roundPoints[author] = pts;
        _scores[author] = (_scores[author] ?? 0) + pts;
      }
    }
    
    // Save to DB
    try {
      await _supabase.from('meme_rooms').update({
        'scores': _scores,
      }).eq('room_code', widget.roomCode);
    } catch (_) {}
    
    _channel.sendBroadcastMessage(event: 'round_results', payload: {
      'voteTally': voteTally,
      'roundPoints': roundPoints,
      'scores': _scores,
    });
    
    _onRoundResults({
      'voteTally': voteTally,
      'roundPoints': roundPoints,
      'scores': _scores,
    });
  }

  // ================= CLIENT BROADCAST HANDLERS =================

  void _onNewRound(Map<String, dynamic> payload) {
    if (!mounted) return;
    setState(() {
      _round = payload['round'];
      _currentMeme = Map<String, String>.from(payload['meme']);
      _phase = 'caption';
      _captions.clear();
      _votes.clear();
      _myVote = null;
      _iSubmittedCaption = false;
      _captionController.clear();
      _maxTime = 60;
      _timeLeft = 60;
    });
    
    _startTimer(() {
      if (_amIHost) _hostTransitionToVoting();
    });
  }
  
  void _onCaptionSubmitted(Map<String, dynamic> payload) {
    if (!mounted) return;
    setState(() {
      _captions[payload['id']] = payload['caption'];
    });
    if (_amIHost) _hostCheckAllCaptions();
  }
  
  void _onVotingPhase(Map<String, dynamic> payload) {
    if (!mounted) return;
    setState(() {
      _phase = 'voting';
      _captions.clear();
      _captions.addAll(Map<String, String>.from(payload['captions']));
      _maxTime = 30;
      _timeLeft = 30;
    });
    
    _startTimer(() {
      if (_amIHost) _hostTransitionToResults();
    });
  }
  
  void _onVoteSubmitted(Map<String, dynamic> payload) {
    if (!mounted) return;
    setState(() {
      _votes[payload['voterId']] = payload['authorId'];
    });
    if (_amIHost) _hostCheckAllVotes();
  }
  
  Map<String, int> _roundVoteTally = {};
  Map<String, int> _roundPoints = {};
  
  void _onRoundResults(Map<String, dynamic> payload) {
    if (!mounted) return;
    setState(() {
      _phase = 'results';
      _roundVoteTally = Map<String, int>.from(payload['voteTally']);
      _roundPoints = Map<String, int>.from(payload['roundPoints']);
      _scores = Map<String, int>.from(payload['scores']);
      _maxTime = 10;
      _timeLeft = 10;
    });
    _startTimer(() {
      if (_amIHost) {
        if (_round < 5) {
          _hostStartNextRound(_round + 1);
        } else {
          _channel.sendBroadcastMessage(event: 'game_over', payload: {'scores': _scores});
          _onGameOver({'scores': _scores});
        }
      }
    });
  }
  
  void _onGameOver(Map<String, dynamic> payload) {
    if (!mounted) return;
    setState(() {
      _phase = 'game_over';
      _scores = Map<String, int>.from(payload['scores']);
    });
    _phaseTimer?.cancel();
    
    // (Achievements could be saved here in the future)
  }
  
  // ================= UTILS =================
  
  void _startTimer(VoidCallback onComplete) {
    _phaseTimer?.cancel();
    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          timer.cancel();
          onComplete();
        }
      });
    });
  }
  
  void _submitCaption() {
    if (_iSubmittedCaption) return;
    final text = _captionController.text.trim();
    if (text.isEmpty) return;
    
    setState(() {
      _iSubmittedCaption = true;
    });
    
    _channel.sendBroadcastMessage(event: 'caption_submitted', payload: {
      'id': _myId,
      'caption': text,
    });
    _onCaptionSubmitted({'id': _myId, 'caption': text});
  }
  
  void _submitVote(String authorId) {
    if (_myVote != null || authorId == _myId) return; // can't vote twice or for self
    
    setState(() {
      _myVote = authorId;
    });
    
    _channel.sendBroadcastMessage(event: 'vote_submitted', payload: {
      'voterId': _myId,
      'authorId': authorId,
    });
    _onVoteSubmitted({'voterId': _myId, 'authorId': authorId});
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _pulseAnim.dispose();
    _channel.unsubscribe();
    super.dispose();
  }
  
  // ================= UI BUILDERS =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GameForgeAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            // Confirmation dialog before leaving?
            context.pop();
          },
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                _phase == 'game_over' ? 'FINAL' : 'RND $_round/5',
                style: GoogleFonts.pressStart2p(fontSize: 10, color: const Color(0xFFF05A28)),
              ),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Timer Bar
            if (_phase != 'loading' && _phase != 'game_over')
              LinearProgressIndicator(
                value: _timeLeft / _maxTime,
                backgroundColor: AppColors.card,
                color: const Color(0xFFF05A28),
                minHeight: 6,
              ),
              
            Expanded(
              child: _buildPhaseView(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPhaseView() {
    if (_opponentLeft) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 24),
              Text(
                'Opponent left! You Win! 🏆',
                textAlign: TextAlign.center,
                style: GoogleFonts.rajdhani(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.amberAccent,
                ),
              ),
              const SizedBox(height: 36),
              ElevatedButton(
                onPressed: () => context.go('/'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  backgroundColor: const Color(0xFFF05A28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text(
                  'EXIT TO LOBBY',
                  style: GoogleFonts.rajdhani(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    switch (_phase) {
      case 'loading':
        return const Center(child: CircularProgressIndicator(color: Color(0xFFF05A28)));
      case 'caption':
        return _buildCaptionPhase();
      case 'voting':
        return _buildVotingPhase();
      case 'results':
        return _buildResultsPhase();
      case 'game_over':
        return _buildGameOverPhase();
      default:
        return const SizedBox();
    }
  }
  
  Widget _buildCaptionPhase() {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 4),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: _buildMemeWithCaption(
                _currentMeme?['url'] ?? '',
                _captionController.text,
                fontSize: 16,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: _iSubmittedCaption
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('😂', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 16),
                      Text(
                        'WAITING FOR OTHERS...',
                        style: GoogleFonts.rajdhani(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Show who submitted
                      Wrap(
                        spacing: 8,
                        children: _players.map((p) {
                          final hasSub = _captions.containsKey(p['id']);
                          final isPresent = _presentIds.contains(p['id']);
                          if (!isPresent) return const SizedBox();
                          return Chip(
                            backgroundColor: hasSub ? const Color(0xFFF05A28) : AppColors.background,
                            label: Text(
                              p['name'],
                              style: TextStyle(color: hasSub ? Colors.white : AppColors.textSecondary),
                            ),
                          );
                        }).toList(),
                      )
                    ],
                  )
                : Column(
                    children: [
                      Text(
                        'Write your funniest caption!',
                        style: GoogleFonts.rajdhani(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _captionController,
                        maxLength: 100,
                        style: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Type here...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (v) => setState(() {}),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _captionController.text.trim().isNotEmpty ? _submitCaption : null,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFFF05A28),
                            disabledBackgroundColor: AppColors.background,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            'SUBMIT CAPTION',
                            style: GoogleFonts.rajdhani(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _captionController.text.trim().isNotEmpty ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildVotingPhase() {
    // Shuffle captions so they are anonymous but consistent? 
    // Actually we can just display them in a list. To be fully fair, we could shuffle.
    final List<MapEntry<String, String>> captionList = _captions.entries.toList();
    // simple sort by caption text to be deterministic across clients
    captionList.sort((a, b) => a.value.compareTo(b.value));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            'VOTE FOR THE BEST!',
            style: GoogleFonts.pressStart2p(fontSize: 16, color: Colors.amberAccent),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: captionList.length,
              itemBuilder: (context, idx) {
                final entry = captionList[idx];
                final authorId = entry.key;
                final text = entry.value;
                final isMine = authorId == _myId;
                final isSelected = _myVote == authorId;
                
                return GestureDetector(
                  onTap: () => _submitVote(authorId),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF05A28).withValues(alpha: 0.2) : const Color(0xFF141418),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFF05A28) : AppColors.border,
                        width: isSelected ? 2.5 : 1,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: const Color(0xFFF05A28).withValues(alpha: 0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ] : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Column(
                        children: [
                          Container(
                            height: 180,
                            width: double.infinity,
                            color: Colors.black,
                            child: _buildMemeWithCaption(
                              _currentMeme?['url'] ?? '',
                              text,
                              fontSize: 10,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isMine ? 'Your Submission' : 'Tap to Vote',
                                    style: GoogleFonts.rajdhani(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isMine ? AppColors.textSecondary : (isSelected ? const Color(0xFFF05A28) : Colors.white),
                                    ),
                                  ),
                                ),
                                if (isMine)
                                  const Icon(Icons.person, color: AppColors.textSecondary, size: 18),
                                if (isSelected)
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFFF05A28)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_myVote != null)
             Text('Waiting for others...', style: GoogleFonts.rajdhani(color: AppColors.textSecondary, fontSize: 18))
        ],
      ),
    );
  }
  
  Widget _buildResultsPhase() {
    // Sort authors by round points
    final sortedAuthors = _roundPoints.keys.toList()..sort((a, b) => _roundPoints[b]!.compareTo(_roundPoints[a]!));
    final winnerAuthorId = sortedAuthors.isNotEmpty ? sortedAuthors.first : null;
    final winningCaption = winnerAuthorId != null ? (_captions[winnerAuthorId] ?? '') : '';
    
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 4),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: _buildMemeWithCaption(
                _currentMeme?['url'] ?? '',
                winningCaption,
                fontSize: 14,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Text(
                  'ROUND $_round RESULTS',
                  style: GoogleFonts.pressStart2p(fontSize: 14, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: sortedAuthors.length,
                    itemBuilder: (context, idx) {
                      final authorId = sortedAuthors[idx];
                      final authorName = _players.firstWhere((p) => p['id'] == authorId, orElse: () => {'name':'Unknown'})['name'];
                      final caption = _captions[authorId] ?? '...';
                      final votes = _roundVoteTally[authorId] ?? 0;
                      final points = _roundPoints[authorId] ?? 0;
                      final isWinner = points == 100;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isWinner ? const Color(0xFFF05A28).withValues(alpha: 0.15) : AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isWinner ? const Color(0xFFF05A28) : AppColors.border,
                            width: isWinner ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              caption,
                              style: GoogleFonts.rajdhani(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'By $authorName',
                                  style: GoogleFonts.inter(color: isWinner ? const Color(0xFFF05A28) : AppColors.textSecondary),
                                ),
                                Row(
                                  children: [
                                    if (votes > 0)
                                      ...List.generate(votes, (i) => const Icon(Icons.star_rounded, color: Colors.amber, size: 16)),
                                    const SizedBox(width: 8),
                                    Text('+$points', style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.greenAccent)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildGameOverPhase() {
    final sortedPlayers = _players.toList()..sort((a, b) => (_scores[b['id']] ?? 0).compareTo(_scores[a['id']] ?? 0));
    final winner = sortedPlayers.isNotEmpty ? sortedPlayers.first : null;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            Text(
              'MEME MASTER',
              style: GoogleFonts.pressStart2p(fontSize: 20, color: Colors.amberAccent),
            ),
            const SizedBox(height: 8),
            Text(
              winner?['name'] ?? 'Unknown',
              style: GoogleFonts.rajdhani(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 48),
            
            // Scoreboard
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: sortedPlayers.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final p = entry.value;
                  final score = _scores[p['id']] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text('#${idx+1}', style: GoogleFonts.pressStart2p(fontSize: 12, color: idx==0 ? Colors.amber : AppColors.textSecondary)),
                            const SizedBox(width: 16),
                            Text(p['name'], style: GoogleFonts.rajdhani(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                        Text('$score PTS', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFFF05A28))),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            
            const Spacer(),
            ElevatedButton(
              onPressed: () => context.go('/multiplayer'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(
                'BACK TO LOBBY',
                style: GoogleFonts.rajdhani(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
