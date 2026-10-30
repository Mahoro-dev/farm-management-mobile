import 'package:flutter/material.dart';

import '../session.dart';
import '../store.dart';
import '../theme.dart';
import 'cow_page.dart';

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key, required this.session, required this.kind});
  final FarmSession session;
  final String kind;

  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  List<Notice> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final farmId = widget.session.farmId;
    if (farmId == null) return;
    final items = await widget.session.store.notices(farmId, widget.kind);
    if (mounted) setState(() => _items = items);
  }

  String get _title {
    switch (widget.kind) {
      case 'vaccine':
        return 'Due vaccines';
      case 'expiry':
        return 'Medicine expiring';
      case 'calving':
        return 'Expected calving';
      default:
        return 'Active withdrawals';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: _items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'Nothing in this list. Sync from Menu while the phone is on the farm network.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Desk.muted(context), height: 1.4),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Material(
                  color: Desk.card(context),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Desk.line(context))),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(item.detail, style: TextStyle(color: Desk.muted(context))),
                    trailing: item.animalId == null ? null : Icon(Icons.chevron_right, color: Desk.muted(context)),
                    onTap: item.animalId == null ? null : () => _openCow(item),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _openCow(Notice item) async {
    final farmId = widget.session.farmId;
    final animalId = item.animalId;
    if (farmId == null || animalId == null) return;
    final cows = await widget.session.store.cows(farmId);
    CowRecord? cow;
    for (final candidate in cows) {
      if (candidate.id == animalId) cow = candidate;
    }
    if (!mounted || cow == null) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CowPage(session: widget.session, cow: cow!)));
  }
}
