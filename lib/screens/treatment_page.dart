import 'package:flutter/material.dart';

import '../api.dart';
import '../labels.dart';
import '../session.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/cow_finder.dart';

class TreatmentPage extends StatefulWidget {
  const TreatmentPage({super.key, required this.session, this.cow});
  final FarmSession session;
  final CowRecord? cow;

  @override
  State<TreatmentPage> createState() => _TreatmentPageState();
}

class _Dose {
  _Dose(this.key);
  final int key;
  String? productId;
  String? batchId;
  String unit = 'ML';
  String route = 'ORAL';
  bool open = true;
  bool details = false;
  bool posted = false;
  final quantity = TextEditingController(text: '1');
  final dose = TextEditingController();
  final times = TextEditingController(text: '1');
  final frequency = TextEditingController();
  final duration = TextEditingController();
  final milkHours = TextEditingController();
  final meatHours = TextEditingController();
  final notes = TextEditingController();

  void dispose() {
    for (final field in [quantity, dose, times, frequency, duration, milkHours, meatHours, notes]) {
      field.dispose();
    }
  }
}

class _TreatmentPageState extends State<TreatmentPage> {
  CowRecord? _cow;
  List<BatchRecord> _batches = [];
  final List<_Dose> _doses = [];
  String _outcome = 'IN_PROGRESS';
  bool _more = false;
  DateTime? _milkUntil;
  DateTime? _meatUntil;
  String? _treatmentId;
  final _diagnosis = TextEditingController();
  final _plan = TextEditingController();
  String? _note;
  bool _ok = false;
  bool _busy = false;
  int _nextKey = 0;

  @override
  void initState() {
    super.initState();
    _cow = widget.cow;
    _addDose(open: true);
    _load();
  }

  @override
  void dispose() {
    _diagnosis.dispose();
    _plan.dispose();
    for (final dose in _doses) {
      dose.dispose();
    }
    super.dispose();
  }

  List<BatchRecord> get _products {
    final seen = <String>{};
    return _batches.where((batch) => seen.add(batch.productId)).toList();
  }

  List<BatchRecord> choicesFor(_Dose dose) => _batches.where((batch) => batch.productId == dose.productId).toList();

  BatchRecord? batchFor(_Dose dose) {
    for (final item in choicesFor(dose)) {
      if (item.id == dose.batchId) return item;
    }
    return null;
  }

  void _addDose({required bool open}) {
    final dose = _Dose(_nextKey++);
    dose.open = open;
    _doses.add(dose);
  }

  void _applyProduct(_Dose dose, String? productId) {
    final matches = _batches.where((batch) => batch.productId == productId).toList();
    final batch = matches.isEmpty ? null : matches.first;
    dose.productId = productId;
    dose.batchId = batch?.id;
    dose.unit = (batch == null || batch.unit.isEmpty) ? 'ML' : batch.unit;
    dose.route = defaultRoute(batch?.form);
  }

  Future<void> _load() async {
    final batches = await widget.session.loadStock();
    if (!mounted) return;
    setState(() => _batches = batches);
  }

