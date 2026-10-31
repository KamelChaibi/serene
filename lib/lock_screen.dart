import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'safety.dart';
import 'security_service.dart';
import 'storage.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  final List<String> _digits = [];
  bool _isError = false;
  String _errorMessage = '';
  Timer? _lockoutTimer;
  int _lockoutSeconds = 0;
  bool _hasBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricsAndPrompt();
    _updateLockoutState();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _updateLockoutState() {
    if (SecurityService.instance.isLockedOut) {
      setState(() {
        _lockoutSeconds = SecurityService.instance.remainingLockoutSeconds;
        _errorMessage = 'Too many attempts. Wait $_lockoutSeconds s';
      });
      _lockoutTimer?.cancel();
      _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        final rem = SecurityService.instance.remainingLockoutSeconds;
        setState(() {
          _lockoutSeconds = rem;
          if (rem <= 0) {
            _errorMessage = '';
            timer.cancel();
          } else {
            _errorMessage = 'Too many attempts. Wait $rem s';
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
      final ok = await SecurityService.instance.authenticateBiometrics(
        reason: 'Authenticate to access Serene',
      );
      if (ok && mounted) {
        widget.onUnlocked();
      }
    }
  }

  void _onDigit(String d) async {
    if (SecurityService.instance.isLockedOut) return;
    if (_digits.length < 4) {
      setState(() {
        _digits.add(d);
        _isError = false;
        _errorMessage = '';
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
                _errorMessage = 'Incorrect PIN';
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
        _errorMessage = '';
      });
    }
  }

  void _showEmergencyDialog() async {
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
                  Text(
                    'Emergency Crisis Hotlines',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Help is available 24/7. You do not have to carry this alone.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ...hotlines.take(3).map((h) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(h.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(h.description),
                      trailing: h.number.isNotEmpty
                          ? FilledButton.icon(
                              icon: const Icon(Icons.phone, size: 16),
                              label: Text(h.number),
                              style: FilledButton.styleFrom(backgroundColor: Colors.red[700]),
                              onPressed: () => launchUrl(Uri.parse('tel:${h.number}')),
                            )
                          : null,
                    ),
                  )),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
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

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top Emergency SOS Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _showEmergencyDialog,
                    icon: const Icon(Icons.emergency, color: Colors.redAccent),
                    label: const Text('SOS Help', style: TextStyle(color: Colors.redAccent)),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const Spacer(),
            // Brand Logo & Title
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.spa_rounded, size: 36, color: primary),
            ),
            const SizedBox(height: 16),
            Text(
              'سكينة • Serene',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your 4-digit PIN',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 28),
            // 4 Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final filled = index < _digits.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isError
                        ? Colors.redAccent
                        : (filled ? primary : primary.withValues(alpha: 0.18)),
                    border: Border.all(
                      color: _isError ? Colors.redAccent : primary,
                      width: 1.5,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            // Error / lockout text
            SizedBox(
              height: 24,
              child: _errorMessage.isNotEmpty
                  ? Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                    )
                  : null,
            ),
            const Spacer(),
            // Numeric Keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                children: [
                  _buildRow(['1', '2', '3']),
                  const SizedBox(height: 14),
                  _buildRow(['4', '5', '6']),
                  const SizedBox(height: 14),
                  _buildRow(['7', '8', '9']),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Biometric button (if available)
                      _hasBiometrics
                          ? IconButton(
                              icon: const Icon(Icons.fingerprint, size: 32),
                              color: primary,
                              onPressed: () => SecurityService.instance.authenticateBiometrics(),
                            )
                          : const SizedBox(width: 64, height: 64),
                      _buildKey('0'),
                      IconButton(
                        icon: const Icon(Icons.backspace_outlined, size: 26),
                        color: Colors.grey[700],
                        onPressed: _onBackspace,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) => _buildKey(k)).toList(),
    );
  }

  Widget _buildKey(String label) {
    return InkWell(
      onTap: () => _onDigit(label),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 68,
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

