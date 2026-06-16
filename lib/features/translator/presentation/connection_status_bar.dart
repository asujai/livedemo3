import 'package:flutter/material.dart';

import '../domain/live_translation_session.dart';

/// Small pill showing the current session status (Ready / Connecting / ...).
class ConnectionStatusBar extends StatelessWidget {
  const ConnectionStatusBar({super.key, required this.status});

  final SessionStatus status;

  Color _color(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      SessionStatus.idle => scheme.outline,
      SessionStatus.connecting => scheme.tertiary,
      SessionStatus.listening => scheme.primary,
      SessionStatus.translating => scheme.secondary,
      SessionStatus.error => scheme.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(status.label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
