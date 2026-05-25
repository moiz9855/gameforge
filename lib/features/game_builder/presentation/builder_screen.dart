import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/services/sound_service.dart';
import '../domain/game_object.dart';
import 'builder_controller.dart';

// ──────────────────────────────────────────────────────────
// BuilderScreen — the premium, redesigned Game Builder
// ──────────────────────────────────────────────────────────
class BuilderScreen extends ConsumerStatefulWidget {
  final String? gameId;
  const BuilderScreen({super.key, this.gameId});

  @override
  ConsumerState<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends ConsumerState<BuilderScreen>
    with TickerProviderStateMixin {
  final _titleController = TextEditingController(text: 'New Game');
  late AnimationController _aiPulseController;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _aiPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    if (widget.gameId != null) {
      Future.microtask(() {
        ref.read(builderStateProvider.notifier).loadGame(widget.gameId!);
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _aiPulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  // ──────── PUBLISH BOTTOM SHEET ────────
  void _showPublishSheet() {
    SoundService.instance.play(SoundType.buttonTap);
    final builderState = ref.read(builderStateProvider);
    final controller = ref.read(builderStateProvider.notifier);
    _titleController.text = builderState.title;
    final descController =
        TextEditingController(text: builderState.description);
    String selectedDifficulty = builderState.difficulty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF0F0F12),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(color: Color(0xFF26262E), width: 1),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF26262E),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppColors.fireGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child:
                            const Icon(Icons.rocket_launch, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.gameId == null ? 'Publish Game' : 'Update Game',
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.only(left: 44),
                    child: Text(
                      'Share your creation with the community!',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Game Title field
                  _BuilderTextField(
                    controller: _titleController,
                    label: 'Game Title',
                    hint: 'My Awesome Platformer',
                    icon: Icons.title,
                    onChanged: controller.setTitle,
                  ),
                  const SizedBox(height: 16),
                  // Description field
                  _BuilderTextField(
                    controller: descController,
                    label: 'Description',
                    hint: 'A fun platformer where you collect coins...',
                    icon: Icons.description,
                    maxLines: 3,
                    onChanged: controller.setDescription,
                  ),
                  const SizedBox(height: 16),
                  // Difficulty
                  const Text('Difficulty',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: ['easy', 'medium', 'hard'].map((diff) {
                      final isSelected = selectedDifficulty == diff;
                      final label =
                          diff[0].toUpperCase() + diff.substring(1);
                      final diffColor = diff == 'easy'
                          ? AppColors.success
                          : diff == 'medium'
                              ? AppColors.gold
                              : AppColors.danger;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: diff == 'easy' ? 0 : 4,
                            right: diff == 'hard' ? 0 : 4,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              SoundService.instance.play(SoundType.buttonTap);
                              setSheetState(
                                  () => selectedDifficulty = diff);
                              controller.setDifficulty(diff);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? diffColor.withValues(alpha: 0.15)
                                    : const Color(0xFF1C1C22),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? diffColor
                                      : const Color(0xFF26262E),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? diffColor
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  // Publish button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.fireGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _onPublish();
                        },
                        icon: const Icon(Icons.rocket_launch, size: 18),
                        label: Text(
                          widget.gameId == null ? 'PUBLISH' : 'UPDATE',
                          style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _onPublish() async {
    final success =
        await ref.read(builderStateProvider.notifier).publishGame();
    if (success && mounted) {
      SoundService.instance.play(SoundType.winFanfare);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Game published successfully!'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.go('/');
    } else if (mounted) {
      SoundService.instance.play(SoundType.loseSound);
      final error = ref.read(builderStateProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to publish game'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ──────── AI PANEL ────────
  void _showAIPanel() {
    SoundService.instance.play(SoundType.buttonTap);
    final aiPromptController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF0F0F12),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(color: Color(0xFF26262E), width: 1),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF26262E),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFAF52DE), Color(0xFF5E5CE6)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFFAF52DE).withValues(alpha: 0.4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.auto_awesome,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '✨ AI Game Generator',
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Describe your game and AI will build it',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Prompt field
                  _BuilderTextField(
                    controller: aiPromptController,
                    label: 'Describe Your Game',
                    hint:
                        'e.g. A jungle platformer where a monkey\ncollects bananas and avoids snakes...',
                    icon: Icons.edit_note,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  // Example chips
                  const Text('Try these ideas:',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'Space shooter with asteroids',
                      'Underwater adventure with fish',
                      'Desert runner with cacti',
                      'Castle platformer with enemies',
                    ]
                        .map((prompt) => _PromptChip(
                              label: prompt,
                              onTap: () {
                                SoundService.instance
                                    .play(SoundType.buttonTap);
                                setSheetState(() {
                                  aiPromptController.text = prompt;
                                });
                              },
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  // Generate button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFAF52DE),
                            Color(0xFF5E5CE6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFAF52DE)
                                .withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (aiPromptController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'Please enter a game description'),
                                backgroundColor: AppColors.warning,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          _runAIGeneration(
                            aiPromptController.text,
                          );
                        },
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text(
                          'Generate Game ✨',
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _runAIGeneration(String prompt) async {
    final controller = ref.read(builderStateProvider.notifier);
    final success = await controller.generateWithAI(prompt);
    if (mounted && success) {
      SoundService.instance.play(SoundType.achievement);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Text('✨', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                    'Game generated! Customize it further or publish!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF7C3AED),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else if (mounted) {
      final error = ref.read(builderStateProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'AI generation failed'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ──────── CLEAR CANVAS ────────
  void _confirmClearCanvas() {
    SoundService.instance.play(SoundType.buttonTap);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep, color: AppColors.danger, size: 22),
            SizedBox(width: 8),
            Text('Clear Canvas',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'PressStart2P',
                    fontSize: 12)),
          ],
        ),
        content: const Text(
          'Remove all elements from the canvas? This can be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(builderStateProvider.notifier).clearCanvas();
              SoundService.instance.play(SoundType.gameOver);
            },
            child: const Text('CLEAR',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final builderState = ref.watch(builderStateProvider);
    final controller = ref.read(builderStateProvider.notifier);
    final safePadTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFF080809),
      body: Column(
        children: [
          // ──────── HEADER ────────
          Container(
            padding: EdgeInsets.only(top: safePadTop + 8, bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F12),
              border: const Border(
                  bottom: BorderSide(color: Color(0xFF26262E), width: 1)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // Back
                  _HeaderIconButton(
                    icon: Icons.arrow_back,
                    onTap: () {
                      SoundService.instance.play(SoundType.buttonBack);
                      context.pop();
                    },
                  ),
                  const SizedBox(width: 8),
                  // Clear
                  _HeaderIconButton(
                    icon: Icons.delete_sweep_outlined,
                    onTap: _confirmClearCanvas,
                  ),
                  const Spacer(),
                  // Title
                  const Text(
                    'GAME BUILDER',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  // Undo
                  _HeaderIconButton(
                    icon: Icons.undo_rounded,
                    onTap: builderState.undoHistory.isNotEmpty
                        ? () {
                            SoundService.instance.play(SoundType.buttonTap);
                            controller.undo();
                          }
                        : null,
                    enabled: builderState.undoHistory.isNotEmpty,
                  ),
                  const SizedBox(width: 8),
                  // Publish
                  GestureDetector(
                    onTap:
                        builderState.isSaving ? null : _showPublishSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: builderState.isSaving
                            ? null
                            : AppColors.fireGradient,
                        color: builderState.isSaving
                            ? AppColors.muted
                            : null,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: builderState.isSaving
                            ? null
                            : [
                                BoxShadow(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: builderState.isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cloud_upload,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  widget.gameId == null
                                      ? 'PUBLISH'
                                      : 'UPDATE',
                                  style: const TextStyle(
                                    fontFamily: 'PressStart2P',
                                    fontSize: 8,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ──────── CANVAS ────────
          Expanded(
            child: Stack(
              children: [
                // Canvas with border glow
                AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, child) {
                    final glowOpacity =
                        0.15 + _glowController.value * 0.15;
                    return Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF080809),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary
                              .withValues(alpha: glowOpacity),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(
                                alpha: glowOpacity * 0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: GestureDetector(
                      onTapUp: (details) {
                        if (builderState.activeToolType != null) {
                          SoundService.instance.play(SoundType.buttonTap);
                          controller.addObjectFromTap(
                            details.localPosition.dx /
                                builderState.zoomLevel,
                            details.localPosition.dy /
                                builderState.zoomLevel,
                          );
                        } else {
                          controller.selectObject(null);
                        }
                      },
                      child: Stack(
                        children: [
                          // Grid background
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _GridPainter(
                                  zoom: builderState.zoomLevel),
                            ),
                          ),

                          // Placed Objects
                          for (final obj in builderState.objects)
                            Positioned(
                              left: obj.x * builderState.zoomLevel,
                              top: obj.y * builderState.zoomLevel,
                              child: GestureDetector(
                                onTap: () {
                                  SoundService.instance
                                      .play(SoundType.buttonTap);
                                  controller.selectObject(obj.id);
                                },
                                onPanUpdate: (details) {
                                  controller.updateObjectPosition(
                                    obj.id,
                                    details.delta.dx /
                                        builderState.zoomLevel,
                                    details.delta.dy /
                                        builderState.zoomLevel,
                                  );
                                },
                                onPanStart: (_) {
                                  controller.selectObject(obj.id);
                                },
                                onDoubleTap: () {
                                  SoundService.instance
                                      .play(SoundType.gameOver);
                                  controller.removeObject(obj.id);
                                },
                                child: _CanvasObjectWidget(
                                  obj: obj,
                                  isSelected:
                                      builderState.selectedObjectId ==
                                          obj.id,
                                  zoom: builderState.zoomLevel,
                                  onDelete: () {
                                    SoundService.instance
                                        .play(SoundType.gameOver);
                                    controller.removeObject(obj.id);
                                  },
                                ),
                              ),
                            ),

                          // Empty canvas hint
                          if (builderState.objects.isEmpty &&
                              !builderState.isGenerating)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.touch_app_rounded,
                                      color: AppColors.muted
                                          .withValues(alpha: 0.5),
                                      size: 48,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Tap elements below to start building',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.muted
                                            .withValues(alpha: 0.7),
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'or use AI to generate a game ✨',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.muted
                                            .withValues(alpha: 0.5),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // AI Generating overlay
                if (builderState.isGenerating)
                  Positioned.fill(
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                color: Color(0xFFAF52DE),
                                strokeWidth: 3,
                                backgroundColor: Color(0xFF26262E),
                              ),
                            ),
                            const SizedBox(height: 20),
                            AnimatedSwitcher(
                              duration:
                                  const Duration(milliseconds: 400),
                              child: Text(
                                builderState.aiStatusMessage ?? '',
                                key: ValueKey(
                                    builderState.aiStatusMessage),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontFamily: 'PressStart2P',
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Element count badge
                if (builderState.objects.isNotEmpty)
                  Positioned(
                    top: 18,
                    left: 18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F12)
                            .withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFF26262E), width: 1),
                      ),
                      child: Text(
                        '${builderState.elementCount} element${builderState.elementCount == 1 ? '' : 's'} placed',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                // Zoom controls
                Positioned(
                  right: 18,
                  top: 18,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F12)
                          .withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF26262E), width: 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ZoomButton(
                          icon: Icons.add,
                          onTap: builderState.zoomLevel < 2.0
                              ? () => controller.zoomIn()
                              : null,
                        ),
                        Container(
                          width: 28,
                          padding: const EdgeInsets.symmetric(
                              vertical: 4),
                          child: Center(
                            child: Text(
                              '${(builderState.zoomLevel * 100).round()}%',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        _ZoomButton(
                          icon: Icons.remove,
                          onTap: builderState.zoomLevel > 0.5
                              ? () => controller.zoomOut()
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ──────── BOTTOM TOOLBAR ────────
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F12),
              border: const Border(
                  top: BorderSide(color: Color(0xFF26262E), width: 1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: SizedBox(
                  height: 76,
                  child: Row(
                    children: [
                      // Scrollable elements
                      Expanded(
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: GameObjectType.values.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final type = GameObjectType.values[index];
                            final isActive =
                                builderState.activeToolType == type;
                            return _ToolCard(
                              type: type,
                              isActive: isActive,
                              onTap: () {
                                SoundService.instance
                                    .play(SoundType.buttonTap);
                                controller.setActiveTool(type);
                              },
                            );
                          },
                        ),
                      ),
                      // Separator
                      Container(
                        width: 1,
                        height: 50,
                        margin:
                            const EdgeInsets.symmetric(horizontal: 6),
                        color: const Color(0xFF26262E),
                      ),
                      // AI Button
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: AnimatedBuilder(
                          animation: _aiPulseController,
                          builder: (context, child) {
                            final scale = 1.0 +
                                _aiPulseController.value * 0.06;
                            final glowAlpha =
                                0.2 + _aiPulseController.value * 0.3;
                            return Transform.scale(
                              scale: scale,
                              child: GestureDetector(
                                onTap: _showAIPanel,
                                child: Container(
                                  width: 62,
                                  height: 62,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFAF52DE),
                                        Color(0xFF5E5CE6),
                                      ],
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFAF52DE)
                                            .withValues(alpha: glowAlpha),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.auto_awesome,
                                          color: Colors.white,
                                          size: 22),
                                      SizedBox(height: 2),
                                      Text(
                                        'AI',
                                        style: TextStyle(
                                          fontFamily: 'PressStart2P',
                                          fontSize: 8,
                                          color: Colors.white,
                                          letterSpacing: 1,
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Supporting Widgets
// ──────────────────────────────────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  const _HeaderIconButton({
    required this.icon,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF26262E), width: 1),
        ),
        child: Icon(
          icon,
          color: enabled
              ? AppColors.textPrimary
              : AppColors.muted.withValues(alpha: 0.4),
          size: 18,
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _ZoomButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null
              ? AppColors.textPrimary
              : AppColors.muted.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final GameObjectType type;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolCard({
    required this.type,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 66,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.12)
              : const Color(0xFF1C1C22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isActive ? AppColors.primary : const Color(0xFF26262E),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              type.emoji,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 4),
            Text(
              type.label,
              style: TextStyle(
                color: isActive
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CanvasObjectWidget extends StatelessWidget {
  final GameObject obj;
  final bool isSelected;
  final double zoom;
  final VoidCallback onDelete;

  const _CanvasObjectWidget({
    required this.obj,
    required this.isSelected,
    required this.zoom,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = obj.type.color;
    final w = obj.width * zoom;
    final h = obj.height * zoom;

    return SizedBox(
      width: w + (isSelected ? 0 : 0),
      height: h + (isSelected ? 28 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Delete button when selected
          if (isSelected)
            Positioned(
              top: 0,
              right: -4,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.danger.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 12),
                ),
              ),
            ),
          // Object
          Positioned(
            top: isSelected ? 26 : 0,
            left: 0,
            child: Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(
                    obj.type == GameObjectType.coin ? 20 : 4),
                border: Border.all(
                  color: isSelected ? AppColors.primary : color,
                  width: isSelected ? 2.5 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isSelected ? AppColors.primary : color)
                        .withValues(alpha: isSelected ? 0.6 : 0.35),
                    blurRadius: isSelected ? 12 : 6,
                    spreadRadius: isSelected ? 2 : 0,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  obj.type.emoji,
                  style: TextStyle(fontSize: 14 * zoom),
                ),
              ),
            ),
          ),
          // Label when selected
          if (isSelected)
            Positioned(
              top: 6,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppColors.primary, width: 1),
                  ),
                  child: Text(
                    obj.type.label,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 7,
                      fontFamily: 'PressStart2P',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PromptChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C22),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: const Color(0xFF26262E), width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _BuilderTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _BuilderTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLines: maxLines,
          obscureText: false,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: AppColors.muted.withValues(alpha: 0.6),
                fontSize: 13),
            prefixIcon: Icon(icon, color: AppColors.muted, size: 18),
            filled: true,
            fillColor: const Color(0xFF1C1C22),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF26262E), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF26262E), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  final double zoom;
  _GridPainter({this.zoom = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1C1C22).withValues(alpha: 0.6)
      ..strokeWidth = 0.5;

    final double gridSize = 40 * zoom;

    for (double i = 0; i < size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // Draw major grid lines every 4 cells
    final majorPaint = Paint()
      ..color = const Color(0xFF1C1C22).withValues(alpha: 0.9)
      ..strokeWidth = 1;

    final double majorGridSize = gridSize * 4;
    for (double i = 0; i < size.width; i += majorGridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), majorPaint);
    }
    for (double i = 0; i < size.height; i += majorGridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), majorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.zoom != zoom;
}
