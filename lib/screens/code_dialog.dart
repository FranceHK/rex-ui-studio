import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../icons/app_icons.dart';
import '../models/ui_element.dart';
import '../services/code_export.dart';

const _languageKey = 'rexa_ui_studio.code_language';

/// Shows the generated code for [page] in the language the user last
/// picked (remembered across sessions).
Future<void> showCodeDialog(BuildContext context, DesignPage page) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = CodeLanguage.values.asNameMap()[prefs.getString(_languageKey)];
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => CodeDialog(
      page: page,
      initial: saved ?? CodeLanguage.flutter,
      onLanguageChanged: (l) => prefs.setString(_languageKey, l.name),
    ),
  );
}

class CodeDialog extends StatefulWidget {
  const CodeDialog({
    super.key,
    required this.page,
    this.initial = CodeLanguage.flutter,
    this.onLanguageChanged,
  });

  final DesignPage page;
  final CodeLanguage initial;
  final ValueChanged<CodeLanguage>? onLanguageChanged;

  @override
  State<CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<CodeDialog> {
  late CodeLanguage _language = widget.initial;
  late String _code = _language.generate(widget.page);

  void _select(CodeLanguage l) {
    setState(() {
      _language = l;
      _code = l.generate(widget.page);
    });
    widget.onLanguageChanged?.call(l);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('Code — ${widget.page.name}'),
      content: SizedBox(
        width: 760,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in CodeLanguage.values)
                  ChoiceChip(
                    label: Text(l.label),
                    selected: l == _language,
                    onSelected: (_) => _select(l),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_language.language} · ${_language.fileName(widget.page)}',
              style: TextStyle(color: scheme.outline, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _code,
                    key: ValueKey(_language),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      color: Color(0xFFE2E8F0),
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          icon: const Icon(AppIcons.copy),
          label: const Text('Copy code'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _code));
            final messenger = ScaffoldMessenger.maybeOf(context);
            Navigator.pop(context);
            messenger?.showSnackBar(
              SnackBar(content: Text('${_language.label} code copied ✓')),
            );
          },
        ),
      ],
    );
  }
}
