import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../devices/artboard_factory.dart';
import '../devices/device_preset.dart';
import '../devices/device_preset_repository.dart';
import '../icons/app_icons.dart';
import '../models/ui_element.dart';
import '../widgets/device_preview.dart';

/// Inajenga artboard mpya ikipewa id.
typedef ArtboardBuilder = DesignPage Function(String id);

const _backgrounds = [
  Colors.white,
  Color(0xFFF8FAFC),
  Color(0xFFF1F5F9),
  Color(0xFF0F172A),
  Color(0xFF000000),
  Color(0xFFEEF2FF),
];

/// Fungua dirisha la New Design. Linarudisha builder ya artboard au null.
Future<ArtboardBuilder?> showNewDesign(
  BuildContext context, {
  CustomPresetManager? manager,
  String createLabel = 'Tengeneza design',
}) {
  return Navigator.of(context).push<ArtboardBuilder>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          NewDesignScreen(manager: manager, createLabel: createLabel),
    ),
  );
}

/// Dirisha la kuchagua kifaa na kutengeneza artboard mpya.
class NewDesignScreen extends StatefulWidget {
  const NewDesignScreen({
    super.key,
    this.manager,
    this.repository,
    this.createLabel = 'Tengeneza design',
  });

  final CustomPresetManager? manager;
  final DevicePresetRepository? repository;
  final String createLabel;

  @override
  State<NewDesignScreen> createState() => _NewDesignScreenState();
}

class _NewDesignScreenState extends State<NewDesignScreen> {
  late final repo = widget.repository ?? DevicePresetRepository();
  late final manager = widget.manager ?? CustomPresetManager();
  late final search = DeviceSearchController(repo, manager);
  final orientation = OrientationController();
  final fold = FoldableDisplayController();

  final _searchText = TextEditingController();
  final _name = TextEditingController();
  final _width = TextEditingController();
  final _height = TextEditingController();

  CustomPreset? _custom;
  bool _bezel = true;
  bool _safeArea = true;
  Color _background = Colors.white;

  @override
  void initState() {
    super.initState();
    if (!manager.loaded) manager.load();
    for (final l in [search, orientation, fold, manager]) {
      l.addListener(_changed);
    }
    _select(repo.byId('iphone-17-pro') ?? repo.presets.first);
  }

