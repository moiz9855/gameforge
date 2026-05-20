import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:game_forge/features/home/domain/game.dart';

final trendingGamesProvider = FutureProvider<List<Game>>((ref) async {
  final response = await Supabase.instance.client
      .from('games')
      .select('*, users(username)')
      .order('like_count', ascending: false)
      .limit(20);
      
  return (response as List).map((json) => Game.fromJson(json)).toList();
});

final newGamesProvider = FutureProvider<List<Game>>((ref) async {
  final response = await Supabase.instance.client
      .from('games')
      .select('*, users(username)')
      .order('created_at', ascending: false)
      .limit(20);
      
  return (response as List).map((json) => Game.fromJson(json)).toList();
});
