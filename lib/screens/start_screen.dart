import 'package:flutter/material.dart';

import '../devices/phone_catalog.dart';
import '../icons/app_icons.dart';
import '../icons/icon_style.dart';
import '../models/device_frame.dart';
import '../services/project_storage.dart';
import '../state/editor_controller.dart';
import 'editor_screen.dart';
import 'new_design_screen.dart';

/// Vifaa vinavyoonyeshwa kwanza wakati wa kuanza mradi.
const _quickDevices = [
  'iphone-17-pro',
  'galaxy-s25',
  'pixel-10',
  'ipad-air-11',
  'galaxy-tab-s9',
  'macbook-air-13',
  'desktop',
  'watch-s11-46',
];

/// Ukurasa wa mwanzo: kuanzisha mradi mpya au kufungua uliopo.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key, this.storage});

  final ProjectStorage? storage;

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  late final _storage = widget.storage ?? ProjectStorage();
  final _name = TextEditingController();
  DeviceFrame _device = defaultDevice;
  List<ProjectInfo>? _projects;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final list = await _storage.list();
    if (mounted) setState(() => _projects = list);
  }

  Future<void> _create({ArtboardBuilder? artboard}) async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Andika jina la mradi kwanza');
      return;
    }
    final controller = EditorController(device: _device);
    if (artboard != null) {
      controller.loadJson({
        'pages': [artboard('e0').toJson()],
      });
    }
    final project = controller.toJson();
    final info = await _storage.create(name, project);
    _name.clear();
    setState(() => _nameError = null);
    await _open(info);
  }

  /// Chagua kifaa kwenye katalogi kamili (New Design), kisha anza mradi.
  Future<void> _createFromCatalog() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = 'Andika jina la mradi kwanza');
      return;
    }
    final artboard = await showNewDesign(context, createLabel: 'Anza kubuni');
    if (artboard != null && mounted) await _create(artboard: artboard);
  }

  Future<void> _open(ProjectInfo info) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorScreen(project: info, storage: _storage),
      ),
    );
    await _reload();
  }

  Future<void> _rename(ProjectInfo info) async {
    final ctrl = TextEditingController(text: info.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Badilisha jina'),
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
    await _storage.rename(info.id, name.trim());
    await _reload();
  }

  Future<void> _delete(ProjectInfo info) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Futa "${info.name}"?'),
        content: const Text(
          'Mradi huu na skrini zake zote zitafutwa kabisa kwenye kifaa hiki.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ghairi'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Futa'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await _storage.delete(info.id);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final scheme = Theme.of(context).colorScheme;

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Hero(),
        const SizedBox(height: 20),
        _newProjectCard(context),
      ],
    );
    final right = _projectsSection(context);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: SafeArea(
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 440,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(28),
                      child: left,
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(8, 28, 28, 28),
                      child: right,
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [left, const SizedBox(height: 28), right],
              ),
      ),
    );
  }

  Widget _newProjectCard(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Anza mradi mpya',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _create(),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              decoration: InputDecoration(
                labelText: 'Jina la mradi',
                hintText: 'k.m. App ya Benki',
                prefixIcon: const Icon(AppIcons.edit),
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 20),
            Text('Kifaa cha kuanzia', style: text.labelLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in _quickDevices)
                  if (deviceById(id) case final d)
                    ChoiceChip(
                      avatar: Icon(d.icon, size: 18),
                      label: Text(d.name),
                      selected: _device.id == d.id,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _device = d),
                    ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _createFromCatalog,
                icon: const Icon(AppIcons.search, size: 18),
                label: Text(
                  'Katalogi kamili: simu ${phoneCatalog.length} '
                  '(Apple, Samsung, Google)…',
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _create(),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(AppIcons.add),
              label: const Text(
                'Anza kubuni',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _projectsSection(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final projects = _projects;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Miradi yako',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 10),
            if (projects != null && projects.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${projects.length}'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (projects == null)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (projects.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              children: [
                Icon(AppIcons.folder, size: 56, color: scheme.outline),
                const SizedBox(height: 12),
                Text('Bado hakuna mradi', style: text.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Andika jina la mradi upande wa kushoto, kisha bonyeza '
                  '"Anza kubuni".',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.outline),
                ),
              ],
            ),
          )
        else
          GridView.extent(
            maxCrossAxisExtent: 280,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.95,
            children: [
              for (final p in projects)
                _ProjectCard(
                  info: p,
                  onOpen: () => _open(p),
                  onRename: () => _rename(p),
                  onDelete: () => _delete(p),
                ),
            ],
          ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final iconCount = IconStyle.values.fold(0, (n, s) => n + s.names.length);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFFDB2777)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(AppIcons.logo, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 20),
          const Text(
            'Rexa UI Studio',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Buni UI za simu, tablet, kompyuta na saa janja — kisha pata '
            'Flutter code papo hapo.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill('${devices.length - 1} vifaa'),
              _Pill('$iconCount+ icons'),
              const _Pill('Flutter code'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.info,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final ProjectInfo info;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final device = deviceById(info.deviceId);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: scheme.primaryContainer.withValues(alpha: 0.45),
                child: Icon(device.icon, size: 56, color: scheme.primary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Skrini ${info.screens} · ${device.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timeAgo(info.updatedAt),
                          style: text.bodySmall?.copyWith(
                            color: scheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<VoidCallback>(
                    icon: const Icon(AppIcons.more),
                    onSelected: (action) => action(),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: onOpen, child: const Text('Fungua')),
                      PopupMenuItem(
                        value: onRename,
                        child: const Text('Badilisha jina'),
                      ),
                      PopupMenuItem(value: onDelete, child: const Text('Futa')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "dakika 5 zilizopita", "jana", ...
String timeAgo(DateTime time, [DateTime? now]) {
  final d = (now ?? DateTime.now()).difference(time);
  if (d.inMinutes < 1) return 'Sasa hivi';
  if (d.inHours < 1) return 'Dakika ${d.inMinutes} zilizopita';
  if (d.inDays < 1) return 'Saa ${d.inHours} zilizopita';
  if (d.inDays == 1) return 'Jana';
  return 'Siku ${d.inDays} zilizopita';
}
