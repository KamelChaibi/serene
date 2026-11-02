import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_service.dart';
import 'features.dart';
import 'l10n.dart';
import 'notification_service.dart';
import 'onboarding.dart';
import 'profile.dart';
import 'pwa_install_card.dart';
import 'responsive.dart';
import 'safety.dart';
import 'security_service.dart';
import 'storage.dart';
import 'theme_service.dart';
import 'live_voice_call_screen.dart';
import 'voice_settings.dart';
import 'wellness.dart';

class ChatScreen extends StatefulWidget {
  final void Function(Locale) onLocale;
  const ChatScreen({super.key, required this.onLocale});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Msg> _messages = []; // Ephemeral in RAM only
  bool _isBusy = false;
  bool _shieldActive = false;
  String _selectedCountry = 'TN';
  Map<String, String>? _trustedContact;
  Profile _profile = Profile.empty;
  List<String> _memories = [];
  bool _useMemories = true;
  StreamSubscription<ChatStreamChunk>? _currentStreamSub;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _currentStreamSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final c = await Store.country();
    final contact = await Store.trustedContact();
    final profile = await Store.profile();
    final useMem = await Store.useMem();
    final memories = useMem ? await Store.memories() : <String>[];
    if (mounted) {
      setState(() {
        _selectedCountry = c;
        _trustedContact = contact;
        _profile = profile;
        _useMemories = useMem;
        _memories = memories;
      });
    }
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        // Jumping avoids restarting an animation on every incoming token,
        // which would otherwise make the text trail behind the scroll.
        _scrollController.jumpTo(target);
      }
    });
  }

  void _stopGenerating() {
    _currentStreamSub?.cancel();
    _currentStreamSub = null;
    if (mounted) {
      setState(() => _isBusy = false);
    }
  }

  Future<void> _startVoiceCall() async {
    // A text reply in flight and a live call would interleave badly.
    if (_isBusy) return;
    final language = S.of(context).code;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveVoiceCallScreen(
          conversation: _messages,
          profile: _profile,
          memories: _useMemories ? _memories : const <String>[],
          appLanguage: language,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _send([String? customText]) async {
    final s = S.of(context);
    final text = (customText ?? _controller.text).trim();
    if (text.isEmpty || _isBusy) return;

    _controller.clear();
    setState(() => _messages.add(Msg('user', text)));
    _scrollToBottom();

    // 1. First-line on-device crisis regex detection
    if (isCrisis(text)) {
      _showCrisisModal(s);
      return;
    }

    setState(() => _isBusy = true);
    final assistantMsg = Msg('assistant', '');
    setState(() => _messages.add(assistantMsg));
    _scrollToBottom();

    try {
      // Memories are cached at load time so sending never waits on secure
      // storage before the first token can arrive.
      final memories = _useMemories ? _memories : <String>[];
      final stream = askStream(_messages, s.code, memories, profile: _profile);

      _currentStreamSub = stream.listen(
        (chunk) {
          if (!mounted) return;
          if (chunk.token.isNotEmpty) {
            setState(() {
              assistantMsg.text += chunk.token;
            });
            _scrollToBottom(animate: false);
          }
          if (chunk.isCrisis) {
            _showCrisisModal(s);
          }
          if (chunk.isDone) {
            if (chunk.memorySuggestion != null &&
                chunk.memorySuggestion!.isNotEmpty) {
              setState(() {
                assistantMsg.memorySuggestion = chunk.memorySuggestion;
              });
            }
          }
        },
        onError: (_) {
          if (mounted) {
            setState(() {
              if (assistantMsg.text.isEmpty) {
                assistantMsg.text = s.t('error');
              }
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() => _isBusy = false);
          }
        },
      );

      await _currentStreamSub?.asFuture();
    } catch (_) {
      if (mounted && assistantMsg.text.isEmpty) {
        setState(() => assistantMsg.text = s.t('error'));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showCrisisModal(S s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final list = hotlinesForCountry(_selectedCountry);
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, scrollController) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.emergency,
                            color: Colors.red, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s.t('crisisTitle'),
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[800],
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.t('crisisSubtitle'),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 16),

                  // Call Trusted Contact Card (if set)
                  if (_trustedContact != null)
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.favorite, color: Colors.red),
                        title: Text(
                          '${s.t('trustedContact')}: ${_trustedContact!['name']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(_trustedContact!['phone']!),
                        trailing: FilledButton.icon(
                          icon: const Icon(Icons.phone),
                          label: Text(s.t('call')),
                          onPressed: () => launchUrl(
                              Uri.parse('tel:${_trustedContact!['phone']}')),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        s.t('noTrustedContact'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                  const Divider(height: 24),

                  // Country Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          s.t('selectCountry'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedCountry,
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => _selectedCountry = val);
                            setState(() => _selectedCountry = val);
                            Store.setCountry(val);
                          }
                        },
                        items: supportedCountries.entries.map((e) {
                          return DropdownMenuItem(
                              value: e.key, child: Text(e.value));
                        }).toList(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Emergency Hotlines List
                  ...list.map((h) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      h.label,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    if (h.description.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          h.description,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ),
                                    if (h.number.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          h.number,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (h.url != null)
                                TextButton(
                                  onPressed: () => launchUrl(Uri.parse(h.url!)),
                                  child: Text(s.t('visitWebsite')),
                                )
                              else if (h.number.isNotEmpty)
                                FilledButton.icon(
                                  icon: const Icon(Icons.phone, size: 18),
                                  label: Text(s.t('call')),
                                  onPressed: () =>
                                      launchUrl(Uri.parse('tel:${h.number}')),
                                ),
                            ],
                          ),
                        ),
                      )),

                  const SizedBox(height: 16),

                  // Immediate Grounding & Breathing Shortcut
                  OutlinedButton.icon(
                    icon: const Icon(Icons.air),
                    label: Text(s.t('crisisBreathing')),
                    onPressed: () {
                      Navigator.pop(ctx);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        builder: (_) => const FractionallySizedBox(
                          heightFactor: 0.88,
                          child: ClipRRect(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24)),
                            child: BreatheScreen(),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(s.t('close')),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);

    // Quick Privacy Shield Mode
    if (_shieldActive) {
      return GestureDetector(
        onTap: () => setState(() => _shieldActive = false),
        child: Scaffold(
          backgroundColor: const Color(0xFF131816),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.spa, size: 54, color: Color(0xFF356B60)),
                  const SizedBox(height: 24),
                  Text(
                    s.t('shieldQuote'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      height: 1.6,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    s.t('shieldActivated'),
                    style: const TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.spa, size: 18, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                s.t('title'),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          // Voice call: hands-free talking with Serene. Hidden while the
          // self-hosted voice stack cannot run on the available hardware;
          // flip `voiceCallsVisible` in features.dart to restore it.
          if (voiceCallsVisible)
            IconButton(
              tooltip: s.t('voiceCall'),
              icon: Icon(Icons.call_outlined, color: theme.colorScheme.primary),
              onPressed: _startVoiceCall,
            ),
          // Emergency Crisis Hotline Icon
          IconButton(
            tooltip: s.t('crisisTitle'),
            icon: const Icon(Icons.emergency, color: Colors.redAccent),
            onPressed: () => _showCrisisModal(s),
          ),
          // Quick Privacy Shield Button
          IconButton(
            tooltip: s.t('privacyShield'),
            icon: const Icon(Icons.shield_outlined),
            onPressed: () => setState(() => _shieldActive = true),
          ),
          // Language Switch
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: (code) => widget.onLocale(Locale(code)),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'ar', child: Text('العربية')),
              PopupMenuItem(value: 'fr', child: Text('Français')),
              PopupMenuItem(value: 'en', child: Text('English')),
            ],
          ),
          // Settings & App Lock & Memories
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MemorySettingsScreen()),
            ).then((_) => _loadPreferences()),
          ),
        ],
      ),
      body: Column(
        children: [
          // Gentle non-clinical boundary disclaimer banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.t('disclaimer'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.info_outline,
                    size: 16, color: theme.colorScheme.outline),
              ],
            ),
          ),

          // Chat message list
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.favorite_border,
                                size: 40, color: theme.colorScheme.primary),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _profile.trimmedName.isEmpty
                                ? s.t('tagline')
                                : s
                                    .t('greetName')
                                    .replaceAll('{name}', _profile.trimmedName),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          if (_profile.trimmedName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              s.t('tagline'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          if (voiceCallsVisible) ...[
                            const SizedBox(height: 24),
                            FilledButton.tonalIcon(
                              onPressed: () => _startVoiceCall(),
                              icon: const Icon(Icons.call_outlined, size: 18),
                              label: Text(s.t('voiceCall')),
                            ),
                            const SizedBox(height: 16),
                          ],
                          ActionChip(
                            label: Text(s.t('promptOverwhelmed')),
                            onPressed: () => _send(s.t('promptOverwhelmed')),
                          ),
                          const SizedBox(height: 8),
                          ActionChip(
                            label: Text(s.t('promptSleep')),
                            onPressed: () => _send(s.t('promptSleep')),
                          ),
                          const SizedBox(height: 8),
                          ActionChip(
                            label: Text(s.t('promptLonely')),
                            onPressed: () => _send(s.t('promptLonely')),
                          ),
                          const SizedBox(height: 8),
                          ActionChip(
                            label: Text(s.t('promptCalm')),
                            onPressed: () => _send(s.t('promptCalm')),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(14),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      final isUser = m.role == 'user';
                      return Column(
                        crossAxisAlignment: isUser
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: isUser
                                ? AlignmentDirectional.centerEnd
                                : AlignmentDirectional.centerStart,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.82,
                              ),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.secondaryContainer
                                        .withValues(alpha: 0.7),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: isUser
                                      ? const Radius.circular(18)
                                      : const Radius.circular(4),
                                  bottomRight: isUser
                                      ? const Radius.circular(4)
                                      : const Radius.circular(18),
                                ),
                              ),
                              child: Text(
                                m.text.isEmpty && _isBusy && !isUser
                                    ? '...'
                                    : m.text,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.45,
                                  color: isUser
                                      ? theme.colorScheme.onPrimaryContainer
                                      : theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ),

                          // Automatic Memory Suggestion with explicit user approval
                          if (!isUser &&
                              m.memorySuggestion != null &&
                              m.memorySuggestion!.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4, bottom: 8),
                              padding: const EdgeInsets.all(12),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.85,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.lightbulb_outline,
                                          size: 18,
                                          color: theme.colorScheme.primary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          s.t('memorySuggestionTitle'),
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    m.memorySuggestion!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          setState(
                                              () => m.memorySuggestion = null);
                                        },
                                        child: Text(s.t('dismiss')),
                                      ),
                                      const SizedBox(width: 6),
                                      FilledButton.tonalIcon(
                                        icon: const Icon(Icons.check, size: 16),
                                        label: Text(s.t('remember')),
                                        onPressed: () async {
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          final suggestion =
                                              m.memorySuggestion!;
                                          if (!_memories.contains(suggestion)) {
                                            _memories.add(suggestion);
                                            await Store.save(_memories);
                                          }
                                          if (mounted) {
                                            setState(() =>
                                                m.memorySuggestion = null);
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content:
                                                    Text(s.t('memorySaved')),
                                                duration:
                                                    const Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),

          if (_isBusy)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(s.t('thinking'), style: theme.textTheme.labelSmall),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.stop_circle_outlined,
                        size: 18, color: Colors.grey),
                    label: Text(s.t('stopGenerating'),
                        style: const TextStyle(color: Colors.grey)),
                    onPressed: _stopGenerating,
                  ),
                ],
              ),
            ),

          // Message input bar
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: s.t('hint'),
                        hintStyle: TextStyle(color: theme.colorScheme.outline),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send_rounded),
                    onPressed: _isBusy ? null : () => _send(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// SETTINGS: PIN LOCK, REMINDERS, MEMORIES
// ==========================================
class MemorySettingsScreen extends StatefulWidget {
  const MemorySettingsScreen({super.key});
  @override
  State<MemorySettingsScreen> createState() => _MemorySettingsScreenState();
}

class _MemorySettingsScreenState extends State<MemorySettingsScreen> {
  final _memoryInput = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();

  List<String> _memories = [];
  bool _useMemories = true;
  String _selectedCountry = 'TN';
  bool _hasTrustedContact = false;
  Profile _profile = Profile.empty;
  ThemeMode _themeMode = ThemeService.instance.mode;

  // Security Lock
  bool _hasPinLock = false;
  bool _biometricsEnabled = false;
  bool _canUseBiometrics = false;
  bool _hasBiometricHardware = false;

  // Reminders
  bool _dailyReminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final m = await Store.memories();
    final u = await Store.useMem();
    final c = await Store.country();
    final contact = await Store.trustedContact();
    final profile = await Store.profile();

    final pinEnabled = await SecurityService.instance.isLockEnabled();
    final bioEnabled = await SecurityService.instance.isBiometricsEnabled();

    final remEnabled = await NotificationService.instance.isReminderEnabled();
    final remTime = await NotificationService.instance.getReminderTime();

    if (mounted) {
      setState(() {
        _memories = m;
        _useMemories = u;
        _selectedCountry = c;
        _profile = profile;
        if (contact != null) {
          _hasTrustedContact = true;
          _contactName.text = contact['name'] ?? '';
          _contactPhone.text = contact['phone'] ?? '';
        }
        _hasPinLock = pinEnabled;
        _biometricsEnabled = bioEnabled;
        _dailyReminderEnabled = remEnabled;
        _reminderTime =
            TimeOfDay(hour: remTime['hour']!, minute: remTime['minute']!);
      });
    }

    // The biometric platform query can be slow, or never answer at all on some
    // OEM builds. Resolve it after the rest of the screen is already usable so
    // a stuck sensor can never hide the PIN or reminder settings.
    final canBio = await SecurityService.instance.canUseBiometrics();
    final hasBioHardware =
        await SecurityService.instance.hasBiometricHardware();
    if (mounted) {
      setState(() {
        _canUseBiometrics = canBio;
        _hasBiometricHardware = hasBioHardware;
      });
    }
  }

  void _setTheme(ThemeMode mode) {
    setState(() => _themeMode = mode);
    ThemeService.instance.setMode(mode);
  }

  String _profileSummary(S s) {
    final parts = <String>[];
    if (_profile.trimmedName.isNotEmpty) parts.add(_profile.trimmedName);
    final age = _profile.age;
    if (age != null) parts.add(s.t('ageYears').replaceAll('{age}', '$age'));
    switch (_profile.style) {
      case Profile.styleFriend:
        parts.add(s.t('styleFriend'));
        break;
      case Profile.styleDirect:
        parts.add(s.t('styleDirect'));
        break;
      default:
        parts.add(s.t('styleWarm'));
    }
    return parts.join(' · ');
  }

  Future<void> _editProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => OnboardingScreen(
          isEditing: true,
          onDone: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
    if (mounted) _loadAll();
  }

  Future<void> _setupPinDialog(S s) async {
    final pin1Ctrl = TextEditingController();
    final pin2Ctrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(s.t('enterNewPin')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pin1Ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: InputDecoration(labelText: s.t('pinLock')),
            ),
            TextField(
              controller: pin2Ctrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: InputDecoration(labelText: s.t('confirmPin')),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(s.t('cancel'))),
          FilledButton(
            onPressed: () async {
              final p1 = pin1Ctrl.text.trim();
              final p2 = pin2Ctrl.text.trim();
              // Capture navigator and messenger before any await
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              if (RegExp(r'^\d{4}$').hasMatch(p1) && p1 == p2) {
                await SecurityService.instance.setupPin(p1);
                if (!mounted) return;
                nav.pop();
                await _loadAll();
                messenger.showSnackBar(
                  SnackBar(content: Text(s.t('pinSetSuccess'))),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(content: Text(s.t('pinMismatch'))),
                );
              }
            },
            child: Text(s.t('save')),
          ),
        ],
      ),
    );
  }

  Future<void> _removePin(S s) async {
    await SecurityService.instance.removePin();
    _loadAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('pinRemoved'))),
      );
    }
  }

  /// Biometric unlock is only switched on after the device actually proves it
  /// can authenticate. Otherwise the lock screen would offer a button that can
  /// never unlock the app.
  Future<void> _toggleBiometrics(bool enabled, S s) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!enabled) {
      await SecurityService.instance.setBiometricsEnabled(false);
      if (mounted) await _loadAll();
      return;
    }

    final ok = await SecurityService.instance.verifyBiometrics(
      reason: s.t('biometricsPrompt'),
    );
    if (!mounted) return;
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(s.t('biometricsFailed'))),
      );
      return;
    }
    await SecurityService.instance.setBiometricsEnabled(true);
    if (mounted) await _loadAll();
  }

  Future<void> _toggleDailyReminder(bool enabled, S s) async {
    final messenger = ScaffoldMessenger.of(context);
    if (enabled) {
      final granted = await NotificationService.instance.requestPermission();
      if (!mounted) return;
      if (!granted) {
        messenger.showSnackBar(
          SnackBar(content: Text(s.t('notificationsBlocked'))),
        );
        return;
      }
      try {
        await NotificationService.instance.scheduleDailyCheckIn(
          hour: _reminderTime.hour,
          minute: _reminderTime.minute,
          title: s.t('title'),
          body: s.t('tagline'),
        );
      } catch (_) {
        // Do not flip the switch on if nothing was actually scheduled.
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(s.t('notificationsFailed'))),
          );
        }
        return;
      }
    } else {
      try {
        await NotificationService.instance.cancelAll();
      } catch (_) {
        // The switch still reflects the user's intent for this session.
      }
    }
    if (mounted) await _loadAll();
  }

  Future<void> _pickReminderTime(S s) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked == null || !mounted) return;
    setState(() => _reminderTime = picked);
    if (_dailyReminderEnabled) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await NotificationService.instance.scheduleDailyCheckIn(
          hour: picked.hour,
          minute: picked.minute,
          title: s.t('title'),
          body: s.t('tagline'),
        );
      } catch (_) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(s.t('notificationsFailed'))),
          );
        }
      }
    }
  }

  Future<void> _saveContact(S s) async {
    final name = _contactName.text.trim();
    final phone = _contactPhone.text.trim();
    if (name.isNotEmpty && phone.isNotEmpty) {
      await Store.setTrustedContact(name, phone);
      setState(() => _hasTrustedContact = true);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.t('saveContact'))));
      }
    }
  }

  Future<void> _removeContact(S s) async {
    await Store.removeTrustedContact();
    _contactName.clear();
    _contactPhone.clear();
    setState(() => _hasTrustedContact = false);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.t('removeContact'))));
    }
  }

  Future<void> _wipeData(S s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.t('wipe')),
        content: Text(s.t('wipeConfirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.t('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.t('confirm')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Store.wipe();
      await SecurityService.instance.removePin();
      try {
        await NotificationService.instance.cancelAll();
      } catch (_) {
        // Nothing scheduled, or notifications are unavailable.
      }
      setState(() {
        _memories = [];
        _hasTrustedContact = false;
        _contactName.clear();
        _contactPhone.clear();
        _hasPinLock = false;
        _biometricsEnabled = false;
        _dailyReminderEnabled = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.t('wipeDone'))),
        );
      }
    }
  }

  @override
  void dispose() {
    _memoryInput.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('settings'))),
      body: Responsive.centered(
        maxWidth: 760,
        child: ListView(
          padding: EdgeInsets.all(Responsive.of(context, 16)),
          children: [
            // 0. Personal profile collected during onboarding
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.t('profileCardTitle'),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(s.t('profileCardDesc'),
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _profileSummary(s),
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: Text(s.t('editProfile')),
                          onPressed: _editProfile,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Appearance: system, light, or dark
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.brightness_6_outlined,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.t('appearance'),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(s.t('appearanceDesc'),
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          avatar: Icon(
                            Icons.brightness_auto_outlined,
                            size: 18,
                            color: _themeMode == ThemeMode.system
                                ? theme.colorScheme.primary
                                : null,
                          ),
                          label: Text(s.t('themeSystem')),
                          selected: _themeMode == ThemeMode.system,
                          onSelected: (_) => _setTheme(ThemeMode.system),
                        ),
                        ChoiceChip(
                          avatar: Icon(
                            Icons.light_mode_outlined,
                            size: 18,
                            color: _themeMode == ThemeMode.light
                                ? theme.colorScheme.primary
                                : null,
                          ),
                          label: Text(s.t('themeLight')),
                          selected: _themeMode == ThemeMode.light,
                          onSelected: (_) => _setTheme(ThemeMode.light),
                        ),
                        ChoiceChip(
                          avatar: Icon(
                            Icons.dark_mode_outlined,
                            size: 18,
                            color: _themeMode == ThemeMode.dark
                                ? theme.colorScheme.primary
                                : null,
                          ),
                          label: Text(s.t('themeDark')),
                          selected: _themeMode == ThemeMode.dark,
                          onSelected: (_) => _setTheme(ThemeMode.dark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (voiceCallsVisible) ...[
              const SizedBox(height: 16),

              // Voice call configuration (self-hosted server, language, captions)
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Icon(
                    Icons.call_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    s.t('voiceSettings'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    s.t('voiceServerUrlDesc'),
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VoiceSettingsScreen(),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],

            // iOS has no automatic install prompt; offer the manual steps.
            const PwaInstallCard(),

            // 1. PIN & Biometrics Security Section
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock_outline,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.t('securityLock'),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(s.t('securityDesc'), style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.t('pinLock'),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          _hasPinLock ? s.t('pinActive') : s.t('pinDisabled')),
                      trailing: _hasPinLock
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () => _setupPinDialog(s),
                                  child: Text(s.t('changePin')),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent),
                                  onPressed: () => _removePin(s),
                                ),
                              ],
                            )
                          : FilledButton.tonal(
                              onPressed: () => _setupPinDialog(s),
                              child: Text(s.t('enablePin')),
                            ),
                    ),
                    if (_hasPinLock) ...[
                      const Divider(),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.t('biometrics')),
                        subtitle: Text(
                          !_hasBiometricHardware
                              ? s.t('biometricsUnavailable')
                              : !_canUseBiometrics
                                  ? s.t('biometricsNotEnrolled')
                                  : s.t('biometricsDesc'),
                        ),
                        value: _biometricsEnabled,
                        onChanged: _canUseBiometrics
                            ? (v) => _toggleBiometrics(v, s)
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 2. Mindful Daily Reminders & Notifications
            // The web build cannot schedule native local notifications, so
            // this section is only offered on Android/iOS.
            if (!kIsWeb)
              Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notifications_active_outlined,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.t('reminders'),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(s.t('remindersDesc'),
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.t('dailyReminder')),
                      value: _dailyReminderEnabled,
                      onChanged: (v) => _toggleDailyReminder(v, s),
                    ),
                    if (_dailyReminderEnabled) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.t('reminderTime')),
                        trailing: TextButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: Text(_reminderTime.format(context)),
                          onPressed: () => _pickReminderTime(s),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.send),
                      label: Text(s.t('testNotification')),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final granted = await NotificationService.instance
                            .requestPermission();
                        if (!mounted) return;
                        if (!granted) {
                          messenger.showSnackBar(
                            SnackBar(
                                content: Text(s.t('notificationsBlocked'))),
                          );
                          return;
                        }
                        try {
                          await NotificationService.instance.showInstantCheckIn(
                            title: s.t('title'),
                            body: s.t('tagline'),
                          );
                        } catch (_) {
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                  content: Text(s.t('notificationsFailed'))),
                            );
                          }
                          return;
                        }
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(s.t('notificationSent'))),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. Emergency Trusted Contact Section
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.emergency_outlined,
                            color: Colors.redAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.t('trustedTitle'),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(s.t('trustedDesc'), style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contactName,
                      decoration: InputDecoration(
                        labelText: s.t('contactName'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _contactPhone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: s.t('contactPhone'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () => _saveContact(s),
                            child: Text(s.t('saveContact')),
                          ),
                        ),
                        if (_hasTrustedContact) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => _removeContact(s),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 4. Country Hotline Preference
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.t('selectCountry'),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _selectedCountry,
                      isExpanded: true,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCountry = val);
                          Store.setCountry(val);
                        }
                      },
                      items: supportedCountries.entries.map((e) {
                        return DropdownMenuItem(
                            value: e.key, child: Text(e.value));
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 5. Memory Management
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.t('memories'),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.t('useMem'),
                          style: theme.textTheme.bodyMedium),
                      value: _useMemories,
                      onChanged: (v) {
                        setState(() => _useMemories = v);
                        Store.setUseMem(v);
                      },
                    ),
                    TextField(
                      controller: _memoryInput,
                      decoration: InputDecoration(
                        hintText: s.t('memHint'),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () async {
                            final text = _memoryInput.text.trim();
                            if (text.isNotEmpty) {
                              _memories.add(text);
                              _memoryInput.clear();
                              await Store.save(_memories);
                              setState(() {});
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_memories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(s.t('empty'),
                            style: theme.textTheme.bodySmall),
                      )
                    else
                      for (var i = 0; i < _memories.length; i++)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(_memories[i]),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () async {
                              _memories.removeAt(i);
                              await Store.save(_memories);
                              setState(() {});
                            },
                          ),
                        ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Complete wipe button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.delete_forever),
              label: Text(s.t('wipe')),
              onPressed: () => _wipeData(s),
            ),
          ],
        ),
      ),
    );
  }
}
