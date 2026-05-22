import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/game_object.dart';
import '../../auth/data/auth_repository.dart';

// Provides the builder state
final builderStateProvider =
    StateNotifierProvider<BuilderController, BuilderState>((ref) {
  return BuilderController(ref);
});

class BuilderState {
  final String? gameId;
  final List<GameObject> objects;
  final String title;
  final String description;
  final String difficulty;
  final bool isSaving;
  final String? error;
  final String? selectedObjectId;
  final GameObjectType? activeToolType;
  final double zoomLevel;
  final List<List<GameObject>> undoHistory;
  // AI generation
  final bool isGenerating;
  final String? aiStatusMessage;

  BuilderState({
    this.gameId,
    this.objects = const [],
    this.title = 'New Game',
    this.description = '',
    this.difficulty = 'medium',
    this.isSaving = false,
    this.error,
    this.selectedObjectId,
    this.activeToolType,
    this.zoomLevel = 1.0,
    this.undoHistory = const [],
    this.isGenerating = false,
    this.aiStatusMessage,
  });

  int get elementCount => objects.length;

  BuilderState copyWith({
    String? gameId,
    List<GameObject>? objects,
    String? title,
    String? description,
    String? difficulty,
    bool? isSaving,
    String? error,
    String? selectedObjectId,
    bool clearSelection = false,
    GameObjectType? activeToolType,
    bool clearActiveTool = false,
    double? zoomLevel,
    List<List<GameObject>>? undoHistory,
    bool? isGenerating,
    String? aiStatusMessage,
    bool clearAiStatus = false,
  }) {
    return BuilderState(
      gameId: gameId ?? this.gameId,
      objects: objects ?? this.objects,
      title: title ?? this.title,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      isSaving: isSaving ?? this.isSaving,
      error: clearAiStatus ? null : (error ?? this.error),
      selectedObjectId:
          clearSelection ? null : (selectedObjectId ?? this.selectedObjectId),
      activeToolType:
          clearActiveTool ? null : (activeToolType ?? this.activeToolType),
      zoomLevel: zoomLevel ?? this.zoomLevel,
      undoHistory: undoHistory ?? this.undoHistory,
      isGenerating: isGenerating ?? this.isGenerating,
      aiStatusMessage:
          clearAiStatus ? null : (aiStatusMessage ?? this.aiStatusMessage),
    );
  }
}

class BuilderController extends StateNotifier<BuilderState> {
  final Ref _ref;
  final _uuid = const Uuid();

  BuilderController(this._ref) : super(BuilderState());

  // ──────── UNDO ────────
  void _pushUndo() {
    final history = [...state.undoHistory, state.objects.map((o) => o.copyWith()).toList()];
    // Keep max 30 undo levels
    if (history.length > 30) history.removeAt(0);
    state = state.copyWith(undoHistory: history);
  }

  void undo() {
    if (state.undoHistory.isEmpty) return;
    final history = [...state.undoHistory];
    final previous = history.removeLast();
    state = state.copyWith(
      objects: previous,
      undoHistory: history,
      clearSelection: true,
    );
  }

  // ──────── ZOOM ────────
  void zoomIn() {
    if (state.zoomLevel < 2.0) {
      state = state.copyWith(zoomLevel: state.zoomLevel + 0.25);
    }
  }

  void zoomOut() {
    if (state.zoomLevel > 0.5) {
      state = state.copyWith(zoomLevel: state.zoomLevel - 0.25);
    }
  }

  // ──────── SELECTION ────────
  void selectObject(String? id) {
    if (id == null) {
      state = state.copyWith(clearSelection: true);
    } else {
      state = state.copyWith(selectedObjectId: id);
    }
  }

  void setActiveTool(GameObjectType? type) {
    if (state.activeToolType == type) {
      state = state.copyWith(clearActiveTool: true);
    } else if (type == null) {
      state = state.copyWith(clearActiveTool: true);
    } else {
      state = state.copyWith(activeToolType: type);
    }
  }

  // ──────── OBJECTS ────────
  void addObject(GameObjectType type, double x, double y) {
    _pushUndo();
    final newObject = GameObject(
      id: _uuid.v4(),
      type: type,
      x: x,
      y: y,
    );
    state = state.copyWith(
      objects: [...state.objects, newObject],
      selectedObjectId: newObject.id,
    );
  }

  void addObjectFromTap(double x, double y) {
    if (state.activeToolType == null) return;
    _pushUndo();
    final type = state.activeToolType!;
    final newObject = GameObject(
      id: _uuid.v4(),
      type: type,
      x: x - type.defaultWidth / 2,
      y: y - type.defaultHeight / 2,
    );
    state = state.copyWith(
      objects: [...state.objects, newObject],
      selectedObjectId: newObject.id,
    );
  }

  void updateObjectPosition(String id, double dx, double dy) {
    final updatedObjects = state.objects.map((obj) {
      if (obj.id == id) {
        obj.x += dx;
        obj.y += dy;
      }
      return obj;
    }).toList();
    state = state.copyWith(objects: updatedObjects);
  }

  void removeObject(String id) {
    _pushUndo();
    state = state.copyWith(
      objects: state.objects.where((obj) => obj.id != id).toList(),
      clearSelection: true,
    );
  }

  void clearCanvas() {
    if (state.objects.isEmpty) return;
    _pushUndo();
    state = state.copyWith(objects: [], clearSelection: true);
  }

