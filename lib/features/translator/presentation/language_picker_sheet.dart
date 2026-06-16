import 'package:flutter/material.dart';

import '../../../core/constants/languages.dart';
import '../domain/language_option.dart';

/// Searchable bottom sheet for picking a language.
///
/// Shows popular languages first, then the rest. Displays name + native name +
/// code. Search matches English name, native name and code. The language used
/// by the other side ([otherSelectedCode]) is marked "in use" and not tappable.
class LanguagePickerSheet extends StatefulWidget {
  const LanguagePickerSheet({super.key, this.selectedCode, this.otherSelectedCode});

  final String? selectedCode;
  final String? otherSelectedCode;

  static Future<LanguageOption?> show(
    BuildContext context, {
    String? selectedCode,
    String? otherSelectedCode,
  }) {
    return showModalBottomSheet<LanguageOption>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => LanguagePickerSheet(
        selectedCode: selectedCode,
        otherSelectedCode: otherSelectedCode,
      ),
    );
  }

  @override
  State<LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<LanguagePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = Languages.all.where((l) => l.matches(_query)).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search language (name or code)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (results.isEmpty)
              const Expanded(child: Center(child: Text('No languages found')))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final lang = results[i];
                    final selected = lang.code == widget.selectedCode;
                    final inUse = lang.code == widget.otherSelectedCode;
                    return ListTile(
                      enabled: !inUse,
                      title: Text('${lang.name}  ·  ${lang.nativeName}'),
                      subtitle: Text(inUse ? '${lang.code} · in use by other side' : lang.code),
                      trailing: selected
                          ? const Icon(Icons.check)
                          : (lang.popular ? const Icon(Icons.star, size: 16) : null),
                      selected: selected,
                      onTap: inUse ? null : () => Navigator.of(context).pop(lang),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
