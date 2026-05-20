import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  User? get currentUser => _supabase.auth.currentUser;

  Future<void> signIn(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password, String username) async {
    await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
    
    // If we need to insert the user into our public.users table,
    // Supabase usually handles this via a Postgres Trigger on auth.users insert.
    // Assuming a trigger exists, we just need to sign up.
    // If not, we would insert here:
    /*
    if (response.user != null) {
      await _supabase.from('users').insert({
        'id': response.user!.id,
        'username': username,
      });
    }
    */
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
