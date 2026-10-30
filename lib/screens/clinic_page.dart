import 'package:flutter/material.dart';

import '../labels.dart';
import '../session.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/cow_finder.dart';

class ClinicPage extends StatefulWidget {
  const ClinicPage({super.key, required this.session, this.cow});
  final FarmSession session;
  final CowRecord? cow;

  @override
  State<ClinicPage> createState() => _ClinicPageState();
}

class _ClinicPageState extends State<ClinicPage> {
  CowRecord? _cow;
  String _type = 'EXAMINATION';
  DateTime _visitAt = DateTime.now();
  DateTime? _followUp;
  bool _more = false;
  final _foldKey = GlobalKey();
  final _symptoms = TextEditingController();
  final _diagnosis = TextEditingController();
  final _temperature = TextEditingController();
  final _weight = TextEditingController();
  final _notes = TextEditingController();
  String? _note;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _cow = widget.cow;
  }

  @override
  void dispose() {
    for (final field in [_symptoms, _diagnosis, _temperature, _weight, _notes]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _pickWhen({required bool followUp}) async {
    final initial = followUp ? (_followUp ?? DateTime.now()) : _visitAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return;
    final chosen = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (followUp) {
        _followUp = chosen;
      } else {
        _visitAt = chosen;
      }
    });
  }

  void _toggleMore() {
    setState(() => _more = !_more);
    if (!_more) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _foldKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 250), alignment: 0.05);
    });
  }

  double? _number(TextEditingController field) {
    final text = field.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  Future<void> _save() async {
    if (_busy) return;
    final cow = _cow;
    final temperature = _number(_temperature);
    final weight = _number(_weight);
    if (cow == null) {
      setState(() => _note = 'Choose the cow.');
      return;
    }
    if (_temperature.text.trim().isNotEmpty && (temperature == null || temperature < 25 || temperature > 45)) {
      setState(() => _note = 'Temperature must be between 25 and 45 °C.');
      return;
    }
    if (_weight.text.trim().isNotEmpty && (weight == null || weight <= 0)) {
      setState(() => _note = 'Weight must be above 0 kg.');
      return;
    }
    final visitAt = _visitAt.toUtc().toIso8601String();
    final waiting = await widget.session.store.pending();
    final already = waiting.any((item) =>
        item.kind == 'visit' && item.payload['animalId'] == cow.id && item.payload['visitAt'] == visitAt && item.payload['visitType'] == _type);
    if (already) {
      setState(() => _note = 'This visit is already saved.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.session.queue('visit', compact({
        'farmId': cow.farmId,
        'animalId': cow.id,
        'visitAt': visitAt,
        'visitType': _type,
        'symptoms': _symptoms.text.trim(),
        'diagnosis': _diagnosis.text.trim(),
        'temperatureC': temperature,
        'weightKg': weight,
        'vetNotes': _notes.text.trim(),
        'followUpAt': _followUp?.toUtc().toIso8601String(),
      }));
      _symptoms.clear();
      _diagnosis.clear();
      _temperature.clear();
      _weight.clear();
      _notes.clear();
      if (!mounted) return;
      setState(() {
        _type = 'EXAMINATION';
        _visitAt = DateTime.now();
        _followUp = null;
        _more = false;
        _note = 'Visit saved on this phone. It syncs when the internet is on.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(_cow == null ? 'Visit' : 'Visit · ${_cow!.number}')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottom),
        children: [
          if (_cow == null)
            CowFinder(session: widget.session, onSelected: (cow) => setState(() => _cow = cow))
          else ...[
            ChosenCow(cow: _cow!, onChange: widget.cow == null ? () => setState(() => _cow = null) : null),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: visitTypes.map((item) => DropdownMenuItem(value: item, child: Text(pretty(item)))).toList(),
              onChanged: (value) => setState(() => _type = value ?? 'EXAMINATION'),
            ),
            const SizedBox(height: 12),
            _WhenRow(label: 'Visit at', value: whenLabel(_visitAt), onPick: () => _pickWhen(followUp: false)),
            const SizedBox(height: 12),
            TextField(controller: _symptoms, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Symptoms')),
            const SizedBox(height: 12),
            TextField(controller: _diagnosis, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Diagnosis')),
            _Fold(
              key: _foldKey,
              title: 'Temperature, weight, and follow-up',
              open: _more,
              onTap: _toggleMore,
              child: Column(
                children: [
                  TextField(
                    controller: _temperature,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Temperature °C'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _weight,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Weight kg'),
                  ),
                  const SizedBox(height: 12),
                  _WhenRow(
                    label: 'Follow up',
                    value: _followUp == null ? 'Not set' : whenLabel(_followUp!),
                    onPick: () => _pickWhen(followUp: true),
                    onClear: _followUp == null ? null : () => setState(() => _followUp = null),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Vet notes')),
                ],
              ),
            ),
            if (_note != null) ...[
              const SizedBox(height: 12),
              Text(_note!, style: const TextStyle(color: FarmColors.warn, height: 1.35)),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save visit')),
          ],
        ],
      ),
    );
  }
}

class _WhenRow extends StatelessWidget {
  const _WhenRow({required this.label, required this.value, required this.onPick, this.onClear});
  final String label;
  final String value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Desk.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Desk.line(context))),
      child: ListTile(
        title: Text(label, style: TextStyle(color: Desk.muted(context), fontSize: 13)),
        subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: onClear == null ? const Icon(Icons.calendar_today, size: 18) : IconButton(onPressed: onClear, icon: const Icon(Icons.close)),
        onTap: onPick,
      ),
    );
  }
}

class _Fold extends StatelessWidget {
  const _Fold({super.key, required this.title, required this.open, required this.onTap, required this.child});
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
