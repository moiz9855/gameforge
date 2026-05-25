import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/crt_overlay.dart';
import 'package:game_forge/core/services/sound_service.dart';
import 'package:game_forge/core/services/achievement_service.dart';

enum Location { leftBank, boat, rightBank }
enum Entity { farmer, wolf, goat, cabbage }

class PuzzleLevel {
  final int number;
  final String farmerName;
  final String farmerEmoji;
  final String wolfName;
  final String wolfEmoji;
  final String goatName;
  final String goatEmoji;
  final String cabbageName;
  final String cabbageEmoji;

  PuzzleLevel({
    required this.number,
    required this.farmerName,
    required this.farmerEmoji,
    required this.wolfName,
    required this.wolfEmoji,
    required this.goatName,
    required this.goatEmoji,
    required this.cabbageName,
    required this.cabbageEmoji,
  });
}

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
  int _level = 1;
  String _message = "GET EVERYONE ACROSS";

  Map<Entity, Location> _locations = {
    Entity.farmer: Location.leftBank,
    Entity.wolf: Location.leftBank,
    Entity.goat: Location.leftBank,
    Entity.cabbage: Location.leftBank,
  };

  Location _boatLocation = Location.leftBank;

  late AnimationController _shakeController;
  final List<PuzzleLevel> _levels = [];

  // Hint highlights
  Entity? _highlightedEntity;
  bool _highlightRowButton = false;
  String _hintMessage = "";

  // Conflict warning
  bool _showConflict = false;
  String _conflictDetails = "";

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _generateLevels();
    _loadBest();
  }

  void _generateLevels() {
    final farmers = [
      ('Farmer', '👨‍🌾'), ('Shepherd', '🧑‍🌾'), ('Zookeeper', '🧑‍⚕️'), ('Hunter', '🤠'),
      ('Explorer', '🤠'), ('Grounded Kid', '👦'), ('Ranger', '🧑‍✈️'), ('Gardener', '🧑‍🌾')
    ];
    final predators = [
      ('Wolf', '🐺'), ('Fox', '🦊'), ('Lion', '🦁'), ('Panther', '🐆'),
      ('Coyote', '🐺'), ('Cat', '🐱'), ('Hawk', '🦅'), ('Tiger', '🐯')
    ];
    final preys = [
      ('Goat', '🐐'), ('Goose', '🪿'), ('Zebra', '🦓'), ('Deer', '🦌'),
      ('Rabbit', '🐰'), ('Fish', '🐟'), ('Squirrel', '🐿️'), ('Sheep', '🐑')
    ];
    final foods = [
      ('Cabbage', '🥬'), ('Grain', '🌾'), ('Grass', '🌿'), ('Leaves', '🍂'),
      ('Carrot', '🥕'), ('Worm', '🪱'), ('Acorn', '🌰'), ('Hay', '🌾')
    ];

    for (int i = 0; i < 50; i++) {
      final f = farmers[i % farmers.length];
      final p = predators[i % predators.length];
      final pr = preys[i % preys.length];
      final fo = foods[i % foods.length];
      _levels.add(PuzzleLevel(
        number: i + 1,
        farmerName: f.$1, farmerEmoji: f.$2,
        wolfName: p.$1, wolfEmoji: p.$2,
        goatName: pr.$1, goatEmoji: pr.$2,
        cabbageName: fo.$1, cabbageEmoji: fo.$2,
      ));
    }
  }

  Future<void> _loadBest() async {
    final hs = await AchievementService.instance.getHighScore('iq_puzzle');
    final prefs = await SharedPreferences.getInstance();
    final savedLevel = prefs.getInt('iq_puzzle_level') ?? 1;
    if (mounted) {
      setState(() {
        _bestMoves = hs;
        _level = savedLevel.clamp(1, 50);
      });
    }
  }

  void _reset() {
    setState(() {
      _moves = 0;
      _gameOver = false;
      _won = false;
      _showConflict = false;
      _message = "GET EVERYONE ACROSS";
      _boatLocation = Location.leftBank;
      _locations = {
        Entity.farmer: Location.leftBank,
        Entity.wolf: Location.leftBank,
        Entity.goat: Location.leftBank,
        Entity.cabbage: Location.leftBank,
      };
      _hintMessage = "";
      _highlightedEntity = null;
      _highlightRowButton = false;
    });
  }

  void _shakeError(String msg) {
    SoundService.instance.play(SoundType.error);
    HapticFeedback.heavyImpact();
    setState(() => _message = msg);
    _shakeController.forward(from: 0);
  }

  void _showConflictWarning(String details) {
    SoundService.instance.play(SoundType.error);
    HapticFeedback.heavyImpact();
    setState(() {
      _showConflict = true;
      _conflictDetails = details;
      _gameOver = true;
      _message = "CONFLICT! GAME OVER";
    });
    _shakeController.forward(from: 0);
  }

  String _entityName(Entity entity) {
    final lvl = _levels[_level - 1];
    switch (entity) {
      case Entity.farmer: return lvl.farmerName;
      case Entity.wolf: return lvl.wolfName;
      case Entity.goat: return lvl.goatName;
      case Entity.cabbage: return lvl.cabbageName;
    }
  }

  String _entityEmoji(Entity entity) {
    final lvl = _levels[_level - 1];
    switch (entity) {
      case Entity.farmer: return lvl.farmerEmoji;
      case Entity.wolf: return lvl.wolfEmoji;
      case Entity.goat: return lvl.goatEmoji;
      case Entity.cabbage: return lvl.cabbageEmoji;
    }
  }

  void _moveEntity(Entity entity) {
    if (_gameOver) return;

    setState(() {
      final loc = _locations[entity]!;
      
      if (loc == Location.boat) {
        _locations[entity] = _boatLocation;
        SoundService.instance.play(SoundType.snakeMove);
      } else if (loc == _boatLocation) {
        final inBoat = _locations.values.where((l) => l == Location.boat).length;
        if (inBoat >= 2) {
          _shakeError("BOAT IS FULL!");
          return;
        }
        if (entity != Entity.farmer && !_locations.values.contains(Location.boat) && _locations[Entity.farmer] != _boatLocation) {
           _shakeError("ONLY ${_entityName(Entity.farmer).toUpperCase()} CAN ROW!");
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
      _shakeError("${_entityName(Entity.farmer).toUpperCase()} MUST BE IN BOAT TO ROW!");
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

    bool checkBank(List<Entity> bank) {
      if (!bank.contains(Entity.farmer)) {
        if (bank.contains(Entity.wolf) && bank.contains(Entity.goat)) {
          _showConflictWarning("${_entityName(Entity.wolf).toUpperCase()} ATE THE ${_entityName(Entity.goat).toUpperCase()}!");
          return false;
        }
        if (bank.contains(Entity.goat) && bank.contains(Entity.cabbage)) {
          _showConflictWarning("${_entityName(Entity.goat).toUpperCase()} ATE THE ${_entityName(Entity.cabbage).toUpperCase()}!");
          return false;
        }
      }
      return true;
    }

    if (!checkBank(left)) return;
    if (!checkBank(right)) return;

    if (right.length == 4) {
      _won = true;
      _gameOver = true;
      _message = "PUZZLE SOLVED!";
      SoundService.instance.play(SoundType.winFanfare);
      
      if (_bestMoves == 0 || _moves < _bestMoves) {
        _bestMoves = _moves;
        AchievementService.instance.saveHighScore('iq_puzzle', _moves);
      }

      _advanceLevel();
    }
  }

  Future<void> _advanceLevel() async {
    final prefs = await SharedPreferences.getInstance();
    if (_level < 50) {
      await prefs.setInt('iq_puzzle_level', _level + 1);
    }
  }

  void _nextLevel() {
    setState(() {
      _level = min(50, _level + 1);
      _reset();
    });
  }

  // BFS Solver for precise hints
  void _getHint() {
    if (_gameOver) return;
    final hint = _solveBFS();
    setState(() {
      _hintMessage = hint.message;
      _highlightedEntity = hint.entity;
      _highlightRowButton = hint.row;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _highlightedEntity = null;
          _highlightRowButton = false;
        });
      }
    });
  }

  HintResult _solveBFS() {
    final startState = GameState(Map.from(_locations), _boatLocation);
    if (startState.isGoal) return HintResult("ALREADY SOLVED!");

    final queue = <BFSNode>[BFSNode(startState)];
    final visited = <String>{startState.serialize()};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);

      if (current.state.isGoal) {
        BFSNode pathNode = current;
        while (pathNode.parent != null && pathNode.parent!.parent != null) {
          pathNode = pathNode.parent!;
        }
        return pathNode.action!;
      }

      // Transitions
      for (var entity in Entity.values) {
        final loc = current.state.locations[entity]!;
        if (loc == Location.boat) {
          final nextLocations = Map<Entity, Location>.from(current.state.locations);
          nextLocations[entity] = current.state.boatLocation;
          final nextState = GameState(nextLocations, current.state.boatLocation);
          if (nextState.isValid && !visited.contains(nextState.serialize())) {
            visited.add(nextState.serialize());
            queue.add(BFSNode(nextState, parent: current, action: HintResult("UNLOAD ${_entityName(entity).toUpperCase()}", entity: entity)));
          }
        } else if (loc == current.state.boatLocation) {
          final inBoat = current.state.locations.values.where((l) => l == Location.boat).length;
          if (inBoat < 2) {
            final nextLocations = Map<Entity, Location>.from(current.state.locations);
            nextLocations[entity] = Location.boat;
            final nextState = GameState(nextLocations, current.state.boatLocation);
            if (nextState.isValid && !visited.contains(nextState.serialize())) {
              visited.add(nextState.serialize());
              queue.add(BFSNode(nextState, parent: current, action: HintResult("LOAD ${_entityName(entity).toUpperCase()}", entity: entity)));
            }
          }
        }
      }

      if (current.state.locations[Entity.farmer] == Location.boat) {
        final nextBoatLoc = current.state.boatLocation == Location.leftBank ? Location.rightBank : Location.leftBank;
        final nextState = GameState(current.state.locations, nextBoatLoc);
        if (nextState.isValid && !visited.contains(nextState.serialize())) {
          visited.add(nextState.serialize());
          queue.add(BFSNode(nextState, parent: current, action: HintResult("ROW BOAT ACROSS", row: true)));
        }
      }
    }

    return HintResult("RESET AND TRY AGAIN!");
  }

  Widget _buildEntity(Entity entity) {
    final emoji = _entityEmoji(entity);
    final isHighlighted = _highlightedEntity == entity;

    return GestureDetector(
      onTap: () => _moveEntity(entity),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 50,
        height: 50,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A24),
          border: Border.all(
            color: isHighlighted ? AppColors.gold : const Color(0xFFF05A28),
            width: isHighlighted ? 3 : 2,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
      ),
    );
  }

  Widget _buildBank(Location bankLoc, String title) {
    final entities = _locations.entries.where((e) => e.value == bankLoc).map((e) => e.key).toList();
    
    return Container(
      width: 110,
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Wrap(
                  key: ValueKey('${entities.length}-$bankLoc'),
                  children: entities.map((e) => _buildEntity(e)).toList(),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildConflictOverlay() {
    return Container(
      color: Colors.red.withValues(alpha: 0.4),
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.2),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                'THEY WILL FIGHT!',
                style: GoogleFonts.pressStart2p(
                  fontSize: 10,
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _conflictDetails,
                textAlign: TextAlign.center,
                style: GoogleFonts.rajdhani(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _reset,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: Text('RETRY PUZZLE', style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteOverlay() {
    final stars = _moves <= 7 ? 3 : (_moves <= 9 ? 2 : 1);
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'PUZZLE $_level COMPLETED! 🎉',
                style: GoogleFonts.pressStart2p(
                  fontSize: 12,
                  color: const Color(0xFFF05A28),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              // Stars
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  final filled = index < stars;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      filled ? '⭐' : '☆',
                      style: TextStyle(
                        fontSize: 48,
                        color: filled ? AppColors.gold : Colors.white24,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF05A28).withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    Text('TOTAL MOVES', style: GoogleFonts.shareTechMono(fontSize: 12, color: AppColors.textSecondary, letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Text('$_moves', style: GoogleFonts.pressStart2p(fontSize: 24, color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: 220,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    SoundService.instance.play(SoundType.gameStart);
                    _nextLevel();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF05A28)),
                  child: Text('NEXT PUZZLE', style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 220,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    SoundService.instance.play(SoundType.buttonBack);
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.border)),
                  child: Text('BACK TO ARCADE', style: GoogleFonts.pressStart2p(fontSize: 9, color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_levels.isEmpty) return const Scaffold(backgroundColor: AppColors.background);


    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CrtOverlay(
          child: Stack(
            children: [
              Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          onPressed: () {
                            SoundService.instance.play(SoundType.buttonBack);
                            Navigator.pop(context);
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PUZZLE $_level/50',
                          style: GoogleFonts.pressStart2p(fontSize: 11, color: Colors.white),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('MOVES: $_moves', style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white)),
                            const SizedBox(height: 4),
                            Text('BEST: ${_bestMoves > 0 ? _bestMoves : '-'}', style: GoogleFonts.pressStart2p(fontSize: 7, color: AppColors.gold)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Hint Message Banner
                  if (_hintMessage.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        border: Border.all(color: AppColors.gold, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '💡 HINT: $_hintMessage',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.pressStart2p(fontSize: 7, color: Colors.yellow, height: 1.4),
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
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
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
                                    color: Colors.blue.shade900.withValues(alpha: 0.2),
                                    child: Center(
                                      child: Text(
                                        '〰️〰️〰️ R I V E R 〰️〰️〰️',
                                        style: GoogleFonts.pressStart2p(fontSize: 6, color: Colors.white10),
                                      ),
                                    ),
                                  ),
                                  // Boat
                                  AnimatedAlign(
                                    duration: const Duration(milliseconds: 800),
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
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.4),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                          )
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Wrap(
                                            children: _locations.entries.where((e) => e.value == Location.boat).map((e) => _buildEntity(e.key)).toList(),
                                          ),
                                          const SizedBox(height: 8),
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(6),
                                              boxShadow: _highlightRowButton
                                                  ? [
                                                      BoxShadow(
                                                        color: AppColors.gold.withValues(alpha: 0.6),
                                                        blurRadius: 10,
                                                        spreadRadius: 2,
                                                      )
                                                    ]
                                                  : [],
                                            ),
                                            child: ElevatedButton(
                                              onPressed: _rowBoat,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _highlightRowButton ? AppColors.gold : const Color(0xFFF05A28),
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                minimumSize: Size.zero,
                                              ),
                                              child: Text('ROW', style: GoogleFonts.pressStart2p(fontSize: 9, color: Colors.white)),
                                            ),
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
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                    color: _gameOver ? (_won ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15)) : const Color(0x40000000),
                    child: Column(
                      children: [
                        Text(_message, textAlign: TextAlign.center, style: GoogleFonts.pressStart2p(
                          fontSize: 10, 
                          color: _gameOver ? (_won ? Colors.green : Colors.red) : Colors.white,
                          height: 1.5,
                        )),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: _reset,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B),
                                side: const BorderSide(color: Colors.white24),
                              ),
                              child: Text('RESET', style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white)),
                            ),
                            const SizedBox(width: 14),
                            ElevatedButton(
                              onPressed: _getHint,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.gold,
                              ),
                              child: Text('💡 HINT', style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.black, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (_showConflict) _buildConflictOverlay(),
              if (_won) _buildCompleteOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}

class GameState {
  final Map<Entity, Location> locations;
  final Location boatLocation;

  GameState(this.locations, this.boatLocation);

  bool get isValid {
    final left = locations.entries.where((e) => e.value == Location.leftBank).map((e) => e.key).toList();
    if (!left.contains(Entity.farmer) && boatLocation != Location.leftBank) {
      if (left.contains(Entity.wolf) && left.contains(Entity.goat)) return false;
      if (left.contains(Entity.goat) && left.contains(Entity.cabbage)) return false;
    }
    final right = locations.entries.where((e) => e.value == Location.rightBank).map((e) => e.key).toList();
    if (!right.contains(Entity.farmer) && boatLocation != Location.rightBank) {
      if (right.contains(Entity.wolf) && right.contains(Entity.goat)) return false;
      if (right.contains(Entity.goat) && right.contains(Entity.cabbage)) return false;
    }
    return true;
  }

  bool get isGoal {
    return locations.values.every((l) => l == Location.rightBank);
  }

  String serialize() {
    return '${locations[Entity.farmer]!.index}-${locations[Entity.wolf]!.index}-${locations[Entity.goat]!.index}-${locations[Entity.cabbage]!.index}-${boatLocation.index}';
  }
}

class HintResult {
  final String message;
  final Entity? entity;
  final bool row;

  HintResult(this.message, {this.entity, this.row = false});
}

class BFSNode {
  final GameState state;
  final BFSNode? parent;
  final HintResult? action;

  BFSNode(this.state, {this.parent, this.action});
}
