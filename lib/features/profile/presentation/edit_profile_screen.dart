import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/crt_overlay.dart';
import 'package:game_forge/core/services/sound_service.dart';
import 'package:game_forge/features/auth/data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_screen.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> currentProfile;
  const EditProfileScreen({super.key, required this.currentProfile});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  String? _selectedAvatar;
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final List<String> _selectedGamerTypes = [];

  bool _isCheckingUsername = false;
  bool _isUsernameValid = true;
  String? _usernameError;
  Timer? _debounce;
  bool _isSaving = false;

  final List<String> _avatars = [
    '😈', '👾', '🎮', '🕹️', '🏆', '🎯', '⚔️', '🛡️',
    '😎', '🔥', '💀', '👻', '🤖', '👽', '🦾', '⚡',
    '🦁', '🐺', '🦊', '🐯', '🦅', '🐉', '🦄', '🐼',
    '🤡', '💪', '🧠', '👑', '💎', '🌟', '❤️', '🚀',
    '🎭', '🃏', '🎪', '🎨', '🌈', '💫', '🌙', '☄️',
  ];

  final List<Map<String, String>> _gamerTypes = [
    {'id': 'competitive', 'emoji': '🏆', 'title': 'COMPETITIVE', 'desc': 'I play to WIN. Rankings matter.'},
    {'id': 'casual', 'emoji': '🎲', 'title': 'CASUAL', 'desc': 'I play for fun. No pressure.'},
    {'id': 'strategic', 'emoji': '🧠', 'title': 'STRATEGIC', 'desc': 'I think before I act. Chess > everything.'},
    {'id': 'speedrunner', 'emoji': '⚡', 'title': 'SPEEDRUNNER', 'desc': 'Fast fingers. Faster wins.'},
    {'id': 'creative', 'emoji': '🎨', 'title': 'CREATIVE', 'desc': 'I love building and creating games.'},
    {'id': 'social', 'emoji': '👥', 'title': 'SOCIAL', 'desc': 'Gaming is better with friends.'},
    {'id': 'night_owl', 'emoji': '🌙', 'title': 'NIGHT OWL', 'desc': 'Best gaming sessions after midnight.'},
    {'id': 'hardcore', 'emoji': '🔥', 'title': 'HARDCORE', 'desc': 'I grind until I master everything.'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedAvatar = widget.currentProfile['avatar_emoji'] as String? ?? '😈';
    _usernameController.text = widget.currentProfile['username'] as String? ?? '';
    _bioController.text = widget.currentProfile['bio'] as String? ?? '';
    final types = widget.currentProfile['gamer_types'] as List? ?? [];
    _selectedGamerTypes.addAll(types.map((e) => e.toString()));
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _validateUsername(String value) async {
    final val = value.trim();
    if (val.isEmpty) {
      setState(() {
        _isUsernameValid = false;
        _usernameError = 'Username cannot be empty';
      });
      return;
    }

    if (val.toLowerCase() == (widget.currentProfile['username'] as String? ?? '').toLowerCase()) {
      setState(() {
        _isUsernameValid = true;
        _usernameError = null;
      });
      return;
    }

    if (val.length < 3) {
      setState(() {
        _isUsernameValid = false;
        _usernameError = 'Must be at least 3 characters';
      });
      return;
    }

    if (val.contains(' ')) {
      setState(() {
        _isUsernameValid = false;
        _usernameError = 'No spaces allowed';
      });
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(val)) {
      setState(() {
        _isUsernameValid = false;
        _usernameError = 'Only letters, numbers, and underscores allowed';
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameError = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('username', val)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _isUsernameValid = false;
          _usernameError = 'Username is already taken';
        });
      } else {
        setState(() {
          _isUsernameValid = true;
          _usernameError = null;
        });
      }
    } catch (e) {
      setState(() {
        _isUsernameValid = false;
        _usernameError = 'Error checking availability';
      });
    } finally {
      setState(() {
        _isCheckingUsername = false;
      });
    }
  }

  void _changeAvatar() {
    SoundService.instance.play(SoundType.buttonTap);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1218),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SELECT AVATAR',
                style: GoogleFonts.pressStart2p(fontSize: 12, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _avatars.length,
                  itemBuilder: (context, index) {
                    final emoji = _avatars[index];
                    return GestureDetector(
                      onTap: () {
                        SoundService.instance.play(SoundType.buttonTap);
                        setState(() => _selectedAvatar = emoji);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E24),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Center(
                          child: Text(emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    if (!_isUsernameValid || _isCheckingUsername) return;

    setState(() => _isSaving = true);
    SoundService.instance.play(SoundType.buttonTap);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('users').update({
        'username': _usernameController.text.trim(),
        'avatar_emoji': _selectedAvatar,
        'bio': _bioController.text.trim(),
        'gamer_types': _selectedGamerTypes,
      }).eq('id', user.id);

      // Invalidate provider to refresh profile screen immediately
      ref.invalidate(userProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated! ✅'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F1218),
          title: Text(
            'DELETE ACCOUNT?',
            style: GoogleFonts.pressStart2p(fontSize: 12, color: Colors.red),
          ),
          content: Text(
            'This action is permanent and will delete all your progress, custom games, and account information.',
            style: GoogleFonts.rajdhani(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL', style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                SoundService.instance.play(SoundType.gameOver);
                final client = Supabase.instance.client;
                final userId = client.auth.currentUser?.id;
                if (userId != null) {
                  try {
                    await client.from('users').delete().eq('id', userId);
                    await ref.read(authRepositoryProvider).signOut();
                    if (context.mounted) {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Close edit profile
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
              child: Text('DELETE', style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine days ago username changed (joined_at is a timestamp)
    final joinedAtStr = widget.currentProfile['joined_at'] as String?;
    int daysAgo = 0;
    if (joinedAtStr != null) {
      try {
        final joined = DateTime.parse(joinedAtStr);
        daysAgo = DateTime.now().difference(joined).inDays;
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080809),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'EDIT PROFILE',
          style: GoogleFonts.pressStart2p(fontSize: 12, color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF05A28)),
                    )
                  : TextButton(
                      onPressed: (_isUsernameValid && !_isCheckingUsername) ? _saveProfile : null,
                      child: Text(
                        'SAVE',
                        style: GoogleFonts.pressStart2p(
                          fontSize: 10,
                          color: (_isUsernameValid && !_isCheckingUsername) ? const Color(0xFFF05A28) : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: CrtOverlay(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar grid trigger
              _buildSectionTitle('AVATAR'),
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1218),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFF05A28), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF05A28).withValues(alpha: 0.2),
                            blurRadius: 12,
                          )
                        ],
                      ),
                      child: Center(
                        child: Text(_selectedAvatar ?? '😈', style: const TextStyle(fontSize: 48)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _changeAvatar,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFF05A28)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'Change Avatar',
                        style: GoogleFonts.pressStart2p(fontSize: 8, color: const Color(0xFFF05A28)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Username section
              _buildSectionTitle('USERNAME'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameController,
                maxLength: 20,
                style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  fillColor: const Color(0xFF0F1218),
                  filled: true,
                  counterStyle: GoogleFonts.shareTechMono(color: AppColors.textSecondary),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFF05A28)),
                  ),
                  suffixIcon: _isCheckingUsername
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF05A28)),
                          ),
                        )
                      : _isUsernameValid
                          ? const Icon(Icons.check_circle_outline, color: Colors.green)
                          : const Icon(Icons.error_outline, color: Colors.red),
                ),
                onChanged: (value) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () {
                    _validateUsername(value);
                  });
                },
              ),
              if (_usernameError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(_usernameError!, style: GoogleFonts.shareTechMono(color: Colors.red)),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    'Username last changed $daysAgo days ago',
                    style: GoogleFonts.shareTechMono(color: Colors.grey, fontSize: 11),
                  ),
                ),
              const SizedBox(height: 28),

              // Bio Section
              _buildSectionTitle('BIO'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioController,
                maxLength: 100,
                maxLines: 3,
                style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Write something about yourself...',
                  hintStyle: GoogleFonts.rajdhani(color: Colors.grey[700]),
                  fillColor: const Color(0xFF0F1218),
                  filled: true,
                  counterStyle: GoogleFonts.shareTechMono(color: AppColors.textSecondary),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFF05A28)),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Gamer Types grid
              _buildSectionTitle('GAMER TYPES'),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.6,
                ),
                itemCount: _gamerTypes.length,
                itemBuilder: (context, index) {
                  final type = _gamerTypes[index];
                  final id = type['id']!;
                  final isSelected = _selectedGamerTypes.contains(id);
                  return GestureDetector(
                    onTap: () {
                      SoundService.instance.play(SoundType.buttonTap);
                      setState(() {
                        if (isSelected) {
                          _selectedGamerTypes.remove(id);
                        } else {
                          _selectedGamerTypes.add(id);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0x1EF05A28) : const Color(0xFF0F1218),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFF05A28) : Colors.white10,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(type['emoji']!, style: const TextStyle(fontSize: 20)),
                              if (isSelected)
                                const Icon(Icons.check_circle, color: Color(0xFFF05A28), size: 14),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            type['title']!,
                            style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            type['desc']!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.rajdhani(color: AppColors.textSecondary, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),

              // Danger Zone
              _buildSectionTitle('DANGER ZONE'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF140D0F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        SoundService.instance.play(SoundType.buttonBack);
                        ref.read(authRepositoryProvider).signOut();
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('SIGN OUT', style: GoogleFonts.pressStart2p(fontSize: 8)),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _confirmDeleteAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('DELETE ACCOUNT', style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.pressStart2p(
        fontSize: 10,
        color: const Color(0xFFF05A28),
        letterSpacing: 1.5,
      ),
    );
  }
}
