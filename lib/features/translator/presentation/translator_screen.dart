import 'package:flutter/material.dart';

import '../domain/language_option.dart';
import '../domain/translation_direction.dart';
import '../domain/usage_tracker.dart';
import 'connection_status_bar.dart';
import 'conversation_bubble.dart';
import 'language_picker_sheet.dart';
import 'push_to_talk_button.dart';
import 'settings_screen.dart';
import 'translator_controller.dart';

/// Main (and only) screen: language selection, live conversation and the two
/// large push-to-talk buttons. Real audio is wired up in the next stage.
class TranslatorScreen extends StatefulWidget {
  const TranslatorScreen({super.key, required this.controller});

  final TranslatorController controller;

  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen> {
  final ScrollController _scroll = ScrollController();
  String? _shownError;

  TranslatorController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    // Surface a fresh error once, as a snackbar.
    final err = c.lastError;
    if (err != null && err != _shownError) {
      _shownError = err;
      _snack(err);
    } else if (err == null) {
      _shownError = null;
    }
    // Keep the conversation scrolled to the latest bubble.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickLanguage({required bool isStaff}) async {
    final picked = await LanguagePickerSheet.show(
      context,
      selectedCode: isStaff ? c.languageA.code : c.languageB.code,
      otherSelectedCode: isStaff ? c.languageB.code : c.languageA.code,
    );
    if (picked != null) {
      await c.setLanguage(isStaff: isStaff, lang: picked);
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SettingsScreen(controller: c)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Tilo Translate'),
            actions: [
              Center(child: ConnectionStatusBar(status: c.status)),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings),
                onPressed: _openSettings,
              ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 720;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _languageSelector(),
                          if (c.sameLanguage) _sameLanguageWarning(),
                          const SizedBox(height: 12),
                          Expanded(flex: 2, child: _conversationArea()),
                          const SizedBox(height: 12),
                          Expanded(flex: 3, child: _talkButtons(isTablet)),
                          const SizedBox(height: 6),
                          _usageBar(),
                          _bottomControls(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _languageSelector() {
    return Row(
      children: [
        Expanded(child: _langCard(label: 'Staff', lang: c.languageA, onTap: () => _pickLanguage(isStaff: true))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: IconButton.filledTonal(
            onPressed: c.swap,
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Swap languages',
          ),
        ),
        Expanded(child: _langCard(label: 'Guest', lang: c.languageB, onTap: () => _pickLanguage(isStaff: false))),
      ],
    );
  }

  Widget _langCard({required String label, required LanguageOption lang, required VoidCallback onTap}) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 2),
              Text(lang.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(lang.nativeName,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sameLanguageWarning() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text('The same language cannot be selected for both sides.',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  Widget _conversationArea() {
    final messages = c.messages;
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'Hold a button below and speak.\nTranslated conversation appears here.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      itemCount: messages.length,
      itemBuilder: (context, i) => ConversationBubble(message: messages[i]),
    );
  }

  Widget _talkButtons(bool isTablet) {
    final staffBtn = PushToTalkButton(
      title: c.languageA.name,
      subtitle: 'Press and hold to speak',
      color: Theme.of(context).colorScheme.primaryContainer,
      enabled: !c.sameLanguage && c.canActivate(TranslationDirection.aToB),
      onStart: () => c.startDirection(TranslationDirection.aToB),
      onStop: () => c.stopDirection(TranslationDirection.aToB),
      onShortPress: () => c.cancelShortPress(TranslationDirection.aToB),
    );
    final guestBtn = PushToTalkButton(
      title: c.languageB.name,
      subtitle: 'Press and hold to speak',
      color: Theme.of(context).colorScheme.secondaryContainer,
      enabled: !c.sameLanguage && c.canActivate(TranslationDirection.bToA),
      onStart: () => c.startDirection(TranslationDirection.bToA),
      onStop: () => c.stopDirection(TranslationDirection.bToA),
      onShortPress: () => c.cancelShortPress(TranslationDirection.bToA),
    );

    if (isTablet) {
      return Row(
        children: [
          Expanded(child: staffBtn),
          const SizedBox(width: 16),
          Expanded(child: guestBtn),
        ],
      );
    }
    return Column(
      children: [
        Expanded(child: staffBtn),
        const SizedBox(height: 16),
        Expanded(child: guestBtn),
      ],
    );
  }

  Widget _usageBar() {
    return Text(
      'This session: ${UsageTracker.format(c.sessionUsage)}   ·   '
      'Today: ${UsageTracker.format(c.todayUsage)}',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
    );
  }

  Widget _bottomControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton.icon(
          onPressed: c.messages.isEmpty ? null : () => _confirmClear(),
          icon: const Icon(Icons.delete_sweep_outlined),
          label: const Text('Clear'),
        ),
        TextButton.icon(
          onPressed: c.endSession,
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('End session'),
        ),
        TextButton.icon(
          onPressed: _openSettings,
          icon: const Icon(Icons.settings_outlined),
          label: const Text('Settings'),
        ),
      ],
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text('This removes all saved transcripts on this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) await c.clearConversation();
  }
}
