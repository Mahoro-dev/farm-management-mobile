import 'package:flutter/material.dart';

import '../session.dart';
import '../store.dart';
import '../theme.dart';
import 'cow_page.dart';

class HerdPage extends StatefulWidget {
  const HerdPage({super.key, required this.session, this.filter = 'all'});
  final FarmSession session;
  final String filter;

  @override
  State<HerdPage> createState() => _HerdPageState();
}

class _HerdPageState extends State<HerdPage> {
  List<CowRecord> _cows = [];
  Set<String> _sick = {};
  Set<String> _held = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.session.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final farmId = widget.session.farmId;
    if (farmId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final cows = await widget.session.store.cows(farmId);
    final sick = await widget.session.store.watch(farmId, 'sick');
    final held = await widget.session.store.watch(farmId, 'withdrawal');
    if (!mounted) return;
    setState(() {
      _cows = cows;
      _sick = sick.map((item) => item.animalId).toSet();
      _held = held.map((item) => item.animalId).toSet();
      _loading = false;
    });
  }

  List<CowRecord> get _visible {
    return _cows.where((cow) {
      switch (widget.filter) {
        case 'female':
          return cow.sex == 'FEMALE';
        case 'male':
          return cow.sex == 'MALE';
        case 'sick':
          return _sick.contains(cow.id);
        case 'withdrawal':
          return _held.contains(cow.id);
        default:
          return true;
      }
    }).toList();
  }

  bool _matches(CowRecord cow, String query) {
    if (query.isEmpty) return false;
    final name = (cow.name ?? '').toLowerCase();
    final number = cow.number.toLowerCase();
    final tags = cow.tags.map((tag) => tag.toLowerCase());
    return number.contains(query) || name.contains(query) || tags.any((tag) => tag.contains(query));
  }

  String get _title {
    switch (widget.filter) {
      case 'female':
        return 'Females';
      case 'male':
        return 'Males';
      case 'sick':
        return 'Sick cows';
      case 'withdrawal':
        return 'On withdrawal';
      default:
        return 'Herd';
    }
  }

  void _open(CowRecord cow) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CowPage(session: widget.session, cow: cow)));
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FarmColors.accent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Autocomplete<CowRecord>(
                  displayStringForOption: (cow) => cow.label,
                  optionsBuilder: (value) {
                    final query = value.text.trim().toLowerCase();
                    if (query.isEmpty) return const Iterable<CowRecord>.empty();
                    return visible.where((cow) => _matches(cow, query));
                  },
                  onSelected: _open,
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Search number, name, or tag',
                        prefixIcon: Icon(Icons.search, color: Desk.muted(context)),
                      ),
                      onSubmitted: (_) => onSubmitted(),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    final items = options.toList();
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        color: Desk.card(context),
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Desk.line(context))),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 280, maxWidth: 420),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final cow = items[index];
                              return ListTile(
                                title: Text(cow.label),
                                subtitle: Text(_subtitle(cow), style: TextStyle(color: Desk.muted(context))),
                                onTap: () => onSelected(cow),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text('${visible.length} cows', style: TextStyle(color: Desk.muted(context))),
                const SizedBox(height: 8),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text('Nothing in this list yet. Sync while the phone is online.', style: TextStyle(color: Desk.muted(context))),
                  )
                else
                  ...visible.map((cow) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Desk.card(context),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Desk.line(context))),
                          child: ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            title: Text(cow.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(_subtitle(cow), style: TextStyle(color: Desk.muted(context))),
                            trailing: _sick.contains(cow.id)
                                ? const Text('Sick', style: TextStyle(color: FarmColors.warn, fontWeight: FontWeight.w700))
                                : Icon(Icons.chevron_right, color: Desk.muted(context)),
                            onTap: () => _open(cow),
                          ),
                        ),
                      )),
              ],
            ),
    );
  }

  String _subtitle(CowRecord cow) {
    final bits = <String>[
      if (cow.sex != null) cow.sex!.toLowerCase(),
      if (cow.status != null) cow.status!.toLowerCase().replaceAll('_', ' '),
      if (_held.contains(cow.id)) 'withdrawal',
    ];
    return bits.join(' · ');
  }
}