  Future<void> _pickDate(bool milk) async {
    final current = milk ? _milkUntil : _meatUntil;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (milk) {
        _milkUntil = picked;
      } else {
        _meatUntil = picked;
      }
    });
  }

  String _summary(_Dose dose) {
    final batch = batchFor(dose);
    if (batch == null) return 'Choose a medicine';
    final quantity = dose.quantity.text.trim();
    final amount = quantity.isEmpty ? '—' : quantity;
    return '${batch.productName} · $amount ${unitLabel(dose.unit)}';
  }

  Future<void> _save() async {
    final cow = _cow;
    final farmId = cow?.farmId ?? widget.session.farmId;
    if (cow == null || farmId == null) {
      setState(() {
        _ok = false;
        _note = 'Choose the cow.';
      });
      return;
    }
    if (_doses.isEmpty) {
      setState(() {
        _ok = false;
        _note = 'Add at least one medicine.';
      });
      return;
    }
    for (final dose in _doses) {
      if (dose.posted) continue;
      final quantity = double.tryParse(dose.quantity.text.trim());
      final times = int.tryParse(dose.times.text.trim());
      final writtenDose = dose.dose.text.trim().isEmpty ? quantity : double.tryParse(dose.dose.text.trim());
      if (batchFor(dose) == null || quantity == null || quantity <= 0 || writtenDose == null || writtenDose <= 0 || times == null || times < 1) {
        setState(() {
          dose.open = true;
          _ok = false;
          _note = 'Each medicine needs a batch and the quantity taken from the store.';
        });
        return;
      }
    }
    setState(() => _busy = true);
    try {
      var treatmentId = _treatmentId;
      if (treatmentId == null) {
        final treatment = await widget.session.postLive('/api/farms/$farmId/treatments', compact({
          'animalId': cow.id,
          'treatmentDate': DateTime.now().toUtc().toIso8601String(),
          'diagnosis': _diagnosis.text.trim(),
          'treatmentPlan': _plan.text.trim(),
          'outcome': _outcome,
          'milkWithdrawalUntil': endOfLocalDay(_milkUntil),
          'meatWithdrawalUntil': endOfLocalDay(_meatUntil),
        }));
        treatmentId = '${treatment['id']}';
        _treatmentId = treatmentId;
      }
      for (final dose in _doses) {
        if (dose.posted) continue;
        final batch = batchFor(dose)!;
        final quantity = double.parse(dose.quantity.text.trim());
        final writtenDose = dose.dose.text.trim().isEmpty ? quantity : double.parse(dose.dose.text.trim());
        try {
          await widget.session.postLive('/api/treatments/$treatmentId/medications', compact({
            'medicineProductId': batch.productId,
            'batchId': batch.id,
            'doseAmount': writtenDose,
            'doseUnit': dose.unit,
            'route': dose.route,
            'administrationsCount': int.parse(dose.times.text.trim()),
            'quantityUsed': quantity,
            'frequency': dose.frequency.text.trim(),
            'durationText': dose.duration.text.trim(),
            'milkWithdrawalHours': int.tryParse(dose.milkHours.text.trim()),
            'meatWithdrawalHours': int.tryParse(dose.meatHours.text.trim()),
            'notes': dose.notes.text.trim(),
          }));
          dose.posted = true;
        } on ApiException catch (error) {
          final saved = _doses.where((item) => item.posted).length;
          if (!mounted) return;
          setState(() {
            _ok = false;
            _note = 'Saved $saved of ${_doses.length} medicines. ${error.message}';
          });
          return;
        }
      }
      if (!mounted) return;
      final names = _doses.map((dose) => batchFor(dose)?.productName).whereType<String>().toList();
      setState(() {
        _ok = true;
        _note = names.length == 1 ? 'Treatment recorded. ${names.first} left the store.' : 'Treatment recorded. ${names.length} medicines left the store.';
      });
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _ok = false;
        _note = error.message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_cow == null ? 'Treatment' : 'Treatment · ${_cow!.number}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_cow == null)
            CowFinder(session: widget.session, onSelected: (cow) => setState(() => _cow = cow))
          else ...[
          ChosenCow(cow: _cow!, onChange: widget.cow == null ? () => setState(() => _cow = null) : null),
          const SizedBox(height: 8),
          Text(
            'Add every medicine for this visit. Each one leaves the store now, so the phone needs the farm network.',
            style: TextStyle(color: Desk.muted(context), height: 1.35),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _outcome,
            decoration: const InputDecoration(labelText: 'Outcome'),
            items: treatmentOutcomes.map((item) => DropdownMenuItem(value: item, child: Text(pretty(item)))).toList(),
            onChanged: _treatmentId == null ? (value) => setState(() => _outcome = value ?? 'IN_PROGRESS') : null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _diagnosis,
            enabled: _treatmentId == null,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Diagnosis'),
          ),
          const SizedBox(height: 8),
          _Fold(
            title: 'Plan and withdrawal dates',
            open: _more,
            onTap: () => setState(() => _more = !_more),
            child: Column(
              children: [
                TextField(controller: _plan, enabled: _treatmentId == null, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Plan')),
                const SizedBox(height: 12),
                _DateRow(label: 'Milk withdrawal until', value: _milkUntil, onPick: () => _pickDate(true), onClear: () => setState(() => _milkUntil = null)),
                const SizedBox(height: 8),
                _DateRow(label: 'Meat withdrawal until', value: _meatUntil, onPick: () => _pickDate(false), onClear: () => setState(() => _meatUntil = null)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Medicines', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Desk.ink(context))),
          const SizedBox(height: 8),
          if (_products.isEmpty)
            Text('No medicine in farm stock on this phone. Sync, or receive it under Medicine on the desk.', style: TextStyle(color: Desk.muted(context)))
          else
            for (final dose in _doses) ...[
              _medicineCard(dose),
              const SizedBox(height: 8),
            ],
          if (_products.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          for (final dose in _doses) {
                            dose.open = false;
                          }
                          _addDose(open: true);
                        }),
                child: const Text('Add medicine'),
              ),
            ),
          if (_note != null) ...[
            const SizedBox(height: 12),
            Text(_note!, style: TextStyle(color: _ok ? FarmColors.accent : FarmColors.warn, height: 1.35)),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy || _products.isEmpty ? null : _save, child: Text(_busy ? 'Saving…' : 'Record treatment')),
          ],
        ],
      ),
    );
  }

  Widget _medicineCard(_Dose dose) {
    final choices = choicesFor(dose);
    final unit = unitLabel(dose.unit);
    return Material(
      color: Desk.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Desk.line(context))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => dose.open = !dose.open),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(_summary(dose), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                if (_doses.length > 1 && !dose.posted)
                  IconButton(
                    onPressed: () {
                      final removed = dose;
                      setState(() => _doses.remove(removed));
                      WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
                    },
                    icon: const Icon(Icons.close),
                  ),
                IconButton(
                  onPressed: () => setState(() => dose.open = !dose.open),
                  icon: Icon(dose.open ? Icons.expand_less : Icons.expand_more),
                ),
              ],
            ),
            if (dose.open) ...[
              if (dose.posted)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, right: 8),
                  child: Align(alignment: Alignment.centerLeft, child: Text('Saved on the server', style: TextStyle(color: FarmColors.accent, fontWeight: FontWeight.w700))),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String?>(
                        key: ValueKey('product-${dose.key}-${dose.productId}'),
                        initialValue: dose.productId,
                        decoration: const InputDecoration(labelText: 'Product'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Select')),
                          ..._products.map((item) => DropdownMenuItem(value: item.productId, child: Text('${item.productName} · ${pretty(item.form)} · ${unitLabel(item.unit)}'))),
                        ],
                        onChanged: (value) => setState(() => _applyProduct(dose, value)),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        key: ValueKey('batch-${dose.key}-${dose.productId}-${dose.batchId}'),
                        initialValue: dose.batchId,
                        decoration: const InputDecoration(labelText: 'Batch'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Select')),
                          ...choices.map((item) => DropdownMenuItem(value: item.id, child: Text('${item.batchNumber} · ${item.quantity} ${unitLabel(item.unit)} on hand'))),
                        ],
                        onChanged: (value) => setState(() {
                          dose.batchId = value;
                          for (final item in choices) {
                            if (item.id != value) continue;
                            if (item.unit.isNotEmpty) dose.unit = item.unit;
                            dose.route = defaultRoute(item.form);
                          }
                        }),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: dose.quantity,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: unit.isEmpty ? 'Quantity used' : 'Quantity used ($unit)'),
                        onChanged: (_) => setState(() {}),
                      ),
                      _Fold(
                        title: 'Dose, route, and withdrawal',
                        open: dose.details,
                        onTap: () => setState(() => dose.details = !dose.details),
                        child: Column(
                          children: [
                            TextField(
                              controller: dose.dose,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(labelText: unit.isEmpty ? 'Dose amount' : 'Dose amount ($unit)', hintText: 'Same as quantity if left empty'),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: ValueKey('unit-${dose.key}-${dose.unit}'),
                              initialValue: medicineUnits.contains(dose.unit) ? dose.unit : 'ML',
                              decoration: const InputDecoration(labelText: 'Dose unit'),
                              items: medicineUnits.map((item) => DropdownMenuItem(value: item, child: Text(unitLabel(item)))).toList(),
                              onChanged: (value) => setState(() => dose.unit = value ?? 'ML'),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: ValueKey('route-${dose.key}-${dose.route}'),
                              initialValue: adminRoutes.contains(dose.route) ? dose.route : 'ORAL',
                              decoration: const InputDecoration(labelText: 'Route'),
                              items: adminRoutes.map((item) => DropdownMenuItem(value: item, child: Text(pretty(item)))).toList(),
                              onChanged: (value) => setState(() => dose.route = value ?? 'ORAL'),
                            ),
                            const SizedBox(height: 12),
                            TextField(controller: dose.times, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Times given')),
                            const SizedBox(height: 12),
                            TextField(controller: dose.frequency, decoration: const InputDecoration(labelText: 'Frequency')),
                            const SizedBox(height: 12),
                            TextField(controller: dose.duration, decoration: const InputDecoration(labelText: 'Duration')),
                            const SizedBox(height: 12),
                            TextField(controller: dose.milkHours, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Milk withdrawal hours')),
                            const SizedBox(height: 12),
                            TextField(controller: dose.meatHours, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Meat withdrawal hours')),
                            const SizedBox(height: 12),
                            TextField(controller: dose.notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Notes')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Fold extends StatelessWidget {
  const _Fold({required this.title, required this.open, required this.onTap, required this.child});
  final String title;
  final bool open;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onTap,
            icon: Icon(open ? Icons.expand_less : Icons.expand_more, size: 18),
            label: Text(title),
          ),
        ),
        if (open) child,
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.label, required this.value, required this.onPick, required this.onClear});
  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? 'Not set' : ymd(value!);
    return Material(
      color: Desk.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Desk.line(context))),
      child: ListTile(
        title: Text(label, style: TextStyle(color: Desk.muted(context), fontSize: 13)),
        subtitle: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: value == null ? const Icon(Icons.calendar_today, size: 18) : IconButton(onPressed: onClear, icon: const Icon(Icons.close)),
        onTap: onPick,
      ),
    );
  }
}