  @override
  void dispose() {
    for (final l in [orientation, fold, manager]) {
      l.removeListener(_changed);
    }
    search.dispose();
    orientation.dispose();
    fold.dispose();
    if (widget.manager == null) manager.dispose();
    for (final c in [_searchText, _name, _width, _height]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {});

  void _update(VoidCallback fn) => setState(fn);

  DevicePreset? get _preset => _custom == null ? fold.preset : null;
  DeviceDisplay? get _display => _custom == null ? fold.display : null;

  void _select(DevicePreset p) {
    _custom = null;
    fold.setPreset(p);
    _syncFields();
  }

  void _selectCustom(CustomPreset c) {
    setState(() => _custom = c);
    _syncFields();
  }

  void _setFolded(bool folded) {
    fold.setFolded(folded);
    _syncFields();
  }

  /// Weka jina na ukubwa wa skrini iliyochaguliwa kwenye sehemu za kuandika.
  void _syncFields() {
    final (name, size) = switch (_custom) {
      final c? => (c.name, c.size),
      null => (_preset!.frameName(fold.role), _display!.artboard),
    };
    _name.text = name;
    _width.text = _fmt(size.width);
    _height.text = _fmt(size.height);
  }

  /// Ukubwa ulioandikwa (wima); null kama si sahihi.
  Size? get _enteredSize {
    final w = double.tryParse(_width.text);
    final h = double.tryParse(_height.text);
    if (w == null || h == null || w < 50 || h < 50 || w > 8000 || h > 8000) {
      return null;
    }
    return Size(w, h);
  }

  Size get _portrait =>
      _enteredSize ??
      _custom?.size ??
      _display?.artboard ??
      const Size(375, 812);

  ArtboardBuilder? get _builder {
    final size = _enteredSize;
    if (size == null) return null;
    final name = _name.text.trim();
    final landscape = orientation.landscape;
    if (_custom case final c?) {
      return (id) => ArtboardFactory.fromCustom(
        id,
        CustomPreset(id: c.id, name: name.isEmpty ? c.name : name, size: size),
        landscape: landscape,
        background: _background,
      );
    }
    final preset = _preset!;
    final role = fold.role;
    final safe = _safeArea;
    final bg = _background;
    return (id) {
      final page = ArtboardFactory.fromPreset(
        id,
        preset,
        role: role,
        landscape: landscape,
        safeArea: safe,
        background: bg,
        size: size,
      );
      return name.isEmpty ? page : page.copyWith(name: name);
    };
  }

  void _create() {
    final builder = _builder;
    if (builder == null) {
      _snack('Weka upana na urefu sahihi (50–8000).');
      return;
    }
    if (_preset case final p?) manager.markUsed(p.id);
    Navigator.of(context).pop(builder);
  }

  Future<void> _saveCustom() async {
    final size = _enteredSize;
    if (size == null) {
      _snack('Weka upana na urefu sahihi (50–8000).');
      return;
    }
    final name = _name.text.trim().isEmpty
        ? 'Preset ${_fmt(size.width)}×${_fmt(size.height)}'
        : _name.text.trim();
    final saved = await manager.addCustom(name, size, basedOn: _preset?.id);
    if (!mounted) return;
    _selectCustom(saved);
    _snack('Preset "$name" imehifadhiwa');
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final scheme = Theme.of(context).colorScheme;

    final left = _LeftPanel(state: this);
    final center = _CenterPanel(state: this);
    final right = _RightPanel(state: this);

    final Widget body;
    if (width >= 1180) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 320, child: left),
          const VerticalDivider(width: 1),
          Expanded(child: center),
          const VerticalDivider(width: 1),
          SizedBox(width: 340, child: right),
        ],
      );
    } else if (width >= 760) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 300, child: left),
          const VerticalDivider(width: 1),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Preview'),
                      Tab(text: 'Maelezo'),
                    ],
                  ),
                  Expanded(child: TabBarView(children: [center, right])),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      body = DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Vifaa'),
                Tab(text: 'Preview'),
                Tab(text: 'Maelezo'),
              ],
            ),
            Expanded(child: TabBarView(children: [left, center, right])),
          ],
        ),
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        appBar: AppBar(
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: 'Funga',
            icon: const Icon(AppIcons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Design mpya',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1),
          ),
        ),
        body: body,
        bottomNavigationBar: _BottomBar(state: this),
      ),
    );
  }
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

// ---------------- Kushoto: watengenezaji, familia, modeli ----------------

class _LeftPanel extends StatelessWidget {
  const _LeftPanel({required this.state});
  final _NewDesignScreenState state;

