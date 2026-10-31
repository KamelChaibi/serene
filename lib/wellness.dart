import 'package:flutter/material.dart';
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
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.t('howFeel'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (var i = 1; i <= 5; i++)
                        InkWell(
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
                            child: Text(_faces[i - 1], style: const TextStyle(fontSize: 32)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(s.t('moodTags'), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
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
          Text(s.t('last'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (last14.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(s.t('empty'), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
              ),
            )
          else ...[
            Container(
              height: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                          Text(_faces[(m['v'] as int) - 1], style: const TextStyle(fontSize: 14)),
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
                            style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
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

class _BreatheScreenState extends State<BreatheScreen> with TickerProviderStateMixin {
  BreathingMode _mode = BreathingMode.calm;
  bool _running = false;
  String _currentPhase = '';
  late AnimationController _animController;

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

  Future<void> _runCycle() async {
    while (_running && mounted) {
      if (_mode == BreathingMode.calm) {
        // 4s Inhale, 6s Exhale
        setState(() => _currentPhase = 'inhale');
        _animController.duration = const Duration(seconds: 4);
        await _animController.forward();
        if (!_running || !mounted) break;

        setState(() => _currentPhase = 'exhale');
        _animController.duration = const Duration(seconds: 6);
        await _animController.reverse();
      } else if (_mode == BreathingMode.box) {
        // 4s In, 4s Hold, 4s Out, 4s Hold
        setState(() => _currentPhase = 'inhale');
        _animController.duration = const Duration(seconds: 4);
        await _animController.forward();
        if (!_running || !mounted) break;

        setState(() => _currentPhase = 'hold');
        await Future.delayed(const Duration(seconds: 4));
        if (!_running || !mounted) break;

        setState(() => _currentPhase = 'exhale');
        _animController.duration = const Duration(seconds: 4);
        await _animController.reverse();
        if (!_running || !mounted) break;

        setState(() => _currentPhase = 'hold');
        await Future.delayed(const Duration(seconds: 4));
      } else if (_mode == BreathingMode.deepRest) {
        // 4-7-8 Deep Rest
        setState(() => _currentPhase = 'inhale');
        _animController.duration = const Duration(seconds: 4);
        await _animController.forward();
        if (!_running || !mounted) break;

        setState(() => _currentPhase = 'hold');
        await Future.delayed(const Duration(seconds: 7));
        if (!_running || !mounted) break;

        setState(() => _currentPhase = 'exhale');
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
    _animController.stop();
    _animController.reset();
  }

  @override
  void dispose() {
    _running = false;
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: Text(s.t('breathingStudio'))),
      body: SafeArea(
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
                    onSelected: (_) => _changeMode(BreathingMode.deepRest),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Animated breathing circle with soft glow
            AnimatedBuilder(
              animation: _animController,
              builder: (_, __) {
                final scale = 120 + 130 * _animController.value;
                return Container(
                  width: scale,
                  height: scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        primary.withValues(alpha: 0.15 + 0.35 * _animController.value),
                        primary.withValues(alpha: 0.05),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.2 * _animController.value),
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
                        color: primary.withValues(alpha: 0.4 + 0.3 * _animController.value),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 36),
            Text(
              _running && _currentPhase.isNotEmpty ? s.t(_currentPhase) : s.t('shieldQuote'),
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: Icon(_running ? Icons.stop_circle_outlined : Icons.play_circle_fill),
                  label: Text(_running ? s.t('stop') : s.t('start'), style: const TextStyle(fontSize: 16)),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _running ? _stop : _start,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. 5-4-3-2-1 SENSORY GROUNDING EXERCISE
// ==========================================
class GroundingScreen extends StatefulWidget {
  const GroundingScreen({super.key});
  @override
  State<GroundingScreen> createState() => _GroundingScreenState();
}

class _GroundingScreenState extends State<GroundingScreen> {
  int _currentStep = 0; // 0 to 4 (Step 5 down to 1)

  final List<Map<String, String>> _steps = [
    {'title': 'step5', 'hint': 'step5Hint', 'icon': '👀', 'count': '5'},
    {'title': 'step4', 'hint': 'step4Hint', 'icon': '✋', 'count': '4'},
    {'title': 'step3', 'hint': 'step3Hint', 'icon': '👂', 'count': '3'},
    {'title': 'step2', 'hint': 'step2Hint', 'icon': '👃', 'count': '2'},
    {'title': 'step1', 'hint': 'step1Hint', 'icon': '👅', 'count': '1'},
  ];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final isFinished = _currentStep >= _steps.length;

    return Scaffold(
      appBar: AppBar(title: Text(s.t('groundingTitle'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: isFinished
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🌱', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 16),
                      Text(s.t('groundingComplete'),
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => setState(() => _currentStep = 0),
                        child: Text(s.t('groundingDone')),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.t('groundingIntro'), style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    // Progress indicator
                    LinearProgressIndicator(
                      value: (_currentStep + 1) / _steps.length,
                      borderRadius: BorderRadius.circular(8),
                      minHeight: 8,
                    ),
                    const SizedBox(height: 8),
                    Text('${_currentStep + 1} / ${_steps.length}', style: theme.textTheme.labelSmall),
                    const Spacer(),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(_steps[_currentStep]['icon']!, style: const TextStyle(fontSize: 48)),
                            const SizedBox(height: 16),
                            Text(
                              s.t(_steps[_currentStep]['title']!),
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              s.t(_steps[_currentStep]['hint']!),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        if (_currentStep > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _currentStep--),
                              child: Text(s.t('prevStep')),
                            ),
                          ),
                        if (_currentStep > 0) const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => setState(() => _currentStep++),
                            child: Text(
                              _currentStep == _steps.length - 1 ? s.t('groundingDone') : s.t('nextStep'),
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

// ==========================================
// 4. PRIVATE ENCRYPTED JOURNAL SCREEN
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
    final controller = TextEditingController(text: initialPrompt != null ? '$initialPrompt\n\n' : '');
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
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('cancel'))),
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
          Text(s.t('tagline'), style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
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
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            )
          else
            for (var i = 0; i < _entries.length; i++)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_entries[i]['d'] ?? '', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
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
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
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
