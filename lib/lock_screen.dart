import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'l10n.dart';
import 'responsive.dart';
import 'safety.dart';
import 'security_service.dart';
import 'storage.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _digits = [];
  bool _isError = false;
  String? _errorKey;
  Timer? _lockoutTimer;
  int _lockoutSeconds = 0;
  bool _hasBiometrics = false;
  bool _biometricBusy = false;

  @override
  void initState() {
    super.initState();
    // The biometric prompt needs the localization context, which is not safe to
    // read synchronously from initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkBiometricsAndPrompt();
    });
    _updateLockoutState();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  String _errorText(S s) {
    final key = _errorKey;
    if (key == null) return '';
    return s.t(key).replaceAll('{seconds}', '$_lockoutSeconds');
  }

  void _updateLockoutState() {
    if (SecurityService.instance.isLockedOut) {
      setState(() {
        _lockoutSeconds = SecurityService.instance.remainingLockoutSeconds;
        _errorKey = 'lockTooManyAttempts';
      });
      _lockoutTimer?.cancel();
      _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        final rem = SecurityService.instance.remainingLockoutSeconds;
        setState(() {
          _lockoutSeconds = rem;
          if (rem <= 0) {
            _errorKey = null;
            timer.cancel();
          }
        });
      });
    }
  }

  Future<void> _checkBiometricsAndPrompt() async {
    final canBio = await SecurityService.instance.canUseBiometrics();
    final bioEnabled = await SecurityService.instance.isBiometricsEnabled();
    if (mounted) {
      setState(() => _hasBiometrics = canBio && bioEnabled);
    }
    if (canBio && bioEnabled && !SecurityService.instance.isLockedOut) {
      // Prompt automatically, but stay quiet if the user cancels: they can
      // still type their PIN.
      await _tryBiometrics(showError: false);
    }
  }

  Future<void> _tryBiometrics({bool showError = true}) async {
    if (_biometricBusy) return;
    final s = S.of(context);
    setState(() => _biometricBusy = true);
    final ok = await SecurityService.instance.authenticateBiometrics(
      reason: s.t('lockBiometricReason'),
    );
    if (!mounted) return;
    setState(() => _biometricBusy = false);
    if (ok) {
      widget.onUnlocked();
    } else if (showError && mounted) {
      setState(() {
        _errorKey = SecurityService.instance.isLockedOut
            ? 'lockTooManyAttempts'
            : 'lockBiometricFailed';
      });
      if (SecurityService.instance.isLockedOut) _updateLockoutState();
    }
  }

  void _onDigit(String d) async {
    if (SecurityService.instance.isLockedOut) return;
    if (_digits.length < 4) {
      setState(() {
        _digits.add(d);
        _isError = false;
        _errorKey = null;
      });

      if (_digits.length == 4) {
        final pin = _digits.join();
        final success = await SecurityService.instance.verifyPin(pin);
        if (success) {
          if (mounted) widget.onUnlocked();
        } else {
          if (mounted) {
            setState(() {
              _isError = true;
              _digits.clear();
              if (SecurityService.instance.isLockedOut) {
                _updateLockoutState();
              } else {
                _errorKey = 'lockIncorrectPin';
              }
            });
          }
        }
      }
    }
  }

  void _onBackspace() {
    if (_digits.isNotEmpty && !SecurityService.instance.isLockedOut) {
      setState(() {
        _digits.removeLast();
        _isError = false;
        _errorKey = null;
      });
    }
  }

  void _showEmergencyDialog() async {
    final s = S.of(context);
    final country = await Store.country();
    final hotlines = hotlinesForCountry(country);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.emergency, color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.t('lockEmergencyTitle'),
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                s.t('lockEmergencyBody'),
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ...hotlines.take(3).map((h) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(h.label,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(h.description),
                      trailing: h.number.isNotEmpty
                          ? FilledButton.icon(
                              icon: const Icon(Icons.phone, size: 16),
                              label: Text(h.number),
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red[700]),
                              onPressed: () =>
                                  launchUrl(Uri.parse('tel:${h.number}')),
                            )
                          : null,
                    ),
                  )),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(s.t('lockClose')),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final s = S.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 620;
            // Keys shrink on small phones and grow a little on tablets, but
            // never enough to clip the layout.
            final keySize = math
                .min(
                  constraints.maxWidth / 4.6,
                  constraints.maxHeight / (compact ? 10.5 : 9.5),
                )
                .clamp(44.0, Responsive.of(context, 68.0));
            final gap = (keySize * 0.2).clamp(8.0, 16.0);
            final logoSize = compact ? 56.0 : Responsive.of(context, 72.0);
            final dotSize = (keySize * 0.26).clamp(12.0, 18.0);

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.of(context, 16),
                vertical: 8,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0, constraints.maxHeight - 16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top section: emergency help, branding, dots and errors.
                    Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _showEmergencyDialog,
                            icon: Icon(
                              Icons.emergency,
                              color: Colors.redAccent,
                              size: Responsive.of(context, 20),
                            ),
                            label: Text(
                              s.t('lockSos'),
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 8 : 20),
                        Container(
                          width: logoSize,
                          height: logoSize,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.spa_rounded,
                            size: logoSize / 2,
                            color: primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Serene',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.t('lockEnterPin'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        SizedBox(height: compact ? 16 : 24),
                        // 4 Dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            final filled = index < _digits.length;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.symmetric(
                                  horizontal: dotSize * 0.55),
                              width: dotSize,
                              height: dotSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isError
                                    ? Colors.redAccent
                                    : (filled
                                        ? primary
                                        : primary.withValues(alpha: 0.18)),
                                border: Border.all(
                                  color: _isError ? Colors.redAccent : primary,
                                  width: 1.5,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 12),
                        // Error / lockout text
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            _errorText(s),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Bottom section: numeric keypad.
                    Column(
                      children: [
                        _buildRow(['1', '2', '3'], keySize, gap),
                        SizedBox(height: gap),
                        _buildRow(['4', '5', '6'], keySize, gap),
                        SizedBox(height: gap),
                        _buildRow(['7', '8', '9'], keySize, gap),
                        SizedBox(height: gap),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            SizedBox(
                              width: keySize,
                              height: keySize,
                              child: _hasBiometrics
                                  ? _buildBiometricButton(primary, keySize)
                                  : null,
                            ),
                            _buildKey('0', keySize),
                            SizedBox(
                              width: keySize,
                              height: keySize,
                              child: IconButton(
                                icon: Icon(
                                  Icons.backspace_outlined,
                                  size: keySize * 0.4,
                                ),
                                color: Colors.grey[700],
                                onPressed: _onBackspace,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 8 : 24),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBiometricButton(Color primary, double keySize) {
    if (_biometricBusy) {
      return Center(
        child: SizedBox(
          width: keySize * 0.45,
          height: keySize * 0.45,
          child: CircularProgressIndicator(strokeWidth: 2, color: primary),
        ),
      );
    }
    return IconButton(
      tooltip: S.of(context).t('lockBiometricTooltip'),
      icon: Icon(Icons.fingerprint, size: keySize * 0.5),
      color: primary,
      onPressed: () => _tryBiometrics(showError: true),
    );
  }

  Widget _buildRow(List<String> keys, double keySize, double gap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) => _buildKey(k, keySize)).toList(),
    );
  }

  Widget _buildKey(String label, double size) {
    return InkWell(
      onTap: () => _onDigit(label),
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
