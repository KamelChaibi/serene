import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n.dart';
import 'safety.dart';
import 'storage.dart';

/// The crisis sheet shown during a voice call when the agent detects risk.
///
/// It is deliberately blocking: the user has to choose "I'm safe for now" or
/// end the call, so the hotlines cannot be dismissed by a stray tap.
Future<void> showVoiceCrisisSheet(
  BuildContext context,
  S s, {
  VoidCallback? onEnd,
}) async {
  final theme = Theme.of(context);

  var country = 'TN';
  try {
    country = await Store.country();
  } catch (_) {
    // Keep the default rather than blocking the safety sheet.
  }
  if (!context.mounted) return;

  final hotlines = hotlinesForCountry(country);

  await showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          Row(
            children: [
              Icon(Icons.favorite, color: theme.colorScheme.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.t('crisisTitle'),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            s.t('voiceCrisisBody'),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 16),
          ...hotlines.map(
            (hotline) => Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                title: Text(
                  hotline.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: hotline.description.isEmpty
                    ? null
                    : Text(
                        hotline.description,
                        style: theme.textTheme.bodySmall,
                      ),
                trailing: hotline.number.isEmpty
                    ? const Icon(Icons.open_in_new, size: 18)
                    : FilledButton(
                        onPressed: () => _dial(hotline.number),
                        child: Text(hotline.number),
                      ),
                onTap: hotline.url != null
                    ? () => _openUrl(hotline.url!)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.tonal(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: Text(s.t('voiceCrisisContinue')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              onEnd?.call();
            },
            child: Text(s.t('voiceEnd')),
          ),
        ],
      ),
    ),
  );
}

Future<void> _dial(String number) async {
  final uri = Uri(scheme: 'tel', path: number);
  try {
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  } catch (_) {
    // Dialling is a courtesy; the number stays visible either way.
  }
}

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  } catch (_) {}
}
