import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/game_object.dart';
import '../../auth/data/auth_repository.dart';

// Provides the builder state
final builderStateProvider = StateNotifierProvider<BuilderController, BuilderState>((ref) {
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

  BuilderState({
    this.gameId,
    this.objects = const [],
    this.title = 'New Game',
    this.description = '',
    this.difficulty = 'medium',
    this.isSaving = false,
    this.error,
  });

  BuilderState copyWith({
    String? gameId,
    List<GameObject>? objects,
    String? title,
    String? description,
    String? difficulty,
    bool? isSaving,
    String? error,
  }) {
    return BuilderState(
      gameId: gameId ?? this.gameId,
      objects: objects ?? this.objects,
      title: title ?? this.title,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

class BuilderController extends StateNotifier<BuilderState> {
  final Ref _ref;
  final _uuid = const Uuid();

  BuilderController(this._ref) : super(BuilderState());

  Future<void> loadGame(String gameId) async {
    state = state.copyWith(isSaving: true, error: null);
    try {
      final response = await Supabase.instance.client
          .from('games')
          .select()
          .eq('id', gameId)
          .single();

      final dataList = response['game_data'] as List;
      final objects = dataList.map((json) => GameObject.fromJson(json)).toList();

      state = state.copyWith(
        gameId: response['id'] as String,
        title: response['title'] as String,
        description: response['description'] as String? ?? '',
        difficulty: response['difficulty'] as String? ?? 'medium',
        objects: objects,
        isSaving: false,
      );
    } catch (e) {
      state = state.copyWith(isSaving: false, error: 'Failed to load game: $e');
    }
  }

  void setTitle(String title) {
    state = state.copyWith(title: title);
  }

  void setDescription(String desc) {
    state = state.copyWith(description: desc);
  }

  void setDifficulty(String diff) {
    state = state.copyWith(difficulty: diff);
  }

  void addObject(GameObjectType type, double x, double y) {
    final newObject = GameObject(
      id: _uuid.v4(),
      type: type,
      x: x,
      y: y,
      width: type == GameObjectType.platform ? 80 : 40,
      height: 40,
    );
    state = state.copyWith(objects: [...state.objects, newObject]);
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
    state = state.copyWith(
      objects: state.objects.where((obj) => obj.id != id).toList(),
    );
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
        'thumbnail_url': 'https://placehold.co/600x400/1A1A24/8B5CF6/png?text=Play+Now',
      };

      if (state.gameId != null) {
        // Update existing game
        await Supabase.instance.client
            .from('games')
            .update(payload)
            .eq('id', state.gameId!);
      } else {
        // Insert new game
        await Supabase.instance.client
            .from('games')
            .insert(payload);
      }

      state = state.copyWith(isSaving: false);
      return true; // Success
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }
}
