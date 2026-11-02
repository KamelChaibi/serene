import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'l10n.dart';
import 'onboarding.dart';
import 'responsive.dart';
import 'storage.dart';
import 'wellness.dart';

/// Shows the privacy and clinical consent screen once on first launch.
class Gate extends StatefulWidget {
  final void Function(Locale) onLocale;
  const Gate({super.key, required this.onLocale});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  bool? _hasConsented;
  bool? _isOnboarded;

  @override
  void initState() {
    super.initState();
    _loadFlags();
  }

  Future<void> _loadFlags() async {
    bool consented = false;
    bool onboarded = false;
    try {
      consented = await Store.flag('consent');
      onboarded = await Store.onboardingDone();
    } catch (_) {
      // Fail open on a storage hiccup rather than showing a blank screen.
      consented = true;
      onboarded = true;
    }
    if (!mounted) return;
    setState(() {
      _hasConsented = consented;
      _isOnboarded = onboarded;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasConsented == null || _isOnboarded == null) {
      return const Scaffold();
    }

    // First launch, after consent: learn how the user wants to be treated.
    if (_hasConsented! && !_isOnboarded!) {
      return OnboardingScreen(
        onDone: () => setState(() => _isOnboarded = true),
      );
    }

    if (_hasConsented!) return Home(onLocale: widget.onLocale);

    final s = S.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Responsive.centered(
          maxWidth: 640,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.of(context, 24),
              vertical: Responsive.of(context, 16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Language switch pills
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final l in const {
                      'ar': 'العربية',
                      'fr': 'Français',
                      'en': 'English'
                    }.entries)
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => widget.onLocale(Locale(l.key)),
                        child: Text(l.value,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                // Brand logo & title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.spa,
                          size: 32, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.t('welcomeTitle'),
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            s.t('tagline'),
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Consent and disclaimer body card
                Expanded(
                  child: Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: SingleChildScrollView(
                        child: Text(
                          s.t('welcomeBody'),
                          style:
                              theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.favorite_border),
                    label: Text(s.t('accept'),
                        style: const TextStyle(fontSize: 16)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      await Store.setFlag('consent', true);
                      final onboarded = await Store.onboardingDone();
                      if (!mounted) return;
                      setState(() {
                        _hasConsented = true;
                        _isOnboarded = onboarded;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Home extends StatefulWidget {
  final void Function(Locale) onLocale;
  const Home({super.key, required this.onLocale});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ChatScreen(onLocale: widget.onLocale),
          const MoodScreen(),
          const BreatheScreen(),
          const GroundingScreen(),
          const JournalScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (v) => setState(() => _currentIndex = v),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: s.t('chat'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.mood_outlined),
            selectedIcon: const Icon(Icons.mood),
            label: s.t('checkin'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.air_outlined),
            selectedIcon: const Icon(Icons.air),
            label: s.t('breathe'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.self_improvement_outlined),
            selectedIcon: const Icon(Icons.self_improvement),
            label: s.t('grounding'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.book_outlined),
            selectedIcon: const Icon(Icons.book),
            label: s.t('journal'),
          ),
        ],
      ),
    );
  }
}
