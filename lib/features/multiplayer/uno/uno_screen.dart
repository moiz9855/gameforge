import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/crt_overlay.dart';
import 'package:game_forge/core/services/sound_service.dart';
import 'uno_logic.dart';

class UnoScreen extends StatefulWidget {
  final String roomCode;
  final bool isCreator;
  final int numPlayers;

  const UnoScreen({
    super.key,
    required this.roomCode,
    required this.isCreator,
    required this.numPlayers,
  });

  @override
  State<UnoScreen> createState() => _UnoScreenState();
}

class _UnoScreenState extends State<UnoScreen> {
  RealtimeChannel? _channel;
  
  List<UnoCard> _myHand = [];
  final Map<String, int> _opponentCardCounts = {};
  final List<Map<String, String>> _players = [];

  List<UnoCard> _deck = [];
  List<UnoCard> _discardPile = [];
  
  String _currentTurnId = '';
  int _direction = 1; // 1 = clockwise, -1 = counter-clockwise
  UnoColor? _selectedWildColor;

  bool _calledUno = false;
  bool _gameOver = false;
  bool _opponentLeft = false;
  String _winnerName = '';

  final Map<String, List<UnoCard>> _allHands = {};
  final Set<String> _playersWhoCalledUno = {};

  int _timerValue = 30;
  Timer? _turnTimer;

  String get _myId => Supabase.instance.client.auth.currentUser?.id ?? '';
  String get _myName {
    final email = Supabase.instance.client.auth.currentUser?.email ?? 'Player';
    return email.split('@')[0].toUpperCase();
  }
  bool get _isMyTurn => _myId == _currentTurnId;

  @override
  void initState() {
    super.initState();
    _subscribeAndSetup();
  }

