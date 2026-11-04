import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../canvas/alignment.dart';
import '../canvas/layout.dart';
import '../icons/app_icons.dart';
import '../services/project_storage.dart';
import '../state/editor_controller.dart';
import '../widgets/canvas_settings.dart';
import '../widgets/design_canvas.dart';
import 'code_dialog.dart';
import 'export_image_dialog.dart';
import 'run_screen.dart';
import '../widgets/properties_panel.dart';
import '../widgets/side_panel.dart';

/// The design screen for one project.
///  - wide (≥ 1150): navigation bar + both panels visible
///  - tablet (720–1149): the navigation bar becomes a drawer
///  - narrow (< 720): both panels are drawers
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.project, required this.storage});

  final ProjectInfo project;
  final ProjectStorage storage;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

enum _SaveState { loading, saving, saved, error }

class _EditorScreenState extends State<EditorScreen> {
  final c = EditorController();
  final _focus = FocusNode();
  late String _name = widget.project.name;

  _SaveState _saveState = _SaveState.loading;

  /// Whether the left and right panels are open (collapsed, the canvas
  /// gets more room).
  bool _leftOpen = true;
  bool _rightOpen = true;

  void _exportImage() =>
      showExportImage(context, pages: c.pages, initialIndex: c.pageIndex);

  void _toggleLeft() => setState(() => _leftOpen = !_leftOpen);
  void _toggleRight() => setState(() => _rightOpen = !_rightOpen);

  /// Full canvas: collapse both panels, or open them again.
  void _toggleFocusCanvas() {
    final open = !(_leftOpen || _rightOpen);
    setState(() => _leftOpen = _rightOpen = open);
  }

  Timer? _saveTimer;

  ProjectStorage get _storage => widget.storage;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  /// Open the saved project, then save every change.
  Future<void> _restore() async {
    try {
      final saved = await _storage.load(widget.project.id);
      if (saved != null) c.loadJson(saved);
    } on FormatException {
      // Corrupt project: start with an empty screen instead of getting stuck
    }
    if (!mounted) return;
    setState(() => _saveState = _SaveState.saved);
    c.addListener(_scheduleSave);
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
    if (_saveState != _SaveState.saving) {
      setState(() => _saveState = _SaveState.saving);
    }
  }

  Future<void> _save() async {
    try {
      await _storage.save(widget.project.id, c.toJson());
      if (mounted) setState(() => _saveState = _SaveState.saved);
    } catch (_) {
      if (mounted) setState(() => _saveState = _SaveState.error);
    }
  }

