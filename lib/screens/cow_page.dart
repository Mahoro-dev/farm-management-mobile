import 'package:flutter/material.dart';

import '../session.dart';
import '../store.dart';
import '../theme.dart';
import 'clinic_page.dart';
import 'mating_page.dart';
import 'milk_page.dart';
import 'treatment_page.dart';
import 'vaccine_page.dart';

class CowPage extends StatefulWidget {
  const CowPage({super.key, required this.session, required this.cow});
  final FarmSession session;
  final CowRecord cow;

  @override
  State<CowPage> createState() => _CowPageState();
}

class _CowPageState extends State<CowPage> {
  String? _sick;
  bool _withdrawal = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sick = await widget.session.store.watch(widget.cow.farmId, 'sick');
    final held = await widget.session.store.watch(widget.cow.farmId, 'withdrawal');
    if (!mounted) return;
    setState(() {
      for (final item in sick) {
        if (item.animalId == widget.cow.id) _sick = item.detail;
      }
      _withdrawal = held.any((item) => item.animalId == widget.cow.id);
    });
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final cow = widget.cow;
    final session = widget.session;
    return Scaffold(
      appBar: AppBar(title: Text(cow.number)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(cow.label, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
          const SizedBox(height: 6),
          Text('${_label(cow.sex)} · ${_label(cow.status)}', style: TextStyle(color: Desk.muted(context))),
          if (cow.tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(cow.tags.join(' · '), style: const TextStyle(color: FarmColors.accent)),
          ],
          if (_sick != null) ...[
            const SizedBox(height: 14),
            _Banner(text: 'Sick · $_sick', color: FarmColors.warn),
          ],
          if (_withdrawal) ...[
            const SizedBox(height: 8),
            const _Banner(text: 'Milk or meat withdrawal', color: FarmColors.danger),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (cow.sex == 'FEMALE') _Action(title: 'Milking', onTap: () => _open(MilkPage(session: session, cow: cow))),
              if (cow.sex != 'MALE') _Action(title: 'Mating', onTap: () => _open(MatingPage(session: session, cow: cow))),
              _Action(title: 'Visit', onTap: () => _open(ClinicPage(session: session, cow: cow))),
              _Action(title: 'Treatment', onTap: () => _open(TreatmentPage(session: session, cow: cow))),
              _Action(title: 'Vaccination', onTap: () => _open(VaccinePage(session: session, cow: cow))),
            ],
          ),
        ],
      ),
    );
  }

  String _label(String? value) {
    if (value == null || value.isEmpty) return '';
    return value.toLowerCase().replaceAll('_', ' ');
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Desk.card(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.title, required this.onTap});
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      onPressed: onTap,
      child: Text(title),
    );
  }
}
