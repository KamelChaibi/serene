import 'package:flutter/material.dart';
import 'l10n.dart';
import 'profile.dart';
import 'storage.dart';

/// First-launch personalization wizard: optional name, birthday (to derive
/// age), and a few questions about how the user wants to be treated.
///
/// Also reused from settings in [_isEditing] mode to update the profile later.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onDone;
  final bool isEditing;

  const OnboardingScreen({
    super.key,
    this.onDone,
    this.isEditing = false,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _stepCount = 3;

  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  int _step = 0;
  bool _loading = true;
  bool _saving = false;

  DateTime? _birthday;
  String _style = Profile.styleWarm;
  String _length = Profile.lengthBalanced;
  final Set<String> _focuses = {};
  bool _inTherapy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Profile p = Profile.empty;
    try {
      p = await Store.profile();
    } catch (_) {
      // Keep the defaults if storage is temporarily unavailable.
    }
    if (!mounted) return;
    setState(() {
      _nameCtrl.text = p.name;
      _notesCtrl.text = p.notes;
      _birthday = p.birthday;
      _style = p.style;
      _length = p.length;
      _focuses
        ..clear()
        ..addAll(p.focuses);
      _inTherapy = p.inTherapy;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday(S s) async {
    final now = DateTime.now();
    final firstDate = DateTime(1900);
    var initial = _birthday ?? DateTime(now.year - 25, now.month, now.day);
    if (initial.isAfter(now)) initial = now;
    if (initial.isBefore(firstDate)) initial = firstDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: now,
      helpText: s.t('chooseBirthday'),
      cancelText: s.t('cancel'),
      confirmText: s.t('done'),
    );
    if (picked != null && mounted) {
      setState(() => _birthday = picked);
    }
  }

  void _next(S s) {
    // Required on first run (with a "skip for now" escape), optional when the
    // user is intentionally revisiting their profile from settings.
    if (_step == 0 && _birthday == null && !widget.isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('birthdayRequired'))),
      );
      return;
    }
    if (_step < _stepCount - 1) {
      setState(() => _step++);
    } else {
      _finish(s);
    }
  }

  Future<void> _finish(S s) async {
    if (_saving) return;
    setState(() => _saving = true);
    final profile = Profile(
      name: _nameCtrl.text.trim(),
      birthday: _birthday,
      style: _style,
      length: _length,
      focuses: _focuses.toList(growable: false),
      inTherapy: _inTherapy,
      notes: _notesCtrl.text.trim(),
    );
    try {
      await Store.setProfile(profile);
      await Store.completeOnboarding();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('saveError'))),
      );
      return;
    }
    if (!mounted) return;
    widget.onDone?.call();
  }

  Future<void> _skip() async {
    try {
      await Store.completeOnboarding();
    } catch (_) {
      // Let the user in anyway; onboarding can be retried from settings.
    }
    if (!mounted) return;
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold();

    final s = S.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  if (widget.isEditing)
                    const BackButton()
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      s.t('profileSetup'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!widget.isEditing)
                    TextButton(
                      onPressed: _saving ? null : _skip,
                      child: Text(s.t('skipForNow')),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 8),
              // Step progress
              Row(
                children: List.generate(_stepCount, (i) {
                  final active = i <= _step;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin:
                          EdgeInsets.only(right: i == _stepCount - 1 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: active
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: SingleChildScrollView(
                    key: ValueKey(_step),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: switch (_step) {
                      0 => _buildAboutStep(s, theme),
                      1 => _buildStyleStep(s, theme),
                      _ => _buildFocusStep(s, theme),
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: _saving ? null : () => setState(() => _step--),
                      child: Text(s.t('back')),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving ? null : () => _next(s),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _step == _stepCount - 1
                                ? (widget.isEditing
                                    ? s.t('saveChanges')
                                    : s.t('getStarted'))
                                : s.t('next'),
                            style: const TextStyle(fontSize: 15),
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

  // ---------------------------------------------------------------------------
  // Step 1 — Name & birthday
  // ---------------------------------------------------------------------------
  Widget _buildAboutStep(S s, ThemeData theme) {
    final age = _birthday == null ? null : _ageFrom(_birthday!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.spa_outlined,
              size: 36,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          s.t('aboutYouTitle'),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.t('aboutYouSubtitle'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: s.t('yourName'),
            hintText: s.t('yourNameHint'),
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _pickBirthday(s),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: s.t('birthday'),
              helperText: s.t('birthdayPrivacy'),
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.cake_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _birthday == null
                        ? s.t('chooseBirthday')
                        : _formatDate(_birthday!),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: _birthday == null
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (age != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      s.t('ageYears').replaceAll('{age}', '$age'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_outline,
              size: 16,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.t('onboardingPrivacy'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 — Tone & reply length
  // ---------------------------------------------------------------------------
  Widget _buildStyleStep(S s, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.t('styleTitle'),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.t('styleSubtitle'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        _choiceCard(
          theme,
          icon: Icons.favorite_outline,
          title: s.t('styleWarm'),
          subtitle: s.t('styleWarmDesc'),
          selected: _style == Profile.styleWarm,
          onTap: () => setState(() => _style = Profile.styleWarm),
        ),
        const SizedBox(height: 10),
        _choiceCard(
          theme,
          icon: Icons.people_outline,
          title: s.t('styleFriend'),
          subtitle: s.t('styleFriendDesc'),
          selected: _style == Profile.styleFriend,
          onTap: () => setState(() => _style = Profile.styleFriend),
        ),
        const SizedBox(height: 10),
        _choiceCard(
          theme,
          icon: Icons.compass_calibration_outlined,
          title: s.t('styleDirect'),
          subtitle: s.t('styleDirectDesc'),
          selected: _style == Profile.styleDirect,
          onTap: () => setState(() => _style = Profile.styleDirect),
        ),
        const SizedBox(height: 28),
        Text(
          s.t('lengthTitle'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _lengthChip(
              theme,
              key: Profile.lengthShort,
              label: s.t('lengthShort'),
            ),
            _lengthChip(
              theme,
              key: Profile.lengthBalanced,
              label: s.t('lengthBalanced'),
            ),
            _lengthChip(
              theme,
              key: Profile.lengthDeep,
              label: s.t('lengthDeep'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _length == Profile.lengthShort
              ? s.t('lengthShortDesc')
              : _length == Profile.lengthDeep
                  ? s.t('lengthDeepDesc')
                  : s.t('lengthBalancedDesc'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _lengthChip(
    ThemeData theme, {
    required String key,
    required String label,
  }) {
    final selected = _length == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _length = key),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3 — Focus areas, therapy, free notes
  // ---------------------------------------------------------------------------
  Widget _buildFocusStep(S s, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.t('focusTitle'),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.t('focusSubtitle'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final key in Profile.focusKeys)
              FilterChip(
                label: Text(s.t('focus${_capitalize(key)}')),
                selected: _focuses.contains(key),
                onSelected: (v) => setState(() {
                  if (v) {
                    _focuses.add(key);
                  } else {
                    _focuses.remove(key);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(s.t('therapyTitle')),
            subtitle: Text(s.t('therapyDesc')),
            value: _inTherapy,
            onChanged: (v) => setState(() => _inTherapy = v),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _notesCtrl,
          minLines: 3,
          maxLines: 5,
          maxLength: 300,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: s.t('notesTitle'),
            hintText: s.t('notesHint'),
            alignLabelWithHint: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.edit_outlined,
              size: 16,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.t('profileLater'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  Widget _choiceCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
                : theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primary.withValues(alpha: 0.16)
                      : theme.colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 22,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static int _ageFrom(DateTime b) {
    final now = DateTime.now();
    var years = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) {
      years--;
    }
    return years < 0 ? 0 : years;
  }

  static String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

  String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }
}