  // ──────── METADATA ────────
  void setTitle(String title) => state = state.copyWith(title: title);
  void setDescription(String desc) => state = state.copyWith(description: desc);
  void setDifficulty(String diff) =>
      state = state.copyWith(difficulty: diff);

  // ──────── LOAD / SAVE ────────
  Future<void> loadGame(String gameId) async {
    state = state.copyWith(isSaving: true, error: null);
    try {
      final response = await Supabase.instance.client
          .from('games')
          .select()
          .eq('id', gameId)
          .single();

      final dataList = response['game_data'] as List;
      final objects =
          dataList.map((json) => GameObject.fromJson(json)).toList();

      state = state.copyWith(
        gameId: response['id'] as String,
        title: response['title'] as String,
        description: response['description'] as String? ?? '',
        difficulty: response['difficulty'] as String? ?? 'medium',
        objects: objects,
        isSaving: false,
      );
    } catch (e) {
      state =
          state.copyWith(isSaving: false, error: 'Failed to load game: $e');
    }
  }

  Future<bool> publishGame() async {
    state = state.copyWith(isSaving: true, error: null);
    try {
      final user = _ref.read(authRepositoryProvider).currentUser;
      if (user == null) {
        throw Exception('Must be logged in to publish.');
      }

      final gameData = state.objects.map((e) => e.toJson()).toList();

      final payload = {
        'title': state.title,
        'description': state.description,
        'difficulty': state.difficulty,
        'creator_id': user.id,
        'game_data': gameData,
        'thumbnail_url':
            'https://placehold.co/600x400/1A1A24/F05A28/png?text=${Uri.encodeComponent(state.title)}',
      };

      if (state.gameId != null) {
        await Supabase.instance.client
            .from('games')
            .update(payload)
            .eq('id', state.gameId!);
      } else {
        await Supabase.instance.client.from('games').insert(payload);
      }

      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  // ──────── AI GENERATION ────────
  static const _aiSystemPrompt =
      'You are a game level designer for a 2D platformer. '
      'Given a game description, generate a JSON array of game objects. '
      'Each object has: type (player/platform/coin/obstacle/enemy/spring/key/door), '
      'x (0-800), y (0-1200), width, height.\n\n'
      'Rules:\n'
      '- Always include exactly 1 player at x:100, y:900\n'
      '- Add 6-12 platforms spread across the level\n'
      '- Add 8-15 coins on or near platforms\n'
      '- Add 3-8 obstacles on platforms\n'
      '- Add 2-5 enemies patrolling platforms\n'
      '- Make the layout fun and completable\n'
      '- Spread elements across the full canvas height\n\n'
      'Return ONLY a valid JSON array, no other text.';

  static const _statusMessages = [
    'Analyzing your idea...',
    'Placing platforms...',
    'Adding obstacles...',
    'Spawning enemies...',
    'Polishing the level...',
  ];

  Future<bool> generateWithAI(String prompt, String apiKey) async {
    if (prompt.trim().isEmpty) return false;

    state = state.copyWith(
      isGenerating: true,
      aiStatusMessage: _statusMessages[0],
      clearSelection: true,
    );

    // Cycle through status messages
    int msgIndex = 0;
    bool generating = true;
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 2200));
      if (!generating || !mounted) return false;
      msgIndex = (msgIndex + 1) % _statusMessages.length;
      if (mounted) {
        state = state.copyWith(aiStatusMessage: _statusMessages[msgIndex]);
      }
      return generating && mounted;
    });

    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-sonnet-4-20250514',
          'max_tokens': 2048,
          'system': _aiSystemPrompt,
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
        }),
      );

      generating = false;

      if (response.statusCode != 200) {
        debugPrint('AI API Error: ${response.statusCode} - ${response.body}');
        state = state.copyWith(
          isGenerating: false,
          clearAiStatus: true,
          error: 'AI generation failed (${response.statusCode})',
        );
        return false;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final content = body['content'] as List;
      final text = content.first['text'] as String;

      // Parse the JSON array from the response
      final jsonStr = _extractJson(text);
      final List<dynamic> objectsJson = jsonDecode(jsonStr);

      _pushUndo();

      final newObjects = <GameObject>[];
      for (final item in objectsJson) {
        final map = item as Map<String, dynamic>;
        // Assign unique IDs
        map['id'] = _uuid.v4();
        try {
          newObjects.add(GameObject.fromJson(map));
        } catch (e) {
          debugPrint('Skipped malformed object: $map — $e');
        }
      }

      state = state.copyWith(
        objects: newObjects,
        isGenerating: false,
        clearAiStatus: true,
      );
      return true;
    } catch (e) {
      generating = false;
      debugPrint('AI Generation error: $e');
      state = state.copyWith(
        isGenerating: false,
        clearAiStatus: true,
        error: 'AI generation failed: $e',
      );
      return false;
    }
  }

  /// Extracts a JSON array from a possibly wrapped response
  String _extractJson(String text) {
    final trimmed = text.trim();
    // Try direct parse first
    if (trimmed.startsWith('[')) return trimmed;
    // Try extracting from markdown code block
    final codeBlockRe = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final match = codeBlockRe.firstMatch(trimmed);
    if (match != null) return match.group(1)!.trim();
    // Fallback: find the first [ and last ]
    final start = trimmed.indexOf('[');
    final end = trimmed.lastIndexOf(']');
    if (start != -1 && end != -1 && end > start) {
      return trimmed.substring(start, end + 1);
    }
    return trimmed;
  }
}
