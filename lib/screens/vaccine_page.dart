import 'package:flutter/material.dart';

import '../api.dart';
import '../labels.dart';
import '../session.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/cow_finder.dart';

class VaccinePage extends StatefulWidget {
  const VaccinePage({super.key, required this.session, this.cow});
  final FarmSession session;
  final CowRecord? cow;

  @override
  State<VaccinePage> createState() => _VaccinePageState();
}

class _VaccinePageState extends State<VaccinePage> {
  CowRecord? _cow;
  List<BatchRecord> _batches = [];
  String? _productId;
  String? _batchId;
  DateTime? _nextDue;
  final _quantity = TextEditingController(text: '1');
  final _notes = TextEditingController();
  String? _note;
  bool _ok = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _cow = widget.cow;
    _load();
  }

  @override
  void dispose() {
    _quantity.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<BatchRecord> get _products {
    final seen = <String>{};
    return _batches.where((batch) => seen.add(batch.productId)).toList();
  }

  List<BatchRecord> get _choices => _batches.where((batch) => batch.productId == _productId).toList();

  Future<void> _load() async {
    final batches = await widget.session.loadStock();
    if (!mounted) return;
    setState(() => _batches = batches);
    if (batches.isNotEmpty) _selectProduct(batches.first.productId);
  }

  void _selectProduct(String? productId) {
    final matches = _batches.where((batch) => batch.productId == productId).toList();
    setState(() {
      _productId = productId;
      _batchId = matches.isEmpty ? null : matches.first.id;
    });
  }

  Future<void> _pickDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDue ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _nextDue = picked);
  }

  Future<void> _save() async {
    final cow = _cow;
    final farmId = cow?.farmId ?? widget.session.farmId;
    final quantity = double.tryParse(_quantity.text.trim());
    BatchRecord? batch;
    for (final item in _choices) {
      if (item.id == _batchId) batch = item;
    }
    if (cow == null || farmId == null || batch == null || quantity == null || quantity <= 0) {
      setState(() {
        _ok = false;
        _note = 'Choose the cow, the batch, and the quantity taken from the store.';
      });
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.session.postLive('/api/farms/$farmId/vaccinations', compact({
        'animalId': cow.id,
        'medicineProductId': batch.productId,
        'medicineBatchId': batch.id,
        'quantityUsed': quantity,
        'administeredAt': DateTime.now().toUtc().toIso8601String(),
        'nextDueOn': _nextDue == null ? null : ymd(_nextDue!),
        'notes': _notes.text.trim(),
      }));
      if (!mounted) return;
      setState(() {
        _ok = true;
        _note = 'Vaccination recorded. ${batch!.productName} left the store.';
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
    BatchRecord? selected;
    for (final item in _choices) {
      if (item.id == _batchId) selected = item;
    }
    final unit = unitLabel(selected?.unit ?? '');
    return Scaffold(
      appBar: AppBar(title: Text(_cow == null ? 'Vaccination' : 'Vaccine · ${_cow!.number}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_cow == null)
            CowFinder(session: widget.session, onSelected: (cow) => setState(() => _cow = cow))
          else ...[
          ChosenCow(cow: _cow!, onChange: widget.cow == null ? () => setState(() => _cow = null) : null),
          const SizedBox(height: 8),
          Text(
            'The quantity is removed from the selected batch. A vaccine stored as one dose or one injection leaves the store as that amount. This needs the farm network.',
            style: TextStyle(color: Desk.muted(context), height: 1.35),
          ),
          const SizedBox(height: 16),
          if (_products.isEmpty)
            Text('No medicine in farm stock on this phone. Sync, or receive it under Medicine on the desk.', style: TextStyle(color: Desk.muted(context)))
          else ...[
            DropdownButtonFormField<String>(
              key: ValueKey('product-$_productId'),
              initialValue: _productId,
              decoration: const InputDecoration(labelText: 'Vaccine'),
              items: _products.map((item) => DropdownMenuItem(value: item.productId, child: Text('${item.productName} · ${pretty(item.form)} · ${unitLabel(item.unit)}'))).toList(),
              onChanged: _selectProduct,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('batch-$_productId-$_batchId'),
              initialValue: _batchId,
              decoration: const InputDecoration(labelText: 'Batch'),
              items: _choices
                  .map((item) => DropdownMenuItem(value: item.id, child: Text('${item.batchNumber} · ${item.quantity} ${unitLabel(item.unit)} on hand')))
                  .toList(),
              onChanged: (value) => setState(() => _batchId = value),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: unit.isEmpty ? 'Quantity' : 'Quantity ($unit)'),
          ),
          const SizedBox(height: 12),
          Material(
            color: Desk.card(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Desk.line(context))),
            child: ListTile(
              title: Text('Next due', style: TextStyle(color: Desk.muted(context), fontSize: 13)),
              subtitle: Text(_nextDue == null ? 'Not set' : ymd(_nextDue!), style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: _nextDue == null ? const Icon(Icons.calendar_today, size: 18) : IconButton(onPressed: () => setState(() => _nextDue = null), icon: const Icon(Icons.close)),
              onTap: _pickDue,
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: _notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Notes')),
          if (_note != null) ...[
            const SizedBox(height: 12),
            Text(_note!, style: TextStyle(color: _ok ? FarmColors.accent : FarmColors.warn, height: 1.35)),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Record vaccination')),
          ],
        ],
      ),
    );
  }
}
