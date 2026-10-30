import 'package:flutter/material.dart';

import '../session.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/cow_finder.dart';

class MilkPage extends StatefulWidget {
  const MilkPage({super.key, required this.session, this.cow});
  final FarmSession session;
  final CowRecord? cow;

  @override
  State<MilkPage> createState() => _MilkPageState();
}

class _MilkPageState extends State<MilkPage> {
  CowRecord? _cow;
  List<ShiftRecord> _shifts = [];
  List<StageRecord> _stages = [];
  String? _shiftId;
  String? _stage;
  final _liters = TextEditingController();
  String? _note;

  @override
  void initState() {
    super.initState();
    _cow = widget.cow;
    _load();
  }

  Future<void> _load() async {
    final farmId = _cow?.farmId ?? widget.session.farmId;
    if (farmId == null) return;
    final shifts = await widget.session.store.shifts(farmId);
    final stages = await widget.session.store.stages();
    if (!mounted) return;
    setState(() {
      _shifts = shifts;
      _stages = stages;
      _shiftId = shifts.isEmpty ? null : shifts.first.id;
    });
  }

  Future<void> _save() async {
    final cow = _cow;
    final liters = double.tryParse(_liters.text.trim());
    if (cow == null || liters == null || _shiftId == null || _stage == null) {
      setState(() => _note = 'Choose the cow, the shift, the stage, and the liters.');
      return;
    }
    await widget.session.queue('milk', {
      'farmId': cow.farmId,
      'animalId': cow.id,
      'shiftId': _shiftId,
      'milkingDate': DateTime.now().toIso8601String().substring(0, 10),
      'quantityLiters': liters,
      'lactationStage': _stage,
    });
    _liters.clear();
    setState(() => _note = 'Milk saved. It syncs when the internet is on.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_cow == null ? 'Milking' : 'Milk · ${_cow!.number}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_cow == null)
            CowFinder(session: widget.session, sex: 'FEMALE', onSelected: (cow) => setState(() => _cow = cow))
          else ...[
          ChosenCow(cow: _cow!, onChange: widget.cow == null ? () => setState(() => _cow = null) : null),
          const SizedBox(height: 16),
          if (_shifts.isEmpty)
            Text('No milking shifts on this phone yet. Sync while online.', style: TextStyle(color: Desk.muted(context)))
          else
            DropdownButtonFormField<String>(
              initialValue: _shiftId,
              decoration: const InputDecoration(labelText: 'Shift'),
              items: _shifts.map((shift) => DropdownMenuItem(value: shift.id, child: Text(shift.name))).toList(),
              onChanged: (value) => setState(() => _shiftId = value),
            ),
          const SizedBox(height: 12),
          if (_stages.isEmpty)
            Text('No lactation stages on this phone yet. Sync while online.', style: TextStyle(color: Desk.muted(context)))
          else
            DropdownButtonFormField<String>(
              initialValue: _stage,
              decoration: const InputDecoration(labelText: 'Stage'),
              items: _stages.map((stage) => DropdownMenuItem(value: stage.code, child: Text(stage.name))).toList(),
              onChanged: (value) => setState(() => _stage = value),
            ),
          if (_stage != null) ...[
            const SizedBox(height: 8),
            Text(
              _stages.firstWhere((stage) => stage.code == _stage).meaning,
              style: TextStyle(color: Desk.muted(context)),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _liters,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Liters'),
          ),
          if (_note != null) ...[
            const SizedBox(height: 12),
            Text(_note!, style: const TextStyle(color: FarmColors.warn)),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save milk')),
          ],
        ],
      ),
    );
  }
}
