import 'package:flutter/material.dart';

import '../session.dart';
import '../theme.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key, required this.session});
  final FarmSession session;

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  static const _order = ['milk', 'mating', 'visit', 'treatment', 'vaccination'];
  Map<String, int> _waiting = {};
  Map<String, String> _problems = {};

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    widget.session.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    _load();
  }

  Future<void> _load() async {
    final items = await widget.session.store.pending();
    final counts = <String, int>{};
    final problems = <String, String>{};
    for (final item in items) {
      counts[item.kind] = (counts[item.kind] ?? 0) + 1;
      final error = item.error;
      if (error != null && error.isNotEmpty) problems[item.kind] ??= error;
    }
    if (mounted) {
      setState(() {
        _waiting = counts;
        _problems = problems;
      });
    }
  }

  String _label(String kind) {
    switch (kind) {
      case 'milk':
        return 'Milk';
      case 'mating':
        return 'Mating';
      case 'visit':
        return 'Visit';
      case 'treatment':
        return 'Treatment';
      case 'vaccination':
        return 'Vaccination';
      default:
        return kind;
    }
  }

  List<String> get _kinds {
    final known = _order.where(_waiting.containsKey);
    final extra = _waiting.keys.where((kind) => !_order.contains(kind));
    return [...known, ...extra];
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(session.userName ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(session.farmName ?? '', style: TextStyle(color: Desk.muted(context))),
          const SizedBox(height: 18),
          Text('Not synced', style: TextStyle(color: Desk.muted(context), fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (_kinds.isEmpty)
            Text('Nothing waiting.', style: TextStyle(color: Desk.muted(context)))
          else
            Material(
              color: Desk.card(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Desk.line(context))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    for (final kind in _kinds)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_label(kind), style: const TextStyle(fontWeight: FontWeight.w700)),
                                  if (_problems[kind] != null)
                                    Text(_problems[kind]!, style: const TextStyle(color: FarmColors.warn, fontSize: 12)),
                                ],
                              ),
                            ),
                            Text('${_waiting[kind]}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          Text('Appearance', style: TextStyle(color: Desk.muted(context), fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'system', label: Text('System')),
              ButtonSegment(value: 'light', label: Text('Light')),
              ButtonSegment(value: 'dark', label: Text('Dark')),
            ],
            selected: {session.themeMode},
            onSelectionChanged: (value) => session.setTheme(value.first),
          ),
          const SizedBox(height: 18),
          if (session.farms.length > 1)
            DropdownButtonFormField<String>(
              initialValue: session.farmId,
              decoration: const InputDecoration(labelText: 'Farm'),
              items: session.farms.map((farm) => DropdownMenuItem(value: farm['id'], child: Text(farm['name']!))).toList(),
              onChanged: (id) {
                final farm = session.farms.firstWhere((item) => item['id'] == id);
                session.selectFarm(farm['id']!, farm['name']!);
              },
            ),
          const SizedBox(height: 12),
          _Row(icon: Icons.sync, title: 'Sync now', subtitle: session.online ? '${session.pendingCount} waiting' : 'Offline · ${session.pendingCount} saved on this phone', onTap: session.sync),
          _Row(icon: Icons.logout, title: 'Sign out', subtitle: 'Stay signed out until the next shift', onTap: session.logout),
          if (session.message != null) ...[
            const SizedBox(height: 12),
            Text(session.message!, style: const TextStyle(color: FarmColors.warn)),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Desk.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Desk.line(context))),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Icon(icon, color: FarmColors.accent),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle, style: TextStyle(color: Desk.muted(context))),
          onTap: onTap,
        ),
      ),
    );
  }
}
