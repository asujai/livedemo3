import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/conversation_message.dart';

/// Local-only persistence of conversation transcripts (no audio, no cloud).
abstract class ConversationStorage {
  /// Load all saved messages (oldest first).
  Future<List<ConversationMessage>> load();

  /// Replace the whole stored list.
  Future<void> saveAll(List<ConversationMessage> messages);

  /// Append a message to history.
  Future<void> add(ConversationMessage message);

  /// Remove all stored messages.
  Future<void> clear();
}

/// SharedPreferences-backed storage. History is kept as a JSON array string.
class SharedPrefsConversationStorage implements ConversationStorage {
  static const _key = 'history.messages';

  @override
  Future<List<ConversationMessage>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ConversationMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveAll(List<ConversationMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(messages.map((m) => m.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  @override
  Future<void> add(ConversationMessage message) async {
    final all = await load()
      ..add(message);
    await saveAll(all);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Trivial in-memory implementation, handy for tests / fallback.
class InMemoryConversationStorage implements ConversationStorage {
  final List<ConversationMessage> _items = [];

  @override
  Future<void> add(ConversationMessage message) async => _items.add(message);

  @override
  Future<void> saveAll(List<ConversationMessage> messages) async {
    _items
      ..clear()
      ..addAll(messages);
  }

  @override
  Future<void> clear() async => _items.clear();

  @override
  Future<List<ConversationMessage>> load() async => List.unmodifiable(_items);
}