  @override
  Widget build(BuildContext context) {
    final s = state.search;
    final scheme = Theme.of(context).colorScheme;
    final results = s.results;
    final showCustom =
        s.source == PresetSource.all &&
        s.manufacturer == null &&
        s.family == null &&
        !s.foldableOnly &&
        state.manager.custom.isNotEmpty;

    return Material(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: state._searchText,
              onChanged: s.setQuery,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Tafuta kifaa… (k.m. s25 ultra, fold)',
                prefixIcon: const Icon(AppIcons.search, size: 20),
                suffixIcon: s.query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Futa utafutaji',
                        icon: const Icon(AppIcons.close, size: 18),
                        onPressed: () {
                          state._searchText.clear();
                          s.setQuery('');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<PresetSource>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: PresetSource.all, label: Text('Zote')),
                ButtonSegment(
                  value: PresetSource.favorites,
                  label: Text('Vipendwa'),
                  icon: Icon(AppIcons.star, size: 16),
                ),
                ButtonSegment(
                  value: PresetSource.recents,
                  label: Text('Karibuni'),
                  icon: Icon(AppIcons.clock, size: 16),
                ),
              ],
              selected: {s.source},
              onSelectionChanged: (v) => s.setSource(v.first),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final m in [null, ...Manufacturer.values])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(m?.label ?? 'Wote'),
                      selected: s.manufacturer == m,
                      showCheckmark: false,
                      onSelected: (_) => s.setManufacturer(m),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: s.family,
                    key: ValueKey('family-${s.manufacturer}'),
                    isExpanded: true,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: 'Familia',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(child: Text('Familia zote')),
                      for (final f in s.families)
                        DropdownMenuItem(value: f, child: Text(f)),
                    ],
                    onChanged: s.setFamily,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Fold'),
                  avatar: const Icon(AppIcons.foldable, size: 16),
                  tooltip: 'Zinazokunjika tu',
                  selected: s.foldableOnly,
                  showCheckmark: false,
                  onSelected: s.setFoldableOnly,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Text(
              '${results.length} vifaa',
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
          ),
          Expanded(
            child: results.isEmpty && !showCustom
                ? _EmptyResults(source: s.source)
                : ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      if (showCustom) ...[
                        const _GroupHeader('Preset zako'),
                        for (final c in state.manager.custom)
                          _CustomTile(state: state, preset: c),
                      ],
                      ..._grouped(results),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Iterable<Widget> _grouped(List<DevicePreset> results) sync* {
    final grouped = state.search.source == PresetSource.all;
    String? last;
    for (final p in results) {
      final header = '${p.manufacturer.label} · ${p.family}';
      if (grouped && header != last) {
        yield _GroupHeader(header);
        last = header;
      }
      yield _PresetTile(state: state, preset: p);
    }
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.outline,
      ),
    ),
  );
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.source});
  final PresetSource source;

  @override
  Widget build(BuildContext context) {
    final msg = switch (source) {
      PresetSource.favorites => 'Bado huna vipendwa. Bonyeza ★ kwenye kifaa.',
      PresetSource.recents => 'Vifaa utakavyotumia vitaonekana hapa.',
      PresetSource.all => 'Hakuna kifaa kinacholingana.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.state, required this.preset});
  final _NewDesignScreenState state;
  final DevicePreset preset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = preset.primary;
    final selected = state._preset?.id == preset.id;
    final fav = state.manager.isFavorite(preset.id);
    final size = d.artboard;
    final unit = preset.logicalUnit.label;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ListTile(
        dense: true,
        selected: selected,
        selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          preset.foldable ? AppIcons.foldable : AppIcons.phone,
          size: 20,
        ),
        title: Text(
          preset.model,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${d.diagonal == null ? '' : '${d.diagonal}" · '}'
          '${_fmt(size.width)}×${_fmt(size.height)} $unit'
          '${d.logicalVerified ? '' : ' (makisio)'}'
          '${preset.foldable ? ' · ${preset.displays.length} skrini' : ''}',
        ),
        trailing: IconButton(
          tooltip: fav ? 'Ondoa kwenye vipendwa' : 'Weka kwenye vipendwa',
          icon: Icon(
            fav ? Icons.star_rounded : Icons.star_outline_rounded,
            color: fav ? const Color(0xFFF59E0B) : scheme.outline,
          ),
          onPressed: () => state.manager.toggleFavorite(preset.id),
        ),
        onTap: () => state._select(preset),
      ),
    );
  }
}

class _CustomTile extends StatelessWidget {
  const _CustomTile({required this.state, required this.preset});
  final _NewDesignScreenState state;
  final CustomPreset preset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ListTile(
        dense: true,
        selected: state._custom?.id == preset.id,
        selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: const Icon(AppIcons.edit, size: 20),
        title: Text(
          preset.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${_fmt(preset.size.width)}×${_fmt(preset.size.height)} · maalum',
        ),
        trailing: IconButton(
          tooltip: 'Futa preset',
          icon: const Icon(AppIcons.trash, size: 18),
          onPressed: () {
            if (state._custom?.id == preset.id) {
              state._select(state.repo.presets.first);
            }
            state.manager.deleteCustom(preset.id);
          },
        ),
        onTap: () => state._selectCustom(preset),
      ),
    );
  }
}

// ---------------- Katikati: preview ----------------

