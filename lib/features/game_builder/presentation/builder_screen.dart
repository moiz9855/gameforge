import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import '../domain/game_object.dart';
import 'builder_controller.dart';

class BuilderScreen extends ConsumerStatefulWidget {
  final String? gameId;
  const BuilderScreen({super.key, this.gameId});

  @override
  ConsumerState<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends ConsumerState<BuilderScreen> {
  final _titleController = TextEditingController(text: 'New Game');

  @override
  void initState() {
    super.initState();
    if (widget.gameId != null) {
      // Delay to avoid modifying providers during build
      Future.microtask(() {
        ref.read(builderStateProvider.notifier).loadGame(widget.gameId!);
        // We will update the title controller once it's loaded in the build method
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _showPublishDialog() {
    final builderState = ref.read(builderStateProvider);
    final controller = ref.read(builderStateProvider.notifier);
    
    // Sync the local controller with the state
    _titleController.text = builderState.title;
    
    final descController = TextEditingController(text: builderState.description);
    String selectedDifficulty = builderState.difficulty;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.surfaceLight,
            title: Text(widget.gameId == null ? 'Publish Game' : 'Update Game', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _titleController,
                    onChanged: controller.setTitle,
                    decoration: const InputDecoration(
                      labelText: 'Game Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    onChanged: controller.setDescription,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedDifficulty,
                    dropdownColor: AppColors.surface,
                    decoration: const InputDecoration(
                      labelText: 'Difficulty',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'easy', child: Text('Easy')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'hard', child: Text('Hard')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => selectedDifficulty = val);
                        controller.setDifficulty(val);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () {
                  Navigator.pop(ctx);
                  _onPublish();
                },
                child: Text(widget.gameId == null ? 'PUBLISH' : 'UPDATE'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _onPublish() async {
    final success = await ref.read(builderStateProvider.notifier).publishGame();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Game published successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/');
    } else if (mounted) {
      final error = ref.read(builderStateProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to publish game'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final builderState = ref.watch(builderStateProvider);
    final controller = ref.read(builderStateProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Game Builder'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: builderState.isSaving ? null : _showPublishDialog,
              icon: builderState.isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.cloud_upload),
              label: Text(widget.gameId == null ? 'PUBLISH' : 'UPDATE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Canvas Area
          Expanded(
            child: Container(
              color: AppColors.background,
              child: Stack(
                children: [
                  // Grid background
                  Positioned.fill(
                    child: CustomPaint(
                      painter: GridPainter(),
                    ),
                  ),
                  
                  // Drag Target for new items
                  Positioned.fill(
                    child: DragTarget<GameObjectType>(
                      builder: (context, candidateData, rejectedData) {
                        return Container(color: Colors.transparent);
                      },
                      onAcceptWithDetails: (details) {
                        final RenderBox renderBox = context.findRenderObject() as RenderBox;
                        final localPosition = renderBox.globalToLocal(details.offset);
                        // Adjust slightly for center drop
                        controller.addObject(
                          details.data,
                          localPosition.dx - 20,
                          localPosition.dy - 20 - kToolbarHeight, // Approximate app bar height adjustment
                        );
                      },
                    ),
                  ),

                  // Placed Objects
                  for (final obj in builderState.objects)
                    Positioned(
                      left: obj.x,
                      top: obj.y,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          controller.updateObjectPosition(obj.id, details.delta.dx, details.delta.dy);
                        },
                        onDoubleTap: () {
                          controller.removeObject(obj.id);
                        },
                        child: _GameObjectWidget(obj: obj),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Tools Panel (Bottom)
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ToolItem(type: GameObjectType.player, icon: Icons.person, label: 'Player'),
                _ToolItem(type: GameObjectType.platform, icon: Icons.horizontal_rule, label: 'Platform'),
                _ToolItem(type: GameObjectType.coin, icon: Icons.monetization_on, label: 'Coin'),
                _ToolItem(type: GameObjectType.obstacle, icon: Icons.warning, label: 'Obstacle'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolItem extends StatelessWidget {
  final GameObjectType type;
  final IconData icon;
  final String label;

  const _ToolItem({required this.type, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Draggable<GameObjectType>(
      data: type,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.fire2, size: 32),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildButton(),
      ),
      child: _buildButton(),
    );
  }

  Widget _buildButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.5)),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _GameObjectWidget extends StatelessWidget {
  final GameObject obj;

  const _GameObjectWidget({required this.obj});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (obj.type) {
      case GameObjectType.player:
        color = AppColors.fire2;
        icon = Icons.person;
        break;
      case GameObjectType.platform:
        color = AppColors.textSecondary;
        icon = Icons.horizontal_rule;
        break;
      case GameObjectType.coin:
        color = AppColors.warning;
        icon = Icons.monetization_on;
        break;
      case GameObjectType.obstacle:
        color = AppColors.error;
        icon = Icons.warning;
        break;
    }

    return Container(
      width: obj.width,
      height: obj.height,
      decoration: BoxDecoration(
        color: color.withOpacity(0.8),
        borderRadius: BorderRadius.circular(obj.type == GameObjectType.coin ? 20 : 4),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 8,
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.surfaceLight.withOpacity(0.5)
      ..strokeWidth = 1;

    const double gridSize = 40;

    for (double i = 0; i < size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    for (double i = 0; i < size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
