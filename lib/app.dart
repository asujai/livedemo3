import 'package:flutter/material.dart';

import 'features/translator/presentation/translator_controller.dart';
import 'features/translator/presentation/translator_screen.dart';

class TiloTranslateApp extends StatefulWidget {
  const TiloTranslateApp({super.key, this.controller});

  /// Optional injected controller (used by tests).
  final TranslatorController? controller;

  @override
  State<TiloTranslateApp> createState() => _TiloTranslateAppState();
}

class _TiloTranslateAppState extends State<TiloTranslateApp> {
  late final TranslatorController _controller = widget.controller ?? TranslatorController();
  late final Future<void> _init = _controller.init();
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFF1565C0);
    return MaterialApp(
      title: 'Tilo Translate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: seed, useMaterial3: true, brightness: Brightness.dark),
      home: FutureBuilder<void>(
        future: _init,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return TranslatorScreen(controller: _controller);
        },
      ),
    );
  }
}
