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

/// Skrini ya kubuni mradi mmoja.
///  - pana (≥ 1150): navigation bar + paneli zote mbili zinaonekana
///  - tablet (720–1149): navigation bar inakuwa drawer
///  - nyembamba (< 720): paneli zote mbili ni drawers
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

  /// Paneli za kushoto na kulia zimefunguliwa (zikikunjwa, canvas
  /// inapata nafasi zaidi).
  bool _leftOpen = true;
  bool _rightOpen = true;

  void _exportImage() =>
      showExportImage(context, pages: c.pages, initialIndex: c.pageIndex);

  void _toggleLeft() => setState(() => _leftOpen = !_leftOpen);
  void _toggleRight() => setState(() => _rightOpen = !_rightOpen);

  /// Uwanja mzima: kunja paneli zote mbili, au zifungue tena.
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

  /// Fungua mradi uliohifadhiwa, kisha hifadhi kila mabadiliko.
  Future<void> _restore() async {
    try {
      final saved = await _storage.load(widget.project.id);
      if (saved != null) c.loadJson(saved);
    } on FormatException {
      // Mradi ulioharibika: anza na skrini tupu badala ya kukwama
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
    // Hifadhi mabadiliko ya mwisho kabla ya kufunga
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
    // Alignment (kama Figma): Alt + A/H/D/W/V/S, Alt + C = katikati
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
    // Mwonekano
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

  /// Mtumiaji anaandika kwenye TextField (jina, X/Y, upana, utafutaji…)?
  /// Hapo Backspace/Delete/mishale ni za maandishi, si za kufuta au
  /// kusogeza kipengele.
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

  /// Jaribu muundo kama app (prototype).
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
        title: const Text('Jina la mradi'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ghairi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Hifadhi'),
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
      'Mradi (JSON) umenakiliwa — ubandike kwenye faili au tuma kwa mtu ✓',
    );
  }

  Future<void> _importJson() async {
    final input = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leta mradi (JSON)'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: input,
            maxLines: 14,
            autofocus: true,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
            decoration: const InputDecoration(
              hintText: 'Bandika hapa JSON uliyohamisha awali...',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ghairi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('Leta'),
          ),
        ],
      ),
    );
    input.dispose();
    if (text == null || text.trim().isEmpty) return;

    try {
      c.loadJson(jsonDecode(text) as Map<String, dynamic>, record: true);
      _toast('Mradi umeletwa: skrini ${c.pages.length} ✓');
    } catch (_) {
      _toast('Imeshindikana: JSON hii si mradi wa Rexa UI Studio');
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
                        tooltip: 'Miradi yote',
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
                          title: Text('Rudi kwenye miradi yote'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _rename,
                        child: const ListTile(
                          leading: Icon(AppIcons.edit),
                          title: Text('Badilisha jina la mradi'),
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
                          title: Text('Hamisha mradi (nakili JSON)'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _importJson,
                        child: const ListTile(
                          leading: Icon(AppIcons.import),
                          title: Text('Leta mradi (bandika JSON)'),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Mipangilio (kalamu, gridi, rulers, snapping)',
                    onPressed: () => showCanvasSettings(context, c),
                    icon: const Icon(AppIcons.settings),
                  ),
                  IconButton(
                    tooltip: 'Rudisha nyuma (Cmd+Z)',
                    onPressed: c.canUndo ? c.undo : null,
                    icon: const Icon(AppIcons.undo),
                  ),
                  IconButton(
                    tooltip: 'Rudia (Cmd+Shift+Z)',
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
                    label: const Text('Toa code'),
                  ),
                  if (showLeft && showRight)
                    IconButton(
                      tooltip: focused
                          ? 'Rudisha paneli (Cmd/Ctrl + \\)'
                          : 'Uwanja mzima — kunja paneli (Cmd/Ctrl + \\)',
                      isSelected: focused,
                      onPressed: _toggleFocusCanvas,
                      icon: const Icon(AppIcons.focusCanvas),
                    ),
                  if (!showRight)
                    Builder(
                      builder: (context) => IconButton(
                        tooltip: 'Sifa',
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
                          // Kalamu ikigusa nje ya kisanduku, TextField
                          // inaondoa focus baada ya pointer down — irudishe.
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
                                            'Sifa',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: scheme.outline,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Kunja paneli',
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
                                    tooltip: 'Funua paneli ya sifa',
                                    icon: const Icon(AppIcons.panelRight),
                                    onPressed: _toggleRight,
                                  ),
                                  IconButton(
                                    tooltip: 'Sifa',
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
      _SaveState.loading => (AppIcons.clock, 'Inafungua…', scheme.outline),
      _SaveState.saving => (AppIcons.saving, 'Inahifadhi…', scheme.outline),
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

/// Nafasi kati ya paneli na kingo za dirisha.
const _gap = 8.0;

/// Paneli "inayoelea": kona za mviringo, mpaka mwembamba na kivuli kidogo.
/// [collapsible] = true: upana unafuata [width] (au upana wa asili wa
/// maudhui ikiwa null, k.m. paneli iliyokunjwa) kwa animation.
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
    // AnimatedSize inapanga maudhui kwa upana wa mwisho na kuyakata wakati
    // wa animation, kwa hiyo hayabanwi wala kuzidi mipaka.
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerLeft,
      child: SizedBox(width: width, child: panel),
    );
  }
}
