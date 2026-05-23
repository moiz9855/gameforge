import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/crt_overlay.dart';
import 'package:game_forge/core/services/sound_service.dart';
import 'package:game_forge/core/services/achievement_service.dart';

enum Location { leftBank, boat, rightBank }
enum Entity { farmer, wolf, goat, cabbage }

class IqPuzzleScreen extends StatefulWidget {
  const IqPuzzleScreen({super.key});

  @override
  State<IqPuzzleScreen> createState() => _IqPuzzleScreenState();
}

class _IqPuzzleScreenState extends State<IqPuzzleScreen> with SingleTickerProviderStateMixin {
  int _moves = 0;
  int _bestMoves = 0;
  bool _gameOver = false;
  bool _won = false;
  String _message = "GET EVERYONE ACROSS";

  Map<Entity, Location> _locations = {
    Entity.farmer: Location.leftBank,
    Entity.wolf: Location.leftBank,
    Entity.goat: Location.leftBank,
    Entity.cabbage: Location.leftBank,
  };

  Location _boatLocation = Location.leftBank;

  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadBest();
  }

  Future<void> _loadBest() async {
    final hs = await AchievementService.instance.getHighScore('iq_puzzle');
    if (mounted) {
      setState(() {
        _bestMoves = hs;
      });
    }
  }

  void _reset() {
    setState(() {
      _moves = 0;
      _gameOver = false;
      _won = false;
      _message = "GET EVERYONE ACROSS";
      _boatLocation = Location.leftBank;
      _locations = {
        Entity.farmer: Location.leftBank,
        Entity.wolf: Location.leftBank,
        Entity.goat: Location.leftBank,
        Entity.cabbage: Location.leftBank,
      };
    });
  }

  void _shakeError(String msg) {
    SoundService.instance.play(SoundType.error);
    HapticFeedback.heavyImpact();
    setState(() => _message = msg);
    _shakeController.forward(from: 0);
  }

  void _moveEntity(Entity entity) {
    if (_gameOver) return;

    setState(() {
      final loc = _locations[entity]!;
      
      if (loc == Location.boat) {
        // Unload to current bank
        _locations[entity] = _boatLocation;
        SoundService.instance.play(SoundType.snakeMove);
      } else if (loc == _boatLocation) {
        // Load onto boat
        final inBoat = _locations.values.where((l) => l == Location.boat).length;
        if (inBoat >= 2) {
          _shakeError("BOAT IS FULL!");
          return;
        }
        if (entity != Entity.farmer && !_locations.values.contains(Location.boat) && _locations[Entity.farmer] != _boatLocation) {
           _shakeError("ONLY FARMER CAN ROW!");
           return;
        }
        _locations[entity] = Location.boat;
        SoundService.instance.play(SoundType.snakeMove);
      } else {
        _shakeError("NOT ON THIS BANK!");
      }
    });
  }

  void _rowBoat() {
    if (_gameOver) return;

    if (_locations[Entity.farmer] != Location.boat) {
      _shakeError("FARMER MUST BE IN BOAT TO ROW!");
      return;
    }

    setState(() {
      _moves++;
      _boatLocation = _boatLocation == Location.leftBank ? Location.rightBank : Location.leftBank;
      SoundService.instance.play(SoundType.runnerStep);
      _checkRules();
    });
  }

  void _checkRules() {
    final left = _locations.entries.where((e) => e.value == Location.leftBank).map((e) => e.key).toList();
    final right = _locations.entries.where((e) => e.value == Location.rightBank).map((e) => e.key).toList();

    bool checkBank(List<Entity> bank, String bankName) {
      if (!bank.contains(Entity.farmer)) {
        if (bank.contains(Entity.wolf) && bank.contains(Entity.goat)) {
          _gameOver = true;
          _shakeError("WOLF ATE THE GOAT!");
          return false;
        }
        if (bank.contains(Entity.goat) && bank.contains(Entity.cabbage)) {
          _gameOver = true;
          _shakeError("GOAT ATE THE CABBAGE!");
          return false;
        }
      }
      return true;
    }

    if (!checkBank(left, "LEFT")) return;
    if (!checkBank(right, "RIGHT")) return;

    if (right.length == 4) {
      _won = true;
      _gameOver = true;
      _message = "PUZZLE SOLVED!";
      SoundService.instance.play(SoundType.winFanfare);
      
      if (_bestMoves == 0 || _moves < _bestMoves) {
        _bestMoves = _moves;
        AchievementService.instance.saveHighScore('iq_puzzle', _moves);
      }
    }
  }

  Widget _buildEntity(Entity entity) {
    String emoji = "👨‍🌾";
    if (entity == Entity.wolf) emoji = "🐺";
    if (entity == Entity.goat) emoji = "🐐";
    if (entity == Entity.cabbage) emoji = "🥬";

    return GestureDetector(
      onTap: () => _moveEntity(entity),
      child: Container(
        width: 50,
        height: 50,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A24),
          border: Border.all(color: const Color(0xFFF05A28), width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
      ),
    );
  }

  Widget _buildBank(Location bankLoc, String title) {
    final entities = _locations.entries.where((e) => e.value == bankLoc).map((e) => e.key).toList();
    
    return Container(
      width: 100,
      height: double.infinity,
      color: const Color(0xFF0D1117),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            width: double.infinity,
            color: const Color(0xFF1A1A24),
            child: Text(title, textAlign: TextAlign.center, style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white70)),
          ),
          Expanded(
            child: Center(
              child: Wrap(
                children: entities.map((e) => _buildEntity(e)).toList(),
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CrtOverlay(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('MOVES: $_moves', style: GoogleFonts.pressStart2p(fontSize: 12, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('BEST: ${_bestMoves > 0 ? _bestMoves : '-'}', style: GoogleFonts.pressStart2p(fontSize: 8, color: AppColors.gold)),
                      ],
                    ),
                  ],
                ),
              ),

              // Game Area
              Expanded(
                child: AnimatedBuilder(
                  animation: _shakeController,
                  builder: (context, child) {
                    final dx = (_shakeController.value > 0 && _shakeController.value < 1) 
                        ? 10 * (1 - _shakeController.value) * ((_shakeController.value * 10).floor() % 2 == 0 ? 1 : -1) 
                        : 0.0;
                    return Transform.translate(
                      offset: Offset(dx, 0),
                      child: child,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Row(
                      children: [
                        _buildBank(Location.leftBank, "LEFT BANK"),
                        Expanded(
                          child: Stack(
                            children: [
                              // River
                              Container(
                                width: double.infinity,
                                height: double.infinity,
                                color: Colors.blue.shade900.withValues(alpha: 0.3),
                              ),
                              // Boat
                              AnimatedAlign(
                                duration: const Duration(seconds: 1),
                                curve: Curves.easeInOutCubic,
                                alignment: _boatLocation == Location.leftBank ? Alignment.centerLeft : Alignment.centerRight,
                                child: Container(
                                  width: 140,
                                  height: 120,
                                  margin: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.brown.shade800,
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
                                    border: Border.all(color: Colors.brown.shade600, width: 4),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Wrap(
                                        children: _locations.entries.where((e) => e.value == Location.boat).map((e) => _buildEntity(e.key)).toList(),
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton(
                                        onPressed: _rowBoat,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFF05A28),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          minimumSize: Size.zero,
                                        ),
                                        child: Text('ROW', style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildBank(Location.rightBank, "RIGHT BANK"),
                      ],
                    ),
                  ),
                ),
              ),

              // Footer Message
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                color: _gameOver ? (_won ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2)) : Colors.transparent,
                child: Column(
                  children: [
                    Text(_message, textAlign: TextAlign.center, style: GoogleFonts.pressStart2p(
                      fontSize: 12, 
                      color: _gameOver ? (_won ? Colors.green : Colors.red) : Colors.white,
                      height: 1.5,
                    )),
                    if (_gameOver) ...[
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _reset,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF05A28)),
                        child: Text('PLAY AGAIN', style: GoogleFonts.pressStart2p(fontSize: 12, color: Colors.white)),
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
