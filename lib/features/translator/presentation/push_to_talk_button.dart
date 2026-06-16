import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Large hold-to-talk button.
///
/// - Calls [onStart] on press down (haptic).
/// - On release: [onStop] if held >= [minHold], otherwise [onShortPress]
///   (silently cancel a too-brief press).
/// - Visually activates while held.
/// - [enabled] = false greys it out and ignores input (used to prevent both
///   directions being active at once).
class PushToTalkButton extends StatefulWidget {
  const PushToTalkButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.enabled,
    required this.onStart,
    required this.onStop,
    required this.onShortPress,
    this.minHold = const Duration(milliseconds: 250),
  });

  final String title;
  final String subtitle;
  final Color color;
  final bool enabled;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onShortPress;
  final Duration minHold;

  @override
  State<PushToTalkButton> createState() => _PushToTalkButtonState();
}

class _PushToTalkButtonState extends State<PushToTalkButton> {
  bool _pressed = false;
  DateTime? _downAt;

  void _handleDown() {
    if (!widget.enabled) return;
    _downAt = DateTime.now();
    setState(() => _pressed = true);
    HapticFeedback.mediumImpact();
    widget.onStart();
  }

  void _handleUp() {
    if (!_pressed) return;
    setState(() => _pressed = false);
    final held = _downAt == null ? Duration.zero : DateTime.now().difference(_downAt!);
    if (held < widget.minHold) {
      widget.onShortPress();
    } else {
      HapticFeedback.lightImpact();
      widget.onStop();
    }
    _downAt = null;
  }

  void _handleCancel() {
    if (!_pressed) return;
    setState(() => _pressed = false);
    widget.onShortPress();
    _downAt = null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = widget.enabled ? widget.color : scheme.surfaceContainerHighest;
    final active = _pressed;

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: '${widget.title}. ${widget.subtitle}',
      child: GestureDetector(
        onTapDown: (_) => _handleDown(),
        onTapUp: (_) => _handleUp(),
        onTapCancel: _handleCancel,
        child: AnimatedScale(
          scale: active ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 90),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: active ? Color.alphaBlend(Colors.black.withValues(alpha: 0.10), base) : base,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: active ? scheme.primary : Colors.transparent,
                width: 3,
              ),
              boxShadow: active
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(active ? Icons.mic : Icons.mic_none,
                      size: 40,
                      color: widget.enabled ? scheme.onSurface : scheme.outline),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: widget.enabled ? scheme.onSurface : scheme.outline,
                          ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: widget.enabled ? scheme.onSurfaceVariant : scheme.outline,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
