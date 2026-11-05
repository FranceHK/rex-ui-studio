import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons/app_icons.dart';
import '../models/device_frame.dart';
import '../models/ui_element.dart';
import '../widgets/element_view.dart';

/// "Run": try the design as an app. The screen is shown inside the device
/// at its real size; when the artboard is taller than the device screen
/// you can scroll down. Elements with a "link" open another screen.
class RunScreen extends StatefulWidget {
  const RunScreen({super.key, required this.pages, this.initialIndex = 0});

  final List<DesignPage> pages;
  final int initialIndex;

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  late int _index = widget.initialIndex.clamp(0, widget.pages.length - 1);
  final _history = <int>[];
  bool _bezel = true;
  final _scroll = ScrollController();

  DesignPage get page => widget.pages[_index];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(int index, {bool remember = true}) {
    if (index == _index || index < 0 || index >= widget.pages.length) return;
    setState(() {
      if (remember) _history.add(_index);
      _index = index;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _back() {
    if (_history.isEmpty) return;
    setState(() => _index = _history.removeLast());
  }

  void _follow(UiElement e) {
    final target = widget.pages.indexWhere((p) => p.id == e.link);
    if (target >= 0) _go(target);
  }

  /// Size of the device screen (the viewport). When the artboard is
  /// taller, its content scrolls inside this viewport.
  Size get _viewport {
    final p = page;
    if (p.device.id == customDeviceId) return p.size;
    final s = p.device.size;
    final oriented = p.landscape ? s.flipped : s;
    return Size(
      oriented.width,
      oriented.height < p.size.height ? oriented.height : p.size.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = page;
    final viewport = _viewport;
    final scrolls = p.size.height > viewport.height + 0.5;
    final corner = p.device.cornerRadius(viewport);
    final bezel = _bezel ? viewport.shortestSide * 0.035 + 4 : 0.0;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _go(_index + 1, remember: false),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _go(_index - 1, remember: false),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFF0B1220),
          appBar: AppBar(
            backgroundColor: const Color(0xFF111A2E),
            foregroundColor: Colors.white,
            leading: IconButton(
              tooltip: 'Close (Esc)',
              icon: const Icon(AppIcons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Row(
              children: [
                const Icon(AppIcons.play, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Run · ${p.name}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            actions: [
              if (_history.isNotEmpty)
                TextButton.icon(
                  onPressed: _back,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  icon: const Icon(AppIcons.back, size: 18),
                  label: const Text('Back'),
                ),
              IconButton(
                tooltip: 'Previous screen (←)',
                onPressed: _index > 0
                    ? () => _go(_index - 1, remember: false)
                    : null,
                icon: const Icon(AppIcons.previous),
              ),
              Text(
                '${_index + 1} / ${widget.pages.length}',
                style: const TextStyle(color: Colors.white70),
              ),
              IconButton(
                tooltip: 'Next screen (→)',
                onPressed: _index < widget.pages.length - 1
                    ? () => _go(_index + 1, remember: false)
                    : null,
                icon: const Icon(AppIcons.next),
              ),
              IconButton(
                tooltip: _bezel ? 'Hide device frame' : 'Show device frame',
                onPressed: () => setState(() => _bezel = !_bezel),
                icon: Icon(
                  AppIcons.phone,
                  color: _bezel ? Colors.white : Colors.white38,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: FittedBox(
                      child: Container(
                        padding: EdgeInsets.all(bezel),
                        decoration: BoxDecoration(
                          color: _bezel ? const Color(0xFF1D2433) : null,
                          borderRadius: BorderRadius.circular(corner + bezel),
                          boxShadow: const [
                            BoxShadow(color: Colors.black54, blurRadius: 40),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(corner),
                          child: SizedBox.fromSize(
                            size: viewport,
                            child: ColoredBox(
                              color: p.background,
                              child: Scrollbar(
                                controller: _scroll,
                                thumbVisibility: scrolls,
                                child: SingleChildScrollView(
                                  key: ValueKey(p.id),
                                  controller: _scroll,
                                  physics: scrolls
                                      ? const ClampingScrollPhysics()
                                      : const NeverScrollableScrollPhysics(),
                                  child: SizedBox.fromSize(
                                    size: p.size,
                                    child: Stack(
                                      children: [
                                        for (final e in p.visibleElements)
                                          Positioned.fromRect(
                                            rect: e.rect,
                                            child: e.link == null
                                                ? ElementView(element: e)
                                                : MouseRegion(
                                                    cursor: SystemMouseCursors
                                                        .click,
                                                    child: GestureDetector(
                                                      onTap: () => _follow(e),
                                                      child: ElementView(
                                                        element: e,
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  '${p.device.name} · screen ${viewport.width.round()}×'
                  '${viewport.height.round()}'
                  '${scrolls ? ' · content ${p.size.height.round()} (scroll down)' : ''}'
                  '${p.elements.any((e) => e.link != null) ? ' · tap linked elements' : ''}',
                  style: TextStyle(color: scheme.outlineVariant, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