class _CenterPanel extends StatelessWidget {
  const _CenterPanel({required this.state});
  final _NewDesignScreenState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final landscape = state.orientation.landscape;
    final display = state._display;
    final preset = state._preset;
    final portrait = state._portrait;
    final size = state.orientation.apply(portrait);
    final safe = display?.safeArea;
    final unit = preset?.logicalUnit.label ?? 'px';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Wima'),
                    icon: Icon(AppIcons.phone, size: 16),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Mlalo'),
                    icon: Icon(AppIcons.rotate, size: 16),
                  ),
                ],
                selected: {landscape},
                onSelectionChanged: (v) => state.orientation.set(v.first),
              ),
              if (preset != null && preset.foldable)
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(
                        preset.displays
                                    .firstWhere((d) => !d.role.folded)
                                    .role ==
                                DisplayRole.inner
                            ? 'Imefunguliwa'
                            : 'Kuu',
                      ),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text(
                        preset.displays.any((d) => d.role == DisplayRole.cover)
                            ? 'Cover'
                            : 'Imekunjwa',
                      ),
                    ),
                  ],
                  selected: {state.fold.folded},
                  onSelectionChanged: (v) => state._setFolded(v.first),
                ),
              _ToggleChip(
                label: 'Bezel',
                value: state._bezel,
                onChanged: (v) => state._update(() => state._bezel = v),
              ),
              _ToggleChip(
                label: 'Safe area',
                value: state._safeArea && safe != null,
                onChanged: safe == null
                    ? null
                    : (v) => state._update(() => state._safeArea = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: DevicePreview(
                  key: ValueKey('${preset?.id}-${state.fold.role}-$landscape'),
                  size: size,
                  cornerRadius:
                      display?.cornerRadius ??
                      (preset?.manufacturer == Manufacturer.apple ? 44 : 28),
                  bezel: state._bezel,
                  safeArea: safe == null
                      ? null
                      : landscape
                      ? rotateSafeArea(safe)
                      : safe,
                  showSafeArea: state._safeArea,
                  cutouts: [
                    for (final c in display?.cutouts ?? const <DisplayCutout>[])
                      landscape ? rotateCutout(c) : c,
                  ],
                  background: state._background,
                  label: state._name.text,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              Text(
                '${_fmt(size.width)} × ${_fmt(size.height)} $unit',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (display != null)
                Text(
                  '${_fmt(state.orientation.apply(display.physical).width)} × '
                  '${_fmt(state.orientation.apply(display.physical).height)} px '
                  'halisi · ${display.role.label}',
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) =>
      FilterChip(label: Text(label), selected: value, onSelected: onChanged);
}

// ---------------- Kulia: maelezo ya kifaa ----------------

class _RightPanel extends StatelessWidget {
  const _RightPanel({required this.state});
  final _NewDesignScreenState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final preset = state._preset;
    final d = state._display;
    final custom = state._custom;
    const unknown = 'Haijulikani';

    String? diag(double? v) => v == null ? null : '$v"';

    return Material(
      color: scheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            custom?.name ?? preset!.model,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          if (preset != null)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Badge(
                  '${preset.manufacturer.label} · ${preset.family} · '
                  '${preset.releaseYear}',
                ),
                _StatusBadge(preset.status),
              ],
            )
          else
            const _Badge('Preset yako'),
          const SizedBox(height: 18),
          TextField(
            controller: state._name,
            onChanged: (_) => state._changed(),
            decoration: const InputDecoration(
              labelText: 'Jina la artboard',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  controller: state._width,
                  label: 'Upana',
                  onChanged: state._changed,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('×'),
              ),
              Expanded(
                child: _NumberField(
                  controller: state._height,
                  label: 'Urefu',
                  onChanged: state._changed,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Ukubwa wa kimantiki ukiwa wima. Ukibadilisha, metadata ya '
              'kifaa inabaki.',
              style: TextStyle(fontSize: 11, color: scheme.outline),
            ),
          ),
          if (d != null && !d.logicalVerified)
            _Warning(
              'Ukubwa wa kimantiki (dp) wa skrini hii haujathibitishwa. '
              '${d.logicalSource}. Hakiki kabla ya kutumia kwa vipimo kamili.',
            ),
          if (preset != null && d != null) ...[
            const SizedBox(height: 18),
            const _SectionTitle('Skrini'),
            _Row('Skrini', d.role.label),
            _Row(
              'Ukubwa',
              diag(d.diagonal) ?? unknown,
              ok: d.isVerified('diagonal'),
            ),
            _Row(
              'Resolution halisi',
              '${_fmt(d.physical.width)} × ${_fmt(d.physical.height)} px',
              ok: d.isVerified('physical'),
            ),
            _Row(
              'Ukubwa wa kimantiki',
              '${_fmt(d.artboard.width)} × ${_fmt(d.artboard.height)} '
                  '${preset.logicalUnit.label}'
                  '${d.logicalVerified ? '' : ' (makisio)'}',
              ok: d.logicalVerified,
            ),
            _Row(
              'Scale',
              d.scale == null
                  ? unknown
                  : preset.manufacturer == Manufacturer.apple
                  ? '@${_fmt(d.scale!)}x'
                  : '${d.scale}× (${d.densityDpi} dpi)',
              ok: d.scale != null,
            ),
            _Row(
              'Density ya skrini',
              d.ppi == null ? unknown : '${_fmt(d.ppi!)} ppi (pixel halisi)',
              ok: d.isVerified('ppi'),
            ),
            _Row(
              'Refresh rate',
              d.refresh ?? unknown,
              ok: d.isVerified('refresh'),
            ),
            _Row('Aina ya skrini', d.type ?? unknown, ok: d.isVerified('type')),
            _Row('Mwelekeo', state.orientation.landscape ? 'Mlalo' : 'Wima'),
            _Row(
              'Safe area',
              d.safeArea == null
                  ? unknown
                  : 'juu ${_fmt(d.safeArea!.top)} · chini '
                        '${_fmt(d.safeArea!.bottom)}'
                        '${d.safeAreaVerified ? '' : ' (mwongozo)'}',
              ok: d.safeAreaVerified,
            ),
            if (d.cutouts.isNotEmpty)
              _Row(
                'Cutouts',
                '${d.cutouts.length} (kamera)',
                ok: d.isVerified('cutouts'),
              ),
            if (d.logicalSource case final src?) _Row('Chanzo cha frame', src),
          ],
          const SizedBox(height: 18),
          const _SectionTitle('Rangi ya background'),
          Wrap(
            spacing: 8,
            children: [
              for (final c in _backgrounds)
                Tooltip(
                  message:
                      '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => state._update(() => state._background = c),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: state._background == c ? 3 : 1,
                          color: state._background == c
                              ? scheme.primary
                              : scheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (preset != null) ...[
            const SizedBox(height: 18),
            const _SectionTitle('Chanzo rasmi'),
            SelectableText(
              preset.sourceUrl,
              style: TextStyle(fontSize: 12, color: scheme.primary),
            ),
            for (final n in preset.notes)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '• $n',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.ok = true});
  final String label;
  final String value;

  /// false = thamani haijathibitishwa.
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: scheme.outline),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!ok)
            Tooltip(
              message: 'Haijathibitishwa',
              child: Icon(AppIcons.error, size: 15, color: scheme.tertiary),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.5, color: c, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final VerificationStatus status;

  @override
  Widget build(BuildContext context) => _Badge(
    status.label,
    color: switch (status) {
      VerificationStatus.verified => const Color(0xFF079455),
      VerificationStatus.partial => const Color(0xFFB54708),
      VerificationStatus.unverified => const Color(0xFFD92D20),
    },
  );
}

class _Warning extends StatelessWidget {
  const _Warning(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFAEB),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFFEDF89)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(AppIcons.error, size: 16, color: Color(0xFFB54708)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF7A2E0E)),
          ),
        ),
      ],
    ),
  );
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: (_) => onChanged(),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
    decoration: InputDecoration(labelText: label, isDense: true),
  );
}

// ---------------- Chini: vitendo ----------------

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state});
  final _NewDesignScreenState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final valid = state._enteredSize != null;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Ghairi'),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: valid ? state._saveCustom : null,
                icon: const Icon(AppIcons.add, size: 18),
                label: const Text('Hifadhi preset'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: valid ? state._create : null,
                icon: const Icon(AppIcons.check, size: 18),
                label: Text(state.widget.createLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
