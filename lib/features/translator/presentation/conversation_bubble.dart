import 'package:flutter/material.dart';

import '../domain/conversation_message.dart';
import '../domain/translation_direction.dart';

/// A chat-style bubble showing one translated utterance (source + translation).
class ConversationBubble extends StatelessWidget {
  const ConversationBubble({super.key, required this.message});

  final ConversationMessage message;

  @override
  Widget build(BuildContext context) {
    final isAToB = message.direction == TranslationDirection.aToB;
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isAToB ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isAToB ? scheme.surfaceContainerHighest : scheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.direction.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline)),
            const SizedBox(height: 4),
            if (message.inputTranscript.isNotEmpty)
              Text(message.inputTranscript, style: Theme.of(context).textTheme.bodyMedium),
            if (message.outputTranscript.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(message.outputTranscript,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}