  void _subscribeAndSetup() {
    final client = Supabase.instance.client;
    final ch = client.channel('uno:${widget.roomCode}');
    _channel = ch;

    ch
      .onPresenceSync((_) {
        if (!mounted || _gameOver) return;
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
          });

          if (_players.length == 1 && _currentTurnId.isNotEmpty) {
            setState(() {
              _opponentLeft = true;
              _gameOver = true;
            });
            _turnTimer?.cancel();
            _saveFinalStats(true);
          }
        }
      })
      .onBroadcast(
        event: 'game_state_sync',
        callback: (payload) {
          if (!mounted) return;
          final data = payload['payload'] ?? payload;
          final hands = data['hands'] as Map;
          final deckJson = data['deck'] as List;
          final discardJson = data['discard'] as List;
          final counts = data['opponentCounts'] as Map;

          setState(() {
            _allHands.clear();
            hands.forEach((key, val) {
              final list = (val as List).map((c) => UnoCard.fromJson(Map<String, dynamic>.from(c))).toList();
              _allHands[key as String] = list;
            });

            _myHand = _allHands[_myId] ?? [];
            _deck = deckJson.map((c) => UnoCard.fromJson(Map<String, dynamic>.from(c))).toList();
            _discardPile = discardJson.map((c) => UnoCard.fromJson(Map<String, dynamic>.from(c))).toList();

            counts.forEach((key, val) {
              if (key != _myId) {
                _opponentCardCounts[key as String] = val as int;
              }
            });

            _currentTurnId = data['currentTurn'] as String;
            _direction = data['direction'] as int;
            final wc = data['selectedWildColor'] as int?;
            _selectedWildColor = wc != null ? UnoColor.values[wc] : null;

            // Remove any player whose cards count went above 1 from called UNO list
            _playersWhoCalledUno.removeWhere((id) {
              final count = id == _myId ? _myHand.length : (_opponentCardCounts[id] ?? 0);
              return count > 1;
            });
          });

          _startTurnTimer();
        },
      )
      .onBroadcast(
        event: 'called_uno_broadcast',
        callback: (payload) {
          if (!mounted) return;
          final data = payload['payload'] ?? payload;
          final pId = data['playerId'] as String;
          setState(() {
            _playersWhoCalledUno.add(pId);
          });
        },
      )
      .onBroadcast(
        event: 'action_uno_catch',
        callback: (payload) {
          if (!mounted) return;
          final data = payload['payload'] ?? payload;
          final targetId = data['targetId'] as String;
          final cards = (data['cards'] as List).map((c) => UnoCard.fromJson(Map<String, dynamic>.from(c))).toList();

          if (targetId == _myId) {
            setState(() {
              _myHand.addAll(cards);
              _allHands[_myId] = _myHand;
            });
            SoundService.instance.play(SoundType.error);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('⚠️ Caught forgetting UNO! +2 Cards penalty!')),
            );
          } else {
            setState(() {
              _opponentCardCounts[targetId] = (_opponentCardCounts[targetId] ?? 0) + 2;
              if (_allHands.containsKey(targetId)) {
                _allHands[targetId]!.addAll(cards);
              }
            });
          }
        },
      )
      .onBroadcast(
        event: 'game_over',
        callback: (payload) {
          if (!mounted) return;
          final data = payload['payload'] ?? payload;
          setState(() {
            _gameOver = true;
            _winnerName = data['winnerName'] as String;
          });
          _turnTimer?.cancel();
          _saveFinalStats(_winnerName == _myName);
        },
      )
      .subscribe((status, [err]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await ch.track({
            'id': _myId,
            'name': _myName,
          });
          if (widget.isCreator) {
            Timer(const Duration(seconds: 1), () => _initDeckAndDeal());
          }
        }
      });
  }

  void _initDeckAndDeal() {
    if (_players.isEmpty) return;

    final deck = generateUnoDeck();
    final hands = <String, List<Map<String, dynamic>>>{};
    final opponentCounts = <String, int>{};
    _allHands.clear();
    _playersWhoCalledUno.clear();

    for (var p in _players) {
      final hand = <UnoCard>[];
      for (int i = 0; i < 7; i++) {
        hand.add(deck.removeLast());
      }
      _allHands[p['id']!] = hand;
      hands[p['id']!] = hand.map((c) => c.toJson()).toList();
      opponentCounts[p['id']!] = 7;
    }

    // Discard pile first card (must not be wild)
    UnoCard firstCard = deck.removeLast();
    while (firstCard.color == UnoColor.wild) {
      deck.insert(0, firstCard);
      firstCard = deck.removeLast();
    }
    
    final discardPile = [firstCard];

    _channel?.sendBroadcastMessage(
      event: 'game_state_sync',
      payload: {
        'hands': hands,
        'deck': deck.map((c) => c.toJson()).toList(),
        'discard': discardPile.map((c) => c.toJson()).toList(),
        'opponentCounts': opponentCounts,
        'currentTurn': _players[0]['id']!,
        'direction': 1,
        'selectedWildColor': null,
      },
    );

    // Save initial state to Supabase uno_rooms
    _updateDbState(hands, deck, discardPile, _players[0]['id']!, 1, null);
  }

  Future<void> _updateDbState(
    Map<String, List<Map<String, dynamic>>> hands,
    List<UnoCard> deck,
    List<UnoCard> discard,
    String turn,
    int dir,
    int? wildIdx,
  ) async {
    try {
      final client = Supabase.instance.client;
      await client.from('uno_rooms').update({
        'hands': hands,
        'deck': deck.map((c) => c.toJson()).toList(),
        'discard_pile': discard.map((c) => c.toJson()).toList(),
        'current_turn': turn,
        'direction': dir,
      }).eq('room_code', widget.roomCode);
    } catch (_) {}
  }

  void _startTurnTimer() {
    _turnTimer?.cancel();
    setState(() {
      _timerValue = 30;
    });

    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timerValue > 1) {
          _timerValue--;
        } else {
          _turnTimer?.cancel();
          if (_isMyTurn) {
            _drawCard();
          }
        }
      });
    });
  }

  void _syncCurrentState() {
    final hands = <String, List<Map<String, dynamic>>>{};
    final opponentCounts = <String, int>{};

    _allHands.forEach((key, val) {
      hands[key] = val.map((c) => c.toJson()).toList();
      opponentCounts[key] = val.length;
    });

    _channel?.sendBroadcastMessage(
      event: 'game_state_sync',
      payload: {
        'hands': hands,
        'deck': _deck.map((c) => c.toJson()).toList(),
        'discard': _discardPile.map((c) => c.toJson()).toList(),
        'opponentCounts': opponentCounts,
        'currentTurn': _currentTurnId,
        'direction': _direction,
        'selectedWildColor': _selectedWildColor?.index,
      },
    );

    _updateDbState(hands, _deck, _discardPile, _currentTurnId, _direction, _selectedWildColor?.index);
  }

  void _playCard(UnoCard card) async {
    if (!_isMyTurn || _gameOver) return;
    
    final topCard = _discardPile.last;
    if (!card.isValidPlay(topCard, _selectedWildColor)) {
      SoundService.instance.play(SoundType.error);
      return;
    }

    UnoColor? finalWildColor;
    if (card.color == UnoColor.wild) {
      finalWildColor = await _showColorPickerDialog();
      if (finalWildColor == null) return; // cancelled
    }

    SoundService.instance.play(SoundType.coin);
    setState(() {
      _myHand.remove(card);
      _allHands[_myId] = _myHand;
      _discardPile.add(card);
      _selectedWildColor = finalWildColor;
      if (_myHand.length != 1) {
        _calledUno = false;
        _playersWhoCalledUno.remove(_myId);
      }
    });

    // Evaluate Win
    if (_myHand.isEmpty) {
      _channel?.sendBroadcastMessage(
        event: 'game_over',
        payload: {'winnerName': _myName},
      );
      setState(() {
        _gameOver = true;
        _winnerName = _myName;
      });
      _saveFinalStats(true);
      return;
    }

    _advanceTurn(card);
  }

  void _drawCard() {
    if (!_isMyTurn || _gameOver) return;

    if (_deck.isEmpty) {
      // Re-shuffle discard pile
      final top = _discardPile.removeLast();
      _deck = List.from(_discardPile)..shuffle();
      _discardPile = [top];
    }

    final drawn = _deck.removeLast();
    setState(() {
      _myHand.add(drawn);
      _allHands[_myId] = _myHand;
    });

    SoundService.instance.play(SoundType.snakeMove);

    _advanceTurn(null);
  }

  void _advanceTurn(UnoCard? playedCard) {
    int skipCount = 1;
    if (playedCard != null) {
      if (playedCard.type == UnoType.skip) skipCount = 2;
      if (playedCard.type == UnoType.reverse) {
        if (_players.length == 2) {
          skipCount = 2;
        } else {
          _direction = -_direction;
        }
      }
    }

    // Find next player index
    final myIdx = _players.indexWhere((p) => p['id'] == _myId);
    int nextIdx = (myIdx + (_direction * skipCount)) % _players.length;
    if (nextIdx < 0) nextIdx += _players.length;

    final nextPlayerId = _players[nextIdx]['id']!;

    if (playedCard != null) {
      if (playedCard.type == UnoType.drawTwo) {
        // Draw 2 for next player
        final drawList = <UnoCard>[];
        for (int i = 0; i < 2; i++) {
          if (_deck.isNotEmpty) drawList.add(_deck.removeLast());
        }
        _allHands[nextPlayerId] = [...(_allHands[nextPlayerId] ?? []), ...drawList];
        _channel?.sendBroadcastMessage(
          event: 'action_uno_catch',
          payload: {
            'targetId': nextPlayerId,
            'cards': drawList.map((c) => c.toJson()).toList(),
          },
        );
      } else if (playedCard.type == UnoType.wildDrawFour) {
        // Draw 4 for next player
        final drawList = <UnoCard>[];
        for (int i = 0; i < 4; i++) {
          if (_deck.isNotEmpty) drawList.add(_deck.removeLast());
        }
        _allHands[nextPlayerId] = [...(_allHands[nextPlayerId] ?? []), ...drawList];
        _channel?.sendBroadcastMessage(
          event: 'action_uno_catch',
          payload: {
            'targetId': nextPlayerId,
            'cards': drawList.map((c) => c.toJson()).toList(),
          },
        );
      }
    }

    _currentTurnId = nextPlayerId;
    _syncCurrentState();
  }

  void _callUno() {
    if (_myHand.length != 1 || _calledUno) return;
    setState(() {
      _calledUno = true;
      _playersWhoCalledUno.add(_myId);
    });
    _channel?.sendBroadcastMessage(
      event: 'called_uno_broadcast',
      payload: {
        'playerId': _myId,
      },
    );
    SoundService.instance.play(SoundType.winFanfare);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🎉 YOU CALLED UNO!')),
    );
  }

  void _catchOpponent() {
    // Find if any opponent has 1 card left and hasn't called UNO
    for (var entry in _opponentCardCounts.entries) {
      if (entry.value == 1 && !_playersWhoCalledUno.contains(entry.key)) {
        final catchCards = <UnoCard>[];
        for (int i = 0; i < 2; i++) {
          if (_deck.isNotEmpty) catchCards.add(_deck.removeLast());
        }
        _allHands[entry.key] = [...(_allHands[entry.key] ?? []), ...catchCards];
        
        _channel?.sendBroadcastMessage(
          event: 'action_uno_catch',
          payload: {
            'targetId': entry.key,
            'cards': catchCards.map((c) => c.toJson()).toList(),
          },
        );
        SoundService.instance.play(SoundType.winFanfare);
        
        _syncCurrentState();
        return;
      }
    }
  }

  Future<UnoColor?> _showColorPickerDialog() async {
    return showDialog<UnoColor>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D1117),
          title: Text(
            'CHOOSE COLOR',
            style: GoogleFonts.pressStart2p(fontSize: 12, color: Colors.white),
          ),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _colorPickBtn(context, Colors.red, UnoColor.red),
              _colorPickBtn(context, Colors.yellow, UnoColor.yellow),
              _colorPickBtn(context, Colors.green, UnoColor.green),
              _colorPickBtn(context, Colors.blue, UnoColor.blue),
            ],
          ),
        );
      },
    );
  }

  Widget _colorPickBtn(BuildContext context, Color color, UnoColor val) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(45, 45),
        shape: const CircleBorder(),
      ),
      onPressed: () {
        SoundService.instance.play(SoundType.buttonTap);
        Navigator.pop(context, val);
      },
      child: const SizedBox(),
    );
  }

  Future<void> _saveFinalStats(bool won) async {
    try {
      final client = Supabase.instance.client;
      await client.from('user_game_progress').insert({
        'user_id': _myId,
        'game_id': 'uno',
        'score': won ? 500 : 100,
        'completed': true,
        'won': won,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _turnTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_discardPile.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final topCard = _discardPile.last;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CrtOverlay(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  _buildTimerBar(),
                  const Spacer(),
                  _buildOpponentsHands(),
                  const Spacer(),
                  _buildDiscardPileSection(topCard),
                  const Spacer(),
                  _buildPlayerHandSection(),
                ],
              ),
              if (_opponentLeft) _buildOpponentLeftOverlay(),
              if (_gameOver) _buildGameOverOverlay(),
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
            'GAMEFORGE UNO',
            style: GoogleFonts.pressStart2p(fontSize: 10, color: AppColors.primary),
          ),
          IconButton(
            icon: const Icon(Icons.flash_on_rounded, color: AppColors.gold),
            onPressed: _catchOpponent,
            tooltip: 'Catch opponent forgetting UNO!',
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBar() {
    final progress = _timerValue / 30.0;
    return Container(
      width: double.infinity,
      height: 6,
      color: Colors.white10,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: progress,
        child: Container(
          color: _timerValue > 8 ? AppColors.primary : AppColors.error,
        ),
      ),
    );
  }

  Widget _buildOpponentsHands() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _opponentCardCounts.entries.map((opp) {
        final name = _players.firstWhere((p) => p['id'] == opp.key, orElse: () => {'name': 'Opponent'})['name']!;
        final isActive = opp.key == _currentTurnId;
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? AppColors.primary : Colors.transparent,
                  width: 2.0,
                ),
              ),
              child: const Text('👤', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.bold,
                color: isActive ? AppColors.primary : Colors.white70,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${opp.value} CARDS',
              style: GoogleFonts.pressStart2p(fontSize: 6, color: Colors.white30),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDiscardPileSection(UnoCard topCard) {
    Color cardColor = Colors.grey;
    if (topCard.color == UnoColor.red) cardColor = Colors.red;
    if (topCard.color == UnoColor.yellow) cardColor = Colors.yellow.shade700;
    if (topCard.color == UnoColor.green) cardColor = Colors.green;
    if (topCard.color == UnoColor.blue) cardColor = Colors.blue;

    if (topCard.color == UnoColor.wild && _selectedWildColor != null) {
      if (_selectedWildColor == UnoColor.red) cardColor = Colors.red;
      if (_selectedWildColor == UnoColor.yellow) cardColor = Colors.yellow.shade700;
      if (_selectedWildColor == UnoColor.green) cardColor = Colors.green;
      if (_selectedWildColor == UnoColor.blue) cardColor = Colors.blue;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Draw Pile
        GestureDetector(
          onTap: _drawCard,
          child: Container(
            width: 80,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _isMyTurn ? AppColors.primary : Colors.white24, width: 2),
              boxShadow: _isMyTurn
                  ? [
                      BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 1),
                    ]
                  : [],
            ),
            child: Center(
              child: Text(
                'DRAW',
                style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white60),
              ),
            ),
          ),
        ),
        const SizedBox(width: 28),
        // Discard Pile
        Container(
          width: 80,
          height: 120,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(color: cardColor.withValues(alpha: 0.4), blurRadius: 12),
            ],
          ),
          child: Center(
            child: Text(
              topCard.label,
              style: GoogleFonts.pressStart2p(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerHandSection() {
    final topCard = _discardPile.last;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: const Color(0x40000000),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isMyTurn ? '👉 YOUR TURN' : 'WAITING FOR TURN...',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 8,
                    color: _isMyTurn ? AppColors.primary : Colors.white30,
                  ),
                ),
                if (_myHand.length == 1)
                  ElevatedButton(
                    onPressed: _callUno,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                    child: Text('UNO!', style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _myHand.length,
              itemBuilder: (context, index) {
                final card = _myHand[index];
                final isValid = card.isValidPlay(topCard, _selectedWildColor);
                final canPlay = _isMyTurn && isValid;

                Color cardColor = Colors.grey;
                if (card.color == UnoColor.red) cardColor = Colors.red;
                if (card.color == UnoColor.yellow) cardColor = Colors.yellow.shade700;
                if (card.color == UnoColor.green) cardColor = Colors.green;
                if (card.color == UnoColor.blue) cardColor = Colors.blue;

                return GestureDetector(
                  onTap: () => _playCard(card),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 75,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: canPlay ? cardColor : cardColor.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: canPlay ? const Color(0xFFF05A28) : Colors.white12,
                        width: canPlay ? 3.0 : 1,
                      ),
                      boxShadow: canPlay
                          ? [
                              BoxShadow(
                                color: const Color(0xFFF05A28).withValues(alpha: 0.8),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        card.label,
                        style: GoogleFonts.pressStart2p(
                          fontSize: 13,
                          color: canPlay ? Colors.white : Colors.white30,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildGameOverOverlay() {
    final won = _winnerName == _myName;
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: won ? AppColors.gold : AppColors.error, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(won ? '🏆' : '😢', style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                won ? 'YOU WIN! 🎉' : 'GAME OVER',
                style: GoogleFonts.pressStart2p(
                  fontSize: 11,
                  color: won ? AppColors.gold : AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Winner: $_winnerName',
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
                style: ElevatedButton.styleFrom(backgroundColor: won ? AppColors.gold : AppColors.error),
                child: Text('BACK TO MENU', style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
