import 'package:flutter/material.dart';
import 'l10n.dart';
import 'pwa.dart';

/// A small, dismissible hint for iPhone users.
///
/// iOS does not support `beforeinstallprompt`, so installing a PWA there is a
/// manual "Share → Add to Home Screen" action. This card only appears when the
/// app is running on iOS inside a browser tab, and it disappears for the rest
/// of the session once dismissed.
class PwaInstallCard extends StatefulWidget {
  const PwaInstallCard({super.key});

  @override
  State<PwaInstallCard> createState() => _PwaInstallCardState();
}

class _PwaInstallCardState extends State<PwaInstallCard> {
  static bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (!shouldSuggestInstall || _dismissed) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final s = S.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.ios_share, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.t('installTitle'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: s.t('close'),
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _dismissed = true),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                s.t('installBody'),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
