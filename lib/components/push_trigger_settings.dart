import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:obtainium/components/ui_widgets.dart';
import 'package:obtainium/providers/settings_provider.dart';
import 'package:obtainium/services/push_trigger.dart';
import 'package:obtainium/theme.dart';
import 'package:provider/provider.dart';

List<Widget> pushTriggerSettingsTiles(BuildContext context) {
  final settingsProvider = context.read<SettingsProvider>();
  final enabled = settingsProvider.pushTriggerEnabled;
  final endpoint = settingsProvider.pushTriggerEndpoint;
  return [
    ToggleTile(
      label: tr('pushTriggeredChecks'),
      value: enabled,
      onChanged: (value) => unawaited(_setPushTriggerEnabled(context, value)),
      helpWidgets: [
        Text(tr('pushTriggeredChecksHelp')),
        const SizedBox(height: AppSpacings.elementGap),
        Text(tr('pushTriggeredChecksPayloadHelp')),
      ],
    ),
    if (enabled)
      CardTile(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr('pushEndpoint')),
          subtitle: endpoint == null
              ? Text(tr('pushEndpointPending'))
              : SelectableText(endpoint),
          trailing: endpoint == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: tr('copyToClipboard'),
                  onPressed: () =>
                      unawaited(copyToClipboard(context, endpoint)),
                ),
        ),
      ),
  ];
}

Future<void> _setPushTriggerEnabled(BuildContext context, bool value) async {
  final settingsProvider = context.read<SettingsProvider>();
  try {
    if (value) {
      await PushTrigger.enable(
        settingsProvider,
        (distributors) => _pickDistributor(context, distributors),
      );
    } else {
      await PushTrigger.disable(settingsProvider);
    }
  } catch (e) {
    if (!context.mounted) return;
    showError(e, context);
  }
}

Future<String?> _pickDistributor(
  BuildContext context,
  List<String> distributors,
) async {
  if (!context.mounted) return null;
  return showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(tr('selectPushDistributor')),
      children: [
        for (final distributor in distributors)
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(distributor),
            child: Text(distributor),
          ),
      ],
    ),
  );
}
