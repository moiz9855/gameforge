import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool isLogin = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (isLogin) {
        ref.read(authControllerProvider.notifier).signIn(
              _emailController.text.trim(),
              _passwordController.text,
            );
      } else {
        ref.read(authControllerProvider.notifier).signUp(
              _emailController.text.trim(),
              _passwordController.text,
              _usernameController.text.trim(),
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      next.when(
        data: (_) {},
        error: (e, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        },
        loading: () {},
      );
    });

    return Scaffold(
      body: Stack(
        children: [
          // Background graphic
          Positioned(
            top: -150,
            right: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ).animate().fade(duration: 1.seconds).scale(delay: 200.ms),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.fire2.withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ).animate().fade(duration: 1.seconds).scale(delay: 400.ms),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo / Title
                      Text(
                        'GAMEFORGE',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          shadows: [
                            const Shadow(
                              color: AppColors.primary,
                              blurRadius: 15,
                            ),
                          ],
                        ),
                      ).animate().fade(duration: 800.ms).slideY(begin: -0.5),
                      const SizedBox(height: 8),
                      Text(
                        'Build. Play. Share.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.fire2,
                          letterSpacing: 2,
                        ),
                      ).animate().fade(delay: 300.ms),
                      const SizedBox(height: 48),

                      // Input Fields
                      if (!isLogin) ...[
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            hintText: 'Player Name',
                            prefixIcon: Icon(Icons.person, color: AppColors.textSecondary),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a username';
                            }
                            return null;
                          },
                        ).animate().fade(delay: 400.ms).slideX(),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'Email Address',
                          prefixIcon: Icon(Icons.email, color: AppColors.textSecondary),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty || !value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ).animate().fade(delay: 500.ms).slideX(),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Password',
                          prefixIcon: Icon(Icons.lock, color: AppColors.textSecondary),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ).animate().fade(delay: 600.ms).slideX(),
                      const SizedBox(height: 32),

                      // Submit Button
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: authState.isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: authState.isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(isLogin ? 'START GAME' : 'JOIN LOBBY'),
                        ),
                      ).animate().fade(delay: 700.ms).scale(),
                      const SizedBox(height: 18),

                      // OR Divider
                      const Row(
                        children: [
                          Expanded(child: Divider(color: AppColors.border, thickness: 1)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '— OR —',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: AppColors.border, thickness: 1)),
                        ],
                      ).animate().fade(delay: 750.ms),
                      const SizedBox(height: 18),

                      // Google Sign In Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: authState.isLoading
                              ? null
                              : () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1F1F1F),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: authState.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF1F1F1F),
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    GoogleLogo(size: 18),
                                    SizedBox(width: 12),
                                    Text(
                                      'Continue with Google',
                                      style: TextStyle(
                                        color: Color(0xFF1F1F1F),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ).animate().fade(delay: 800.ms),
                      const SizedBox(height: 12),

                      // Toggle Login/Signup
                      TextButton(
                        onPressed: () {
                          setState(() {
                            isLogin = !isLogin;
                          });
                        },
                        child: Text(
                          isLogin
                              ? 'New player? Create an account'
                              : 'Already have an account? Login',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ).animate().fade(delay: 850.ms),
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

class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint paint = Paint()..style = PaintingStyle.fill;
    final rect = Rect.fromLTWH(0, 0, w, h);
    
    // 1. Red (Top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -3.14159 * 0.75, -3.14159 * 0.5, true, paint);
    
    // 2. Yellow (Left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -3.14159 * 1.25, -3.14159 * 0.5, true, paint);
    
    // 3. Green (Bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, -3.14159 * 1.75, -3.14159 * 0.5, true, paint);
    
    // 4. Blue (Right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -3.14159 * 0.25, -3.14159 * 0.5, true, paint);

    // 5. White Cutout (Inner Circle)
    paint.color = Colors.white;
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.32, paint);
    
    // 6. Blue Horizontal Bar
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTRB(w * 0.5, h * 0.35, w * 0.94, h * 0.65), paint);
    
    // 7. White Gap sector
    paint.color = Colors.white;
    canvas.drawArc(rect, -3.14159 * 0.25, 3.14159 * 0.15, true, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