  @override
  void dispose() {
    // Save the last changes before closing
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      _storage.save(widget.project.id, c.toJson());
    }
    c.dispose();
    _focus.dispose();
    super.dispose();
  }

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.keyE, meta: true, shift: true):
        _exportImage,
    const SingleActivator(LogicalKeyboardKey.keyE, control: true, shift: true):
        _exportImage,
    const SingleActivator(LogicalKeyboardKey.backslash, meta: true):
        _toggleFocusCanvas,
    const SingleActivator(LogicalKeyboardKey.backslash, control: true):
        _toggleFocusCanvas,
    const SingleActivator(LogicalKeyboardKey.delete): c.deleteSelected,
    const SingleActivator(LogicalKeyboardKey.backspace): c.deleteSelected,
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): c.undo,
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true): c.undo,
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
        c.redo,
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
        c.redo,
    const SingleActivator(LogicalKeyboardKey.keyD, meta: true):
        c.duplicateSelected,
    const SingleActivator(LogicalKeyboardKey.keyD, control: true):
        c.duplicateSelected,
    const SingleActivator(LogicalKeyboardKey.keyL, meta: true, shift: true):
        _toggleLockSelected,
    const SingleActivator(LogicalKeyboardKey.keyL, control: true, shift: true):
        _toggleLockSelected,
    const SingleActivator(LogicalKeyboardKey.keyA, meta: true): c.selectAll,
    const SingleActivator(LogicalKeyboardKey.keyA, control: true): c.selectAll,
    const SingleActivator(LogicalKeyboardKey.escape): () => c.select(null),
    // Alignment (like Figma): Alt + A/H/D/W/V/S, Alt + C = center
    for (final (key, op) in [
      (LogicalKeyboardKey.keyA, AlignOp.left),
      (LogicalKeyboardKey.keyH, AlignOp.hCenter),
      (LogicalKeyboardKey.keyD, AlignOp.right),
      (LogicalKeyboardKey.keyW, AlignOp.top),
      (LogicalKeyboardKey.keyV, AlignOp.vCenter),
      (LogicalKeyboardKey.keyS, AlignOp.bottom),
      (LogicalKeyboardKey.keyC, AlignOp.centerBoth),
    ])
      SingleActivator(key, alt: true): () => c.align(op),
    // View
    const SingleActivator(LogicalKeyboardKey.keyR, shift: true): () =>
        _toggleView((v) => v.copyWith(showRulers: !v.showRulers)),
    for (final mod in [(true, false), (false, true)]) ...{
      SingleActivator(
        LogicalKeyboardKey.semicolon,
        meta: mod.$1,
        control: mod.$2,
      ): () =>
          _toggleView((v) => v.copyWith(showGuides: !v.showGuides)),
      SingleActivator(
        LogicalKeyboardKey.semicolon,
        meta: mod.$1,
        control: mod.$2,
        alt: true,
      ): () =>
          _toggleView((v) => v.copyWith(guidesLocked: !v.guidesLocked)),
      SingleActivator(
        LogicalKeyboardKey.quote,
        meta: mod.$1,
        control: mod.$2,
      ): () =>
          c.setGrid(c.page.grid.copyWith(show: !c.page.grid.show)),
      SingleActivator(LogicalKeyboardKey.enter, meta: mod.$1, control: mod.$2):
          _run,
    },
    for (final (key, delta) in [
      (LogicalKeyboardKey.arrowLeft, const Offset(-1, 0)),
      (LogicalKeyboardKey.arrowRight, const Offset(1, 0)),
      (LogicalKeyboardKey.arrowUp, const Offset(0, -1)),
      (LogicalKeyboardKey.arrowDown, const Offset(0, 1)),
    ]) ...{
      SingleActivator(key): () => c.nudgeSelected(delta),
      SingleActivator(key, shift: true): () => c.nudgeSelected(delta * 10),
    },
  };

  /// Is the user typing in a TextField (name, X/Y, width, search…)?
  /// Then Backspace/Delete/arrows edit the text instead of deleting or
  /// moving the element.
  static bool get isTyping {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || isTyping) return KeyEventResult.ignored;
    for (final MapEntry(key: activator, value: action) in _shortcuts.entries) {
      if (activator.accepts(event, HardwareKeyboard.instance)) {
        action();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _toggleLockSelected() {
    if (c.selectedId case final id?) c.toggleLock(id);
  }

  void _toggleView(ViewSettings Function(ViewSettings) change) =>
      c.setView(change(c.view));

  /// Try the design as an app (prototype).
  void _run() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => RunScreen(pages: c.pages, initialIndex: c.pageIndex),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _rename() async {
    final ctrl = TextEditingController(text: _name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Project name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.trim().isEmpty) return;
    await _storage.rename(widget.project.id, name.trim());
    setState(() => _name = name.trim());
  }

  Future<void> _exportJson() async {
    final json = const JsonEncoder.withIndent('  ').convert(c.toJson());
    await Clipboard.setData(ClipboardData(text: json));
    _toast(
      'Project JSON copied — paste it into a file or send it to someone ✓',
    );
  }

  Future<void> _importJson() async {
    final input = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import project (JSON)'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: input,
            maxLines: 14,
            autofocus: true,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
            decoration: const InputDecoration(
              hintText: 'Paste the JSON you exported earlier...',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    input.dispose();
    if (text == null || text.trim().isEmpty) return;

    try {
      c.loadJson(jsonDecode(text) as Map<String, dynamic>, record: true);
      _toast('Project imported: ${c.pages.length} screens ✓');
    } catch (_) {
      _toast('Failed: this JSON is not a Rexa UI Studio project');
    }
  }

  void _showCode() => showCodeDialog(context, c.page);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final showLeft = width >= 1150;
    final showRight = width >= 720;
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final left = SidePanel(controller: c);
        final right = PropertiesPanel(controller: c);
        final focused = showLeft && !_leftOpen && showRight && !_rightOpen;

        return Focus(
          onKeyEvent: _onKey,
          child: Focus(
            focusNode: _focus,
            autofocus: true,
            child: Scaffold(
              appBar: AppBar(
                leading: showLeft
                    ? IconButton(
                        tooltip: 'All projects',
                        icon: const Icon(AppIcons.back),
                        onPressed: () => Navigator.pop(context),
                      )
                    : null,
                titleSpacing: showLeft ? 0 : null,
                title: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        AppIcons.logo,
                        size: 18,
                        color: scheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _rename,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            _name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    if (showRight) ...[
                      const SizedBox(width: 8),
                      _SaveIndicator(state: _saveState),
                    ],
                  ],
                ),
                actions: [
                  PopupMenuButton<VoidCallback>(
                    tooltip: 'Mradi',
                    icon: const Icon(AppIcons.folder),
                    onSelected: (action) => action(),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: () => Navigator.pop(context),
                        child: const ListTile(
                          leading: Icon(AppIcons.back),
                          title: Text('Back to all projects'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _rename,
                        child: const ListTile(
                          leading: Icon(AppIcons.edit),
                          title: Text('Rename project'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _exportImage,
                        child: const ListTile(
                          leading: Icon(AppIcons.image),
                          title: Text('Export image (PNG)'),
                          trailing: Text('⇧⌘E'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _exportJson,
                        child: const ListTile(
                          leading: Icon(AppIcons.export),
                          title: Text('Export project (copy JSON)'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _importJson,
                        child: const ListTile(
                          leading: Icon(AppIcons.import),
                          title: Text('Import project (paste JSON)'),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Settings (pen, grid, rulers, snapping)',
                    onPressed: () => showCanvasSettings(context, c),
                    icon: const Icon(AppIcons.settings),
                  ),
                  IconButton(
                    tooltip: 'Undo (Cmd+Z)',
                    onPressed: c.canUndo ? c.undo : null,
                    icon: const Icon(AppIcons.undo),
                  ),
                  IconButton(
                    tooltip: 'Redo (Cmd+Shift+Z)',
                    onPressed: c.canRedo ? c.redo : null,
                    icon: const Icon(AppIcons.redo),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _run,
                    icon: const Icon(AppIcons.play, size: 18),
                    label: const Text('Run'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _showCode,
                    icon: const Icon(AppIcons.code, size: 18),
                    label: const Text('Get code'),
                  ),
                  if (showLeft && showRight)
                    IconButton(
                      tooltip: focused
                          ? 'Show panels (Cmd/Ctrl + \\)'
                          : 'Full canvas — collapse panels (Cmd/Ctrl + \\)',
                      isSelected: focused,
                      onPressed: _toggleFocusCanvas,
                      icon: const Icon(AppIcons.focusCanvas),
                    ),
                  if (!showRight)
                    Builder(
                      builder: (context) => IconButton(
                        tooltip: 'Properties',
                        icon: const Icon(AppIcons.properties),
                        onPressed: () => Scaffold.of(context).openEndDrawer(),
                      ),
                    ),
                  const SizedBox(width: 12),
                ],
                shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
              ),
              drawer: showLeft
                  ? null
                  : Drawer(width: 380, child: SafeArea(child: left)),
              endDrawer: showRight
                  ? null
                  : Drawer(child: SafeArea(child: right)),
              backgroundColor: scheme.surfaceContainer,
              body: Padding(
                padding: const EdgeInsets.all(_gap),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showLeft) ...[
                      _Panel(
                        collapsible: true,
                        width: _leftOpen ? 380 : null,
                        child: SidePanel(
                          controller: c,
                          expanded: _leftOpen,
                          onToggle: _toggleLeft,
                        ),
                      ),
                      const SizedBox(width: _gap),
                    ],
                    Expanded(
                      child: _Panel(
                        child: Listener(
                          onPointerDown: (_) => _focus.requestFocus(),
                          // When the pen taps outside a text box, the TextField
                          // drops focus after pointer down — take it back.
                          onPointerUp: (_) => _focus.requestFocus(),
                          child: DesignCanvas(controller: c),
                        ),
                      ),
                    ),
                    if (showRight) ...[
                      const SizedBox(width: _gap),
                      _Panel(
                        collapsible: true,
                        width: _rightOpen ? 300 : null,
                        child: _rightOpen
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      6,
                                      4,
                                      0,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Properties',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: scheme.outline,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Collapse panel',
                                          icon: const Icon(AppIcons.panelRight),
                                          onPressed: _toggleRight,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(child: right),
                                ],
                              )
                            : Column(
                                children: [
                                  const SizedBox(height: 6),
                                  IconButton(
                                    tooltip: 'Expand properties panel',
                                    icon: const Icon(AppIcons.panelRight),
                                    onPressed: _toggleRight,
                                  ),
                                  IconButton(
                                    tooltip: 'Properties',
                                    icon: const Icon(AppIcons.properties),
                                    onPressed: _toggleRight,
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator({required this.state});

  final _SaveState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, label, color) = switch (state) {
      _SaveState.loading => (AppIcons.clock, 'Opening…', scheme.outline),
      _SaveState.saving => (AppIcons.saving, 'Saving…', scheme.outline),
      _SaveState.saved => (AppIcons.saved, 'Imehifadhiwa', scheme.outline),
      _SaveState.error => (AppIcons.error, 'Haijahifadhiwa', scheme.error),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

/// Space between the panels and the window edges.
const _gap = 8.0;

/// A "floating" panel: rounded corners, a thin border and a soft shadow.
/// [collapsible] = true: the width animates to [width] (or the content's
/// intrinsic width when null, e.g. a collapsed panel).
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.width, this.collapsible = false});

  final Widget child;
  final double? width;
  final bool collapsible;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
    if (!collapsible) return panel;
    // AnimatedSize lays the content out at its final width and clips it
    // during the animation, so it is never squeezed or overflows.
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerLeft,
      child: SizedBox(width: width, child: panel),
    );
  }
}
