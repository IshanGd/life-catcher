import 'package:flutter/material.dart';

import '../models/sos_dispatch.dart';
import '../models/sos_event.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Live SOS relay status, shown across every tab (mounted above the
/// bottom-nav content in RootShell) so it survives a tab switch --
/// 03_RULES.md "fail visibly, not silently" applies to the relay itself,
/// not just the BLE link.
class SosDispatchBanner extends StatelessWidget {
  const SosDispatchBanner({super.key, required this.record, this.onDismiss, this.onRetry});

  final SosDispatchRecord record;
  final VoidCallback? onDismiss;
  final VoidCallback? onRetry;

  Color get _accent => switch (record.status) {
        SosDispatchStatus.locating => AppColors.amber,
        SosDispatchStatus.sending => AppColors.amber,
        SosDispatchStatus.sent => AppColors.green,
        SosDispatchStatus.failed => AppColors.red,
      };

  String get _title => switch (record.event.type) {
        SosTriggerType.crashImpact => 'CRASH DETECTED',
        SosTriggerType.panicButton => 'PANIC BUTTON PRESSED',
      };

  String get _statusLine => switch (record.status) {
        SosDispatchStatus.locating => 'Getting your location…',
        SosDispatchStatus.sending => 'Sending alert to your emergency contact…',
        SosDispatchStatus.sent => 'Alert sent to your emergency contact',
        SosDispatchStatus.failed => 'Alert failed to send',
      };

  @override
  Widget build(BuildContext context) {
    final busy = record.status == SosDispatchStatus.locating || record.status == SosDispatchStatus.sending;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (busy)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
                )
              else
                Icon(record.status == SosDispatchStatus.sent ? Icons.check_circle_rounded : Icons.error_rounded,
                    size: 18, color: _accent),
              const SizedBox(width: 8),
              Text(_title, style: AppTextStyles.eyebrowMono(color: _accent)),
            ],
          ),
          const SizedBox(height: 8),
          Text(_statusLine, style: AppTextStyles.body(weight: FontWeight.w600)),
          if (record.location != null) ...[
            const SizedBox(height: 4),
            Text('Location: ${record.location!.toDisplayString()}', style: AppTextStyles.bodySecondary()),
          ] else if (!busy) ...[
            const SizedBox(height: 4),
            Text('Location unavailable', style: AppTextStyles.bodySecondary()),
          ],
          if (record.event.confirmedBy.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Confirmed by: ${record.event.confirmedBy.join(' + ')}', style: AppTextStyles.caption()),
          ],
          if (!busy) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (record.status == SosDispatchStatus.failed && onRetry != null)
                  TextButton(onPressed: onRetry, child: Text('Retry', style: AppTextStyles.body(weight: FontWeight.w700, color: _accent))),
                if (onDismiss != null)
                  TextButton(
                      onPressed: onDismiss,
                      child: Text('Dismiss', style: AppTextStyles.bodySecondary(weight: FontWeight.w600))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
