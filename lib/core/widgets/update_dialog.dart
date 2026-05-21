import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/services/update_service.dart';

/// Dark / fire themed update prompt with optional forced update.
class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;

  const UpdateDialog({super.key, required this.info});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double? _progress;
  String? _error;

  Future<void> _onUpdateNow() async {
    setState(() {
      _downloading = true;
      _error = null;
      _progress = 0;
    });
    try {
      await HapticFeedback.lightImpact();
      final path = await UpdateService.instance.downloadApk(
        url: widget.info.downloadUrl,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      await HapticFeedback.heavyImpact();
      await UpdateService.instance.openDownloadedApk(path);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      await HapticFeedback.vibrate();
      if (mounted) {
        setState(() {
          _error = e.toString();
          _downloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final forced = widget.info.isForced;

    return PopScope(
      canPop: !forced && !_downloading,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.card, AppColors.card2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.fireGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Icon(Icons.sports_esports_rounded,
                    color: Colors.white, size: 34),
              ),
              const SizedBox(height: 14),
              Text(
                'New Update Available!',
                textAlign: TextAlign.center,
                style: GoogleFonts.rajdhani(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.info.currentVersion,
                    style: GoogleFonts.pressStart2p(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.arrow_forward_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  Text(
                    widget.info.remoteVersion,
                    style: GoogleFonts.pressStart2p(
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'What\'s new',
                  style: GoogleFonts.rajdhani(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 2,
                    color: AppColors.fire2,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Text(
                    widget.info.changelog.isEmpty
                        ? '—'
                        : widget.info.changelog,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              if (_downloading || _error != null) ...[
                const SizedBox(height: 16),
                if (_error != null)
                  Text(
                    _error!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.danger,
                    ),
                  )
                else ...[
                  if (_progress != null)
                    Text(
                      '${(_progress! * 100).clamp(0, 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.pressStart2p(
                        fontSize: 10,
                        color: AppColors.fire2,
                      ),
                    )
                  else
                    Text(
                      '…',
                      style: GoogleFonts.pressStart2p(
                        fontSize: 10,
                        color: AppColors.fire2,
                      ),
                    ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 8,
                      backgroundColor: AppColors.border,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Note: Because this is a manual APK install, Google Play Protect may warn you about an unverified developer. This is normal and safe for manual releases.',
                        style: GoogleFonts.rajdhani(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (!forced) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _downloading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(
                          'Later',
                          style: GoogleFonts.rajdhani(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: forced ? 1 : 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.fireGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _downloading ? null : _onUpdateNow,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _downloading ? 'Downloading…' : 'Update Now',
                          style: GoogleFonts.rajdhani(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
