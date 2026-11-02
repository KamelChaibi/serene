import 'package:flutter/material.dart';

import 'l10n.dart';
import 'voice_api.dart';

/// Lets the user point the app at their own voice backend.
///
/// This is a self-hosted product, so there is no "our server" to hard-code:
/// the address, the optional enrolment code, and the call language all belong
/// to the person running the stack.
class VoiceSettingsScreen extends StatefulWidget {
  /// Injectable for tests.
  final VoiceApi? api;

  const VoiceSettingsScreen({super.key, this.api});

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  late final VoiceApi _api = widget.api ?? VoiceApi();
  final _serverController = TextEditingController();
  final _codeController = TextEditingController();

  String _language = 'auto';
  bool _captions = true;
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _saved = false;
  VoiceHealth? _health;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _codeController.dispose();
    if (widget.api == null) _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    final url = await _api.serverUrl();
    final code = await _api.enrollmentCode();
    final language = await _api.languagePreference();
    final captions = await _api.captionsEnabled();
    if (!mounted) return;
    setState(() {
      _serverController.text = url;
      _codeController.text = code;
      _language = language;
      _captions = captions;
      _loading = false;
    });
  }

  bool _validServer(String raw) {
    final normalized = VoiceApi.normalizeServerUrl(raw);
    final uri = Uri.tryParse(normalized);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Future<bool> _persist() async {
    final s = S.of(context);
    if (!_validServer(_serverController.text)) {
      setState(() {
        _error = s.t('voiceServerUrlInvalid');
        _saved = false;
      });
      return false;
    }

    setState(() {
      _saving = true;
      _error = null;
      _saved = false;
    });

    await _api.setServerUrl(_serverController.text);
    await _api.setEnrollmentCode(_codeController.text);
    await _api.setLanguagePreference(_language);

    if (!mounted) return false;
    final resolved = await _api.serverUrl();
    setState(() {
      _saving = false;
      _saved = true;
      _serverController.text = resolved;
    });
    return true;
  }

  Future<void> _test() async {
    final s = S.of(context);
    final saved = await _persist();
    if (!saved || !mounted) return;

    setState(() {
      _testing = true;
      _health = null;
    });
    final health = await _api.checkHealth();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _health = health;
      _saved = false;
      if (!health.reachable) _error = s.t('voiceTestFail');
    });
  }

  Future<void> _setCaptions(bool value) async {
    setState(() => _captions = value);
    await _api.setCaptionsEnabled(value);
  }

  Future<void> _forgetDevice() async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.t('voiceResetDevice')),
        content: Text(s.t('voiceResetDeviceDesc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.t('voiceResetDevice')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _api.forgetDevice();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.t('voiceResetDone'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('voiceSettings'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _card(
                  theme,
                  icon: Icons.dns_outlined,
                  title: s.t('voiceServerUrl'),
                  children: [
                    Text(
                      s.t('voiceServerUrlDesc'),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _serverController,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: 'http://192.168.1.10:8788',
                        errorText: _error,
                      ),
                      onChanged: (_) {
                        if (_saved) setState(() => _saved = false);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _card(
                  theme,
                  icon: Icons.vpn_key_outlined,
                  title: s.t('voiceEnrollmentCode'),
                  children: [
                    Text(
                      s.t('voiceEnrollmentCodeDesc'),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codeController,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _card(
                  theme,
                  icon: Icons.translate_rounded,
                  title: s.t('voiceLanguage'),
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _language,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'auto',
                          child: Text(s.t('voiceLanguageAuto')),
                        ),
                        const DropdownMenuItem(
                          value: 'en',
                          child: Text('English'),
                        ),
                        const DropdownMenuItem(
                          value: 'fr',
                          child: Text('Français'),
                        ),
                        const DropdownMenuItem(
                          value: 'ar',
                          child: Text('العربية'),
                        ),
                        DropdownMenuItem(
                          value: 'tn',
                          child: Text(s.t('voiceLanguageTunisian')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _language = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _card(
                  theme,
                  icon: Icons.subtitles_outlined,
                  title: s.t('voiceCaptions'),
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        s.t('voiceCaptions'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        s.t('voiceCaptionsDesc'),
                        style: theme.textTheme.bodySmall,
                      ),
                      value: _captions,
                      onChanged: _setCaptions,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _persist,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text(s.t('voiceSave')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _testing ? null : _test,
                        icon: _testing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_tethering_rounded,
                                size: 18),
                        label: Text(
                          _testing
                              ? s.t('voiceTesting')
                              : s.t('voiceTestConnection'),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_saved) ...[
                  const SizedBox(height: 12),
                  _banner(
                    theme,
                    color: theme.colorScheme.primary,
                    icon: Icons.check_circle_outline,
                    text: s.t('voiceSaved'),
                  ),
                ],
                if (_health != null) ...[
                  const SizedBox(height: 12),
                  _healthBanner(theme, s, _health!),
                ],
                const SizedBox(height: 24),
                _card(
                  theme,
                  icon: Icons.link_off_rounded,
                  title: s.t('voiceResetDevice'),
                  children: [
                    Text(
                      s.t('voiceResetDeviceDesc'),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _forgetDevice,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(s.t('voiceResetDevice')),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _card(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _healthBanner(ThemeData theme, S s, VoiceHealth health) {
    if (!health.reachable) {
      return _banner(
        theme,
        color: theme.colorScheme.error,
        icon: Icons.error_outline,
        text: s.t('voiceTestFail'),
      );
    }
    if (health.ready) {
      return _banner(
        theme,
        color: theme.colorScheme.primary,
        icon: Icons.check_circle_outline,
        text: s.t('voiceTestOk'),
      );
    }
    return _banner(
      theme,
      color: const Color(0xFFB8860B),
      icon: Icons.warning_amber_rounded,
      text: s.t('voiceTestDegraded'),
    );
  }

  Widget _banner(
    ThemeData theme, {
    required Color color,
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
