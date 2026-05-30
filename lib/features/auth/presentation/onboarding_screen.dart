import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/widgets/crt_overlay.dart';
import 'package:game_forge/core/services/sound_service.dart';
import 'package:game_forge/core/routing/app_router.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep = 1; // Steps 1 to 4
  final int _totalSteps = 4;

  // Selected values
  String? _selectedAvatar;
  String _username = '';
  final List<String> _selectedGamerTypes = [];
  String _friendId = '';

  // Step 2 Username Validation Fields
  final _usernameController = TextEditingController();
  bool _isCheckingUsername = false;
  bool _isUsernameValid = false;
  String? _usernameError;
  Timer? _debounce;

  final List<String> _avatars = [
    // Row 1 (Gaming)
    '😈', '👾', '🎮', '🕹️', '🏆', '🎯', '⚔️', '🛡️',
    // Row 2 (Cool)
    '😎', '🔥', '💀', '👻', '🤖', '👽', '🦾', '⚡',
    // Row 3 (Animals)
    '🦁', '🐺', '🦊', '🐯', '🦅', '🐉', '🦄', '🐼',
    // Row 4 (Fun)
    '🤡', '💪', '🧠', '👑', '💎', '🌟', '❤️', '🚀',
    // Row 5 (Extra)
    '🎭', '🃏', '🎪', '🎨', '🌈', '💫', '🌙', '☄️',
  ];

  final List<Map<String, String>> _gamerTypes = [
    {
      'id': 'competitive',
      'emoji': '🏆',
      'title': 'COMPETITIVE',
      'desc': 'I play to WIN. Rankings matter.',
      'color': 'red',
    },
    {
      'id': 'casual',
      'emoji': '🎲',
      'title': 'CASUAL',
      'desc': 'I play for fun. No pressure.',
      'color': 'blue',
    },
    {
      'id': 'strategic',
      'emoji': '🧠',
      'title': 'STRATEGIC',
      'desc': 'I think before I act. Chess > everything.',
      'color': 'yellow',
    },
    {
      'id': 'speedrunner',
      'emoji': '⚡',
      'title': 'SPEEDRUNNER',
      'desc': 'Fast fingers. Faster wins.',
      'color': 'cyan',
    },
    {
      'id': 'creative',
      'emoji': '🎨',
      'title': 'CREATIVE',
      'desc': 'I love building and creating games.',
      'color': 'purple',
    },
    {
      'id': 'social',
      'emoji': '👥',
      'title': 'SOCIAL',
      'desc': 'Gaming is better with friends.',
      'color': 'green',
    },
    {
      'id': 'night_owl',
      'emoji': '🌙',
      'title': 'NIGHT OWL',
      'desc': 'Best gaming sessions after midnight.',
      'color': 'indigo',
    },
    {
      'id': 'hardcore',
      'emoji': '🔥',
      'title': 'HARDCORE',
      'desc': 'I grind until I master everything.',
      'color': 'orange',
    },
  ];

  @override
  void initState() {
    super.initState();
    _prefillGoogleName();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _prefillGoogleName() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final name = user.userMetadata?['full_name'] as String? ?? '';
      if (name.isNotEmpty) {
        // Clean name: remove spaces, lowercase, remove special characters
        final cleanName = name
            .replaceAll(' ', '')
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9_]'), '');
        _usernameController.text = cleanName.substring(0, min(cleanName.length, 20));
        _validateUsername(_usernameController.text);
      }
    }
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

    if (val.length < 3) {
      setState(() {
        _isUsernameValid = false;
        _usernameError = 'Must be at least 3 characters';
      });
      return;
    }

    if (val.length > 20) {
      setState(() {
        _isUsernameValid = false;
        _usernameError = 'Must be at most 20 characters';
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

    // Supabase validation check
    setState(() {
      _isCheckingUsername = true;
      _usernameError = null;
    });

    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final response = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('username', val)
          .maybeSingle();

      if (response != null && response['id'] != currentUserId) {
        setState(() {
          _isUsernameValid = false;
          _usernameError = 'Username is already taken';
        });
      } else {
        setState(() {
          _isUsernameValid = true;
          _usernameError = null;
          _username = val;
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

  void _generateFriendId() {
    final suffix = Random().nextInt(9000) + 1000; // 1000-9999
    setState(() {
      _friendId = '$_username#$suffix';
    });
  }

  void _goNext() {
    SoundService.instance.play(SoundType.buttonTap);
    if (_currentStep == 1 && _selectedAvatar == null) return;
    if (_currentStep == 2 && !_isUsernameValid) return;
    if (_currentStep == 3 && _selectedGamerTypes.isEmpty) return;

    if (_currentStep < _totalSteps) {
      setState(() {
        _currentStep++;
        if (_currentStep == 4) {
          _generateFriendId();
        }
      });
    }
  }

  void _goBack() {
    SoundService.instance.play(SoundType.buttonBack);
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    SoundService.instance.play(SoundType.winFanfare);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Save profile details to database
    try {
      await Supabase.instance.client.from('users').update({
        'username': _username,
        'avatar_emoji': _selectedAvatar,
        'gamer_types': _selectedGamerTypes,
        'friend_id': _friendId,
        'onboarding_completed': true,
      }).eq('id', user.id);

      // Save locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed_${user.id}', true);

      // Invalidate the Riverpod provider so the redirect immediately triggers
      ref.invalidate(onboardingCompletedProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080809), // exact dark theme
      body: SafeArea(
        child: CrtOverlay(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              children: [
                // Progress Bar at the top
                _buildProgressBar(),
                const SizedBox(height: 24),

                // Animated step views
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (_currentStep == 1) _buildStep1(),
                        if (_currentStep == 2) _buildStep2(),
                        if (_currentStep == 3) _buildStep3(),
                        if (_currentStep == 4) _buildStep4(),
                      ],
                    ),
                  ),
                ),

                // Bottom Action buttons
                const SizedBox(height: 16),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _currentStep / _totalSteps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'STEP $_currentStep/$_totalSteps',
              style: GoogleFonts.pressStart2p(
                color: const Color(0xFFF05A28), // Orange accent
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}% COMPLETE',
              style: GoogleFonts.shareTechMono(
                color: AppColors.textSecondary,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            children: [
              Expanded(
                flex: (_currentStep * 10).toInt(),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF05A28),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF05A28).withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: ((_totalSteps - _currentStep) * 10).toInt(),
                child: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      children: [
        Text(
          'CHOOSE YOUR AVATAR 🎭',
          style: GoogleFonts.pressStart2p(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pick an emoji that represents you!',
          textAlign: TextAlign.center,
          style: GoogleFonts.rajdhani(
            fontSize: 16,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),

        // Large Preview Avatar
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFF0F1218),
            shape: BoxShape.circle,
            border: Border.all(
              color: _selectedAvatar != null ? const Color(0xFFF05A28) : AppColors.border,
              width: 3,
            ),
            boxShadow: _selectedAvatar != null
                ? [
                    BoxShadow(
                      color: const Color(0xFFF05A28).withValues(alpha: 0.3),
                      blurRadius: 18,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              _selectedAvatar ?? '❓',
              style: const TextStyle(fontSize: 48),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Grid of 40 emojis
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _avatars.length,
          itemBuilder: (context, index) {
            final emoji = _avatars[index];
            final isSelected = _selectedAvatar == emoji;
            return GestureDetector(
              onTap: () {
                SoundService.instance.play(SoundType.buttonTap);
                setState(() {
                  _selectedAvatar = emoji;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0x3DF05A28) : const Color(0xFF0F1218),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFF05A28) : Colors.white10,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      children: [
        Text(
          'SET YOUR USERNAME 👤',
          style: GoogleFonts.pressStart2p(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This is how other players will know you',
          style: GoogleFonts.rajdhani(
            fontSize: 16,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),

        // Show Large Preview Avatar Emoji
        if (_selectedAvatar != null)
          Text(
            _selectedAvatar!,
            style: const TextStyle(fontSize: 64),
          ),
        const SizedBox(height: 24),

        // Username Field
        TextFormField(
          controller: _usernameController,
          maxLength: 20,
          style: GoogleFonts.rajdhani(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: 'Enter your username',
            hintStyle: GoogleFonts.rajdhani(color: Colors.grey[700]),
            fillColor: const Color(0xFF0F1218),
            filled: true,
            counterStyle: GoogleFonts.shareTechMono(color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFF05A28)),
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
                    : _usernameController.text.isNotEmpty
                        ? const Icon(Icons.error_outline, color: Colors.red)
                        : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF05A28), width: 1.5),
            ),
          ),
          onChanged: (value) {
            if (_debounce?.isActive ?? false) _debounce!.cancel();
            _debounce = Timer(const Duration(milliseconds: 500), () {
              _validateUsername(value);
            });
          },
        ),

        const SizedBox(height: 12),

        if (_isCheckingUsername)
          Text(
            'Checking availability...',
            style: GoogleFonts.shareTechMono(color: const Color(0xFFF05A28)),
          )
        else if (_usernameError != null)
          Text(
            _usernameError!,
            style: GoogleFonts.shareTechMono(color: Colors.red),
          )
        else if (_isUsernameValid)
          Text(
            'Username is available! ✅',
            style: GoogleFonts.shareTechMono(color: Colors.green),
          ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      children: [
        Text(
          'GAMER TYPE? 🎮',
          style: GoogleFonts.pressStart2p(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select all that apply (select at least 1)',
          style: GoogleFonts.rajdhani(
            fontSize: 16,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0x2EF05A28) : const Color(0xFF0F1218),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFF05A28) : Colors.white10,
                    width: isSelected ? 1.8 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFF05A28).withValues(alpha: 0.05),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : [],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          type['emoji']!,
                          style: const TextStyle(fontSize: 24),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: Color(0xFFF05A28), size: 16),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      type['title']!,
                      style: GoogleFonts.pressStart2p(
                        fontSize: 8,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type['desc']!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.rajdhani(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      children: [
        Text(
          'YOU\'RE ALL SET! 🚀',
          style: GoogleFonts.pressStart2p(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Welcome to GameForge',
          style: GoogleFonts.rajdhani(
            fontSize: 16,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),

        // Summary Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1218),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF05A28).withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF05A28).withValues(alpha: 0.04),
                blurRadius: 16,
              )
            ],
          ),
          child: Column(
            children: [
              Text(
                _selectedAvatar ?? '😈',
                style: const TextStyle(fontSize: 72),
              ),
              const SizedBox(height: 12),
              Text(
                _username.toUpperCase(),
                style: GoogleFonts.pressStart2p(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),

              // Badges Grid
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _selectedGamerTypes.map((typeId) {
                  final type = _gamerTypes.firstWhere((t) => t['id'] == typeId);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E24),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getGamerColor(type['color']!),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${type['emoji']} ${type['title']}',
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Friend ID Field
        Text(
          'YOUR FRIEND ID:',
          style: GoogleFonts.pressStart2p(
            fontSize: 8,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1218),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _friendId,
                  style: GoogleFonts.shareTechMono(
                    fontSize: 20,
                    color: const Color(0xFFF05A28),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _friendId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied: $_friendId'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Share this with friends so they can add you!',
          textAlign: TextAlign.center,
          style: GoogleFonts.rajdhani(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final isFirstStep = _currentStep == 1;
    final isLastStep = _currentStep == _totalSteps;

    // Disabled states
    bool canProceed = true;
    if (_currentStep == 1 && _selectedAvatar == null) canProceed = false;
    if (_currentStep == 2 && !_isUsernameValid) canProceed = false;
    if (_currentStep == 3 && _selectedGamerTypes.isEmpty) canProceed = false;

    return Row(
      children: [
        if (!isFirstStep) ...[
          OutlinedButton(
            onPressed: _goBack,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: ElevatedButton(
            onPressed: canProceed
                ? (isLastStep ? _completeOnboarding : _goNext)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF05A28),
              disabledBackgroundColor: const Color(0xFF1E1E24),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isLastStep ? 'START PLAYING 🎮' : 'NEXT',
              style: GoogleFonts.pressStart2p(
                fontSize: 10,
                color: canProceed ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getGamerColor(String colorName) {
    switch (colorName) {
      case 'red': return Colors.red;
      case 'blue': return Colors.blue;
      case 'yellow': return Colors.yellow;
      case 'cyan': return Colors.cyan;
      case 'purple': return Colors.purple;
      case 'green': return Colors.green;
      case 'indigo': return Colors.indigo;
      case 'orange': return Colors.orange;
      default: return Colors.grey;
    }
  }
}
