import 'package:flutter/material.dart';

import '../session.dart';
import '../theme.dart';
import 'clinic_page.dart';
import 'mating_page.dart';
import 'milk_page.dart';
import 'notices_page.dart';
import 'treatment_page.dart';
import 'vaccine_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.session, required this.onOpenScan});
  final FarmSession session;
  final VoidCallback onOpenScan;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _vaccines = 0;
  int _expiring = 0;
  int _calving = 0;
  int _held = 0;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    widget.session.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final farmId = widget.session.farmId;
    if (farmId == null) return;
    final items = await widget.session.store.notices(farmId);
    if (!mounted) return;
    setState(() {
      _vaccines = items.where((item) => item.kind == 'vaccine').length;
      _expiring = items.where((item) => item.kind == 'expiry').length;
      _calving = items.where((item) => item.kind == 'calving').length;
      _held = items.where((item) => item.kind == 'withdrawal').length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final link = session.online ? 'Online · ${session.pendingCount} to sync' : 'Offline · ${session.pendingCount} saved here';
    return Scaffold(
      appBar: AppBar(title: Text(session.farmName ?? 'Farm desk')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(session.userName ?? '', style: TextStyle(color: Desk.muted(context))),
          const SizedBox(height: 4),
          Text(link, style: const TextStyle(color: FarmColors.accent, fontWeight: FontWeight.w700)),
          if (session.message != null) ...[
            const SizedBox(height: 6),
            Text(session.message!, style: const TextStyle(color: FarmColors.warn)),
          ],
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.9,
            children: [
              _Stat(label: 'Due vaccines', value: _vaccines, tone: FarmColors.warn, onTap: () => _open(NoticesPage(session: session, kind: 'vaccine'))),
              _Stat(label: 'Medicine expiring', value: _expiring, tone: FarmColors.warn, onTap: () => _open(NoticesPage(session: session, kind: 'expiry'))),
              _Stat(label: 'Expected calving', value: _calving, tone: FarmColors.accent, onTap: () => _open(NoticesPage(session: session, kind: 'calving'))),
              _Stat(label: 'Active withdrawals', value: _held, tone: FarmColors.danger, onTap: () => _open(NoticesPage(session: session, kind: 'withdrawal'))),
            ],
          ),
          const SizedBox(height: 22),
          const Text('Quick actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _Action(icon: Icons.qr_code_scanner, title: 'Scan a cow', subtitle: 'Ear tag, RFID stick, or typed number', onTap: widget.onOpenScan),
          _Action(icon: Icons.water_drop_outlined, title: 'Milking', subtitle: 'Record liters for one cow', onTap: () => _open(MilkPage(session: session))),
          _Action(icon: Icons.favorite_outline, title: 'Mating', subtitle: 'Needs the farm network', onTap: () => _open(MatingPage(session: session))),
          _Action(icon: Icons.medical_information_outlined, title: 'Visit', subtitle: 'Symptoms, diagnosis, and follow-up', onTap: () => _open(ClinicPage(session: session))),
          _Action(icon: Icons.medication_outlined, title: 'Treatment', subtitle: 'Several medicines, saved together', onTap: () => _open(TreatmentPage(session: session))),
          _Action(icon: Icons.vaccines_outlined, title: 'Vaccination', subtitle: 'Needs the farm network. Stock is taken now', onTap: () => _open(VaccinePage(session: session))),
        ],
      ),
    );
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)).then((_) => _reload());
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.onTap, required this.tone});
  final String label;
  final int value;
  final VoidCallback onTap;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Desk.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Desk.line(context))),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: tone, height: 1)),
              const SizedBox(height: 4),
              Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Desk.muted(context), fontSize: 12, fontWeight: FontWeight.w600, height: 1.15)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.title, required this.subtitle, required this.onTap});
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
          trailing: Icon(Icons.chevron_right, color: Desk.muted(context)),
          onTap: onTap,
        ),
      ),
    );
  }
}
