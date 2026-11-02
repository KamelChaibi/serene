import 'package:flutter/material.dart';
import 'l10n.dart';
import 'security_service.dart';
import 'storage.dart';

/// Branded launch screen shown while the app settles.
///
/// It gives the first frame a calm, recognizable identity and greets
/// returning users by name — except when the app is locked, so a name is
/// never revealed above the PIN screen.
class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const SplashScreen({super.key, required this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _minimumDisplay = Duration(milliseconds: 1400);

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  String _name = '';
  bool _nameResolved = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _prepare();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    final startedAt = DateTime.now();
    var name = '';
    try {
      final onboarded = await Store.onboardingDone();
      // Privacy first: never print a name on a locked device.
      if (onboarded && !SecurityService.instance.isLocked) {
        name = (await Store.profile()).trimmedName;
      }
    } catch (_) {
      // A storage hiccup must never block the app from opening.
    }

    if (!mounted) return;
    setState(() {
      _name = name;
      _nameResolved = true;
    });

    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < _minimumDisplay) {
      await Future<void>.delayed(_minimumDisplay - elapsed);
    }
    _finish();
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final backgroundStart =
        isDark ? const Color(0xFF131816) : const Color(0xFFF4F8F5);
    final backgroundEnd =
        isDark ? const Color(0xFF1B2421) : const Color(0xFFE4EFE8);
    final showName = _nameResolved && _name.isNotEmpty;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundStart, backgroundEnd],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LogoMark(primary: primary),
                        const SizedBox(height: 26),
                        Text(
                          'Serene',
                          // The brand name stays the same in every language.
                          textDirection: TextDirection.ltr,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.5,
                            color: primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 36),
                          child: Text(
                            s.t('tagline'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        AnimatedOpacity(
                          opacity: showName ? 1 : 0,
                          duration: const Duration(milliseconds: 450),
                          child: AnimatedSlide(
                            offset:
                                showName ? Offset.zero : const Offset(0, 0.4),
                            duration: const Duration(milliseconds: 450),
                            curve: Curves.easeOut,
                            child: Text(
                              s.t('welcomeBack').replaceAll('{name}', _name),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // A quiet hint that the app is waking up.
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 42),
                  child: FadeTransition(
                    opacity: _fade,
                    child: SizedBox(
                      width: 44,
                      child: LinearProgressIndicator(
                        minHeight: 2.5,
                        borderRadius: BorderRadius.circular(2),
                        backgroundColor: primary.withValues(alpha: 0.15),
                        color: primary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft, layered spa mark used as the Serene logo.
class _LogoMark extends StatelessWidget {
  final Color primary;
  const _LogoMark({required this.primary});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withValues(alpha: 0.06),
            ),
          ),
          Container(
            width: 102,
            height: 102,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withValues(alpha: 0.12),
            ),
          ),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary,
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.28),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.spa_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
