import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n.dart';
import 'storage.dart';

String _today() => DateTime.now().toIso8601String().substring(0, 10);
const _faces = ['😞', '😕', '😐', '🙂', '😄'];

// ==========================================
// 1. MOOD CHECK-IN SCREEN
// ==========================================
class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});
  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  List<Map<String, dynamic>> _entries = [];
  int _rating = 3;
  final _noteController = TextEditingController();
  final Set<String> _selectedTags = {};

  final List<String> _availableTags = [
    'tagAnxiety',
    'tagWork',
    'tagFamily',
    'tagSleep',
    'tagLoneliness',
    'tagHope',
    'tagBurnout',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await Store.list('mood');
    if (mounted) setState(() => _entries = list);
  }

  Future<void> _save(S s) async {
    final entry = {
      'd': _today(),
      'v': _rating,
      'n': _noteController.text.trim(),
      'tags': _selectedTags.toList(),
    };
    _entries.add(entry);
    _noteController.clear();
    _selectedTags.clear();
    await Store.putList('mood', _entries);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.t('save')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final last14 = _entries.length > 14
        ? _entries.sublist(_entries.length - 14)
        : _entries;

    return Scaffold(
      appBar: AppBar(title: Text(s.t('checkin'))),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.t('howFeel'),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _rating = i),
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _rating == i
                                    ? theme.colorScheme.primaryContainer
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _rating == i
                                      ? theme.colorScheme.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              // Shrinks instead of overflowing on 320 px phones
                              // or when the system font size is very large.
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(_faces[i - 1],
                                    style: const TextStyle(fontSize: 32)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(s.t('moodTags'),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final tag in _availableTags)
                        FilterChip(
                          label: Text(s.t(tag)),
                          selected: _selectedTags.contains(tag),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTags.add(tag);
                              } else {
                                _selectedTags.remove(tag);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: s.t('note'),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(s.t('save')),
                      onPressed: () => _save(s),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(s.t('last'),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (last14.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(s.t('empty'),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline)),
              ),
            )
          else ...[
            Container(
              height: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final m in last14)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(_faces[(m['v'] as int) - 1],
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 4),
                          Container(
                            height: 18.0 * (m['v'] as int),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (m['d'] as String).substring(5),
                            style: theme.textTheme.labelSmall
                                ?.copyWith(fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ==========================================
// 2. GUIDED BREATHING STUDIO
// ==========================================
enum BreathingMode { calm, box, deepRest }

class BreatheScreen extends StatefulWidget {
  const BreatheScreen({super.key});
  @override
  State<BreatheScreen> createState() => _BreatheScreenState();
}

class _BreatheScreenState extends State<BreatheScreen>
    with TickerProviderStateMixin {
  BreathingMode _mode = BreathingMode.calm;
  bool _running = false;
  bool _soundEnabled = true;
  String _currentPhase = '';
  late AnimationController _animController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  void _changeMode(BreathingMode mode) {
    if (_running) _stop();
    setState(() => _mode = mode);
  }

  Future<void> _playSound(String assetName) async {
    if (!_soundEnabled || !_running) return;
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('audio/$assetName.wav'));
    } catch (_) {
      // Audio playback errors are non-blocking
    }
  }

  Future<void> _stopSound() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  Future<void> _runCycle() async {
    while (_running && mounted) {
      if (_mode == BreathingMode.calm) {
        // 4s Inhale, 6s Exhale
        setState(() => _currentPhase = 'inhale');
        _playSound('inhale');
        _animController.duration = const Duration(seconds: 4);
        await _animController.forward();
        if (!_running || !mounted) break;

        setState(() => _currentPhase = 'exhale');
        _playSound('exhale');
        _animController.duration = const Duration(seconds: 6);
        await _animController.reverse();
      } else if (_mode == BreathingMode.box) {
        // 4s In, 4s Hold, 4s Out, 4s Hold
        setState(() => _currentPhase = 'inhale');
        _playSound('inhale');
        _animController.duration = const Duration(seconds: 4);
        await _animController.forward();
        if (!_running || !mounted) break;

        setState(() => _currentPhase = 'hold');
        _stopSound();
        await Future.delayed(const Duration(seconds: 4));
        if (!_running || !mounted) break;

        setState(() => _currentPhase = 'exhale');
        _playSound('exhale');
        _animController.duration = const Duration(seconds: 4);
        await _animController.reverse();
        if (!_running || !mounted) break;

        setState(() => _currentPhase = 'hold');
        _stopSound();
        await Future.delayed(const Duration(seconds: 4));
      } else if (_mode == BreathingMode.deepRest) {
        // 4-7-8 Deep Rest
        setState(() => _currentPhase = 'inhale');
        _playSound('inhale');
        _animController.duration = const Duration(seconds: 4);
        await _animController.forward();
        if (!_running || !mounted) break;

        setState(() => _currentPhase = 'hold');
        _stopSound();
        await Future.delayed(const Duration(seconds: 7));
        if (!_running || !mounted) break;

        setState(() => _currentPhase = 'exhale');
        _playSound('exhale');
        _animController.duration = const Duration(seconds: 8);
        await _animController.reverse();
      }
    }
  }

  void _start() {
    setState(() => _running = true);
    _runCycle();
  }

  void _stop() {
    setState(() {
      _running = false;
      _currentPhase = '';
    });
    _stopSound();
    _animController.stop();
    _animController.reset();
  }

  @override
  void dispose() {
    _running = false;
    _stopSound();
    _audioPlayer.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('breathingStudio')),
        actions: [
          IconButton(
            icon: Icon(_soundEnabled ? Icons.volume_up : Icons.volume_off),
            tooltip: _soundEnabled ? 'Désactiver le son' : 'Activer le son',
            onPressed: () {
              setState(() => _soundEnabled = !_soundEnabled);
              if (!_soundEnabled) {
                _stopSound();
              } else if (_running &&
                  (_currentPhase == 'inhale' || _currentPhase == 'exhale')) {
                _playSound(_currentPhase);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxDiameter =
                (constraints.maxHeight * 0.35).clamp(130.0, 240.0);
            final minDiameter = maxDiameter * 0.52;

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Mode selector chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: Text(s.t('modeCalm')),
                              selected: _mode == BreathingMode.calm,
                              onSelected: (_) => _changeMode(BreathingMode.calm),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: Text(s.t('modeBox')),
                              selected: _mode == BreathingMode.box,
                              onSelected: (_) => _changeMode(BreathingMode.box),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: Text(s.t('mode478')),
                              selected: _mode == BreathingMode.deepRest,
                              onSelected: (_) =>
                                  _changeMode(BreathingMode.deepRest),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Animated breathing circle with soft glow
                      AnimatedBuilder(
                        animation: _animController,
                        builder: (_, __) {
                          final scale = minDiameter +
                              (maxDiameter - minDiameter) *
                                  _animController.value;
                          return Container(
                            width: scale,
                            height: scale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  primary.withValues(
                                      alpha: 0.15 +
                                          0.35 * _animController.value),
                                  primary.withValues(alpha: 0.05),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withValues(
                                      alpha: 0.2 * _animController.value),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: scale * 0.5,
                                height: scale * 0.5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: primary.withValues(
                                      alpha: 0.4 +
                                          0.3 * _animController.value),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _running && _currentPhase.isNotEmpty
                              ? s.t(_currentPhase)
                              : s.t('shieldQuote'),
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 20),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: Icon(_running
                                ? Icons.stop_circle_outlined
                                : Icons.play_circle_fill),
                            label: Text(_running ? s.t('stop') : s.t('start'),
                                style: const TextStyle(fontSize: 16)),
                            style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14)),
                            onPressed: _running ? _stop : _start,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ==========================================
// 3. 5-4-3-2-1 SENSORY GROUNDING EXERCISE
// ==========================================
class _GroundingStepConfig {
  final String titleKey;
  final String hintKey;
  final String senseNameKey;
  final String icon;
  final int count;
  final Color accentColor;
  final List<String> suggestions;

  const _GroundingStepConfig({
    required this.titleKey,
    required this.hintKey,
    required this.senseNameKey,
    required this.icon,
    required this.count,
    required this.accentColor,
    required this.suggestions,
  });
}

class GroundingScreen extends StatefulWidget {
  const GroundingScreen({super.key});
  @override
  State<GroundingScreen> createState() => _GroundingScreenState();
}

class _GroundingScreenState extends State<GroundingScreen>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0; // 0 to 4 (Step 5 down to 1), 5 is finished
  final Map<int, Set<int>> _acknowledged = {};
  bool _soundEnabled = true;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _pulseController;

  static const List<_GroundingStepConfig> _steps = [
    _GroundingStepConfig(
      titleKey: 'step5',
      hintKey: 'step5Hint',
      senseNameKey: 'senseSight',
      icon: '👀',
      count: 5,
      accentColor: Color(0xFF0D9488), // Teal
      suggestions: ['Lumière', 'Couleur', 'Objet', 'Plante', 'Ombre'],
    ),
    _GroundingStepConfig(
      titleKey: 'step4',
      hintKey: 'step4Hint',
      senseNameKey: 'senseTouch',
      icon: '✋',
      count: 4,
      accentColor: Color(0xFFD97706), // Warm Amber
      suggestions: ['Vêtements', 'Table / Surface', 'Pieds au sol', 'Air frais'],
    ),
    _GroundingStepConfig(
      titleKey: 'step3',
      hintKey: 'step3Hint',
      senseNameKey: 'senseHearing',
      icon: '👂',
      count: 3,
      accentColor: Color(0xFF6366F1), // Indigo
      suggestions: ['Bruit lointain', 'Respiration', 'Vent / Climatisation'],
    ),
    _GroundingStepConfig(
      titleKey: 'step2',
      hintKey: 'step2Hint',
      senseNameKey: 'senseSmell',
      icon: '👃',
      count: 2,
      accentColor: Color(0xFF059669), // Emerald
      suggestions: ['Air ambiant', 'Café / Parfum réconfortant'],
    ),
    _GroundingStepConfig(
      titleKey: 'step1',
      hintKey: 'step1Hint',
      senseNameKey: 'senseTaste',
      icon: '👅',
      count: 1,
      accentColor: Color(0xFFE11D48), // Rose
      suggestions: ['Gorgée d\'eau', 'Phrase bienveillante : "Je suis en sécurité"'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playChime() async {
    if (!_soundEnabled) return;
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('audio/chime.wav'));
    } catch (_) {}
  }

  void _toggleAnchor(int stepIndex, int anchorIndex) {
    HapticFeedback.mediumImpact();
    setState(() {
      final set = _acknowledged.putIfAbsent(stepIndex, () => <int>{});
      if (set.contains(anchorIndex)) {
        set.remove(anchorIndex);
      } else {
        set.add(anchorIndex);
        _playChime();
      }
    });
  }

  void _acknowledgeNextAnchor(int stepIndex, int totalCount) {
    final set = _acknowledged.putIfAbsent(stepIndex, () => <int>{});
    for (int i = 0; i < totalCount; i++) {
      if (!set.contains(i)) {
        _toggleAnchor(stepIndex, i);
        return;
      }
    }
  }

  void _goToStep(int step) {
    HapticFeedback.lightImpact();
    setState(() => _currentStep = step);
  }

  void _reset() {
    HapticFeedback.mediumImpact();
    setState(() {
      _currentStep = 0;
      _acknowledged.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final isFinished = _currentStep >= _steps.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('groundingTitle')),
        actions: [
          IconButton(
            icon: Icon(_soundEnabled ? Icons.volume_up : Icons.volume_off),
            tooltip: _soundEnabled ? 'Désactiver le son' : 'Activer le son',
            onPressed: () => setState(() => _soundEnabled = !_soundEnabled),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: s.t('restartExercise'),
            onPressed: _reset,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      (constraints.maxHeight - 32).clamp(0.0, double.infinity),
                ),
                child: IntrinsicHeight(
                  child: isFinished
                      ? _buildCompletionSanctuary(context, s, theme)
                      : _buildActiveGroundingStep(context, s, theme),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActiveGroundingStep(BuildContext context, S s, ThemeData theme) {
    final currentConfig = _steps[_currentStep];
    final checkedSet = _acknowledged[_currentStep] ?? const <int>{};
    final foundCount = checkedSet.length;
    final isAllFound = foundCount >= currentConfig.count;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Step Countdown Header Bar (5, 4, 3, 2, 1)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_steps.length, (idx) {
              final stepCfg = _steps[idx];
              final isCurrent = idx == _currentStep;
              final isPast = idx < _currentStep;
              final stepDone = (_acknowledged[idx]?.length ?? 0) >= stepCfg.count;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => _goToStep(idx),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? stepCfg.accentColor.withValues(alpha: 0.16)
                          : (isPast
                              ? theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5)
                              : Colors.transparent),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrent
                            ? stepCfg.accentColor
                            : (stepDone
                                ? stepCfg.accentColor.withValues(alpha: 0.4)
                                : theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.5)),
                        width: isCurrent ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(stepCfg.icon, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          '${stepCfg.count} ${s.t(stepCfg.senseNameKey)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isCurrent
                                ? stepCfg.accentColor
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (stepDone) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.check_circle,
                              size: 14, color: stepCfg.accentColor),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 16),

        // 2. Main Sense Showcase Card
        Card(
          elevation: 0,
          color: currentConfig.accentColor.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: currentConfig.accentColor.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Icon Avatar with glowing animation
                ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1.04).animate(
                    CurvedAnimation(
                        parent: _pulseController, curve: Curves.easeInOut),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: currentConfig.accentColor.withValues(alpha: 0.14),
                      boxShadow: [
                        BoxShadow(
                          color: currentConfig.accentColor.withValues(alpha: 0.2),
                          blurRadius: 18,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      currentConfig.icon,
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Sense Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: currentConfig.accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${currentConfig.count} • ${s.t(currentConfig.senseNameKey).toUpperCase()}',
                    style: TextStyle(
                      color: currentConfig.accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Instruction Title
                Text(
                  s.t(currentConfig.titleKey),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // Comforting hint
                Text(
                  s.t(currentConfig.hintKey),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 3. Interactive Anchor Touchpoints
        Text(
          s.t('groundingTapHint'),
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: List.generate(currentConfig.count, (idx) {
            final isChecked = checkedSet.contains(idx);
            return InkWell(
              onTap: () => _toggleAnchor(_currentStep, idx),
              borderRadius: BorderRadius.circular(30),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isChecked
                      ? currentConfig.accentColor
                      : currentConfig.accentColor.withValues(alpha: 0.1),
                  border: Border.all(
                    color: isChecked
                        ? currentConfig.accentColor
                        : currentConfig.accentColor.withValues(alpha: 0.4),
                    width: isChecked ? 2.5 : 1.5,
                  ),
                  boxShadow: isChecked
                      ? [
                          BoxShadow(
                            color: currentConfig.accentColor.withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: isChecked
                      ? const Icon(Icons.check, color: Colors.white, size: 28)
                      : Text(
                          '${idx + 1}',
                          style: TextStyle(
                            color: currentConfig.accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 12),

        // Live progress indicator & feedback
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isAllFound
                ? Container(
                    key: const ValueKey('all_found'),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: currentConfig.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            color: currentConfig.accentColor, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            s.t('allFound'),
                            style: TextStyle(
                              color: currentConfig.accentColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Text(
                    '$foundCount / ${currentConfig.count}',
                    key: ValueKey('count_$foundCount'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 16),

        // 4. Quick Inspiration Chips
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: currentConfig.suggestions.map((hint) {
            return ActionChip(
              avatar: Icon(Icons.touch_app_outlined,
                  size: 14, color: currentConfig.accentColor),
              label: Text(hint, style: const TextStyle(fontSize: 12)),
              backgroundColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.35),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
              onPressed: () =>
                  _acknowledgeNextAnchor(_currentStep, currentConfig.count),
            );
          }).toList(),
        ),

        const Spacer(),
        const SizedBox(height: 20),

        // 5. Navigation Action Bar
        Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () => _goToStep(_currentStep - 1),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(s.t('prevStep')),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                icon: Icon(_currentStep == _steps.length - 1
                    ? Icons.spa
                    : Icons.arrow_forward),
                label: Text(
                  _currentStep == _steps.length - 1
                      ? s.t('groundingDone')
                      : s.t('nextStep'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: isAllFound ? currentConfig.accentColor : null,
                ),
                onPressed: () => _goToStep(_currentStep + 1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompletionSanctuary(
      BuildContext context, S s, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.06).animate(
              CurvedAnimation(
                  parent: _pulseController, curve: Curves.easeInOut),
            ),
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 32,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: const Center(
                child: Text('🌿', style: TextStyle(fontSize: 54)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            s.t('groundingComplete'),
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold, height: 1.3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            '15 / 15 ancrages sensoriels complétés',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            icon: const Icon(Icons.air),
            label: Text(s.t('groundingBreatheBtn')),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BreatheScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: Text(s.t('restartExercise')),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            onPressed: _reset,
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. PRIVATE IN-MEMORY JOURNAL SCREEN
// ==========================================
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await Store.list('journal');
    if (mounted) setState(() => _entries = list);
  }

  Future<void> _addEntry(S s, [String? initialPrompt]) async {
    final controller = TextEditingController(
        text: initialPrompt != null ? '$initialPrompt\n\n' : '');
    final text = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.t('journal')),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 5,
          maxLines: 12,
          decoration: InputDecoration(
            hintText: s.t('writeHere'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.t('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(s.t('save')),
          ),
        ],
      ),
    );

    if (text != null && text.isNotEmpty) {
      _entries.insert(0, {'d': _today(), 't': text});
      await Store.putList('journal', _entries);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('journal'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addEntry(s),
        child: const Icon(Icons.edit_note),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Prompt suggestions
          Text(s.t('tagline'),
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.lightbulb_outline, size: 16),
                  label: Text(s.t('journalPrompt1')),
                  onPressed: () => _addEntry(s, s.t('journalPrompt1')),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.spa_outlined, size: 16),
                  label: Text(s.t('journalPrompt2')),
                  onPressed: () => _addEntry(s, s.t('journalPrompt2')),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.favorite_border, size: 16),
                  label: Text(s.t('journalPrompt3')),
                  onPressed: () => _addEntry(s, s.t('journalPrompt3')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_entries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  s.t('noEntries'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            )
          else
            for (var i = 0; i < _entries.length; i++)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_entries[i]['d'] ?? '',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: theme.colorScheme.primary)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () async {
                              _entries.removeAt(i);
                              await Store.putList('journal', _entries);
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
                      ),
                      Text(
                        _entries[i]['t'] ?? '',
                        style:
                            theme.textTheme.bodyMedium?.copyWith(height: 1.4),
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
