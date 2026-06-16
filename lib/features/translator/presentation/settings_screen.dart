import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import 'translator_controller.dart';

/// Simple settings screen. All values persist locally.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final TranslatorController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _urlController =
      TextEditingController(text: widget.controller.settings.tokenServerUrlOverride);

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Token server', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: 'Token server URL',
                  hintText: AppConfig.tokenServerUrl,
                  helperText: 'Leave empty to use the build-time default.',
                ),
                onSubmitted: (v) => c.updateSettings(tokenServerUrlOverride: v.trim()),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: () {
                    c.updateSettings(tokenServerUrlOverride: _urlController.text.trim());
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Saved. Using: ${AppConfig.tokenServerUrl}')),
                    );
                  },
                  child: const Text('Save URL'),
                ),
              ),
              const Divider(height: 32),
              SwitchListTile(
                title: const Text('Save conversation history'),
                subtitle: const Text('Store transcripts on this device only'),
                value: c.settings.saveHistory,
                onChanged: (v) => c.updateSettings(saveHistory: v),
              ),
              SwitchListTile(
                title: const Text('Auto-play translated audio'),
                subtitle: const Text('Play translation automatically when received'),
                value: c.settings.autoPlayAudio,
                onChanged: (v) => c.updateSettings(autoPlayAudio: v),
              ),
              const Divider(height: 32),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Clear conversation history'),
                onTap: () async {
                  await c.clearConversation();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Conversation history cleared')),
                    );
                  }
                },
              ),
              const Divider(height: 32),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Tilo Translate'),
                subtitle: Text(
                  'Two-way live speech translation for hotels, receptions, '
                  'restaurants and clinics.\n'
                  'No accounts · No analytics · Data stays on device.',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.translate),
                title: const Text('Model'),
                subtitle: Text(AppConfig.liveTranslateModel),
              ),
            ],
          );
        },
      ),
    );
  }
}
