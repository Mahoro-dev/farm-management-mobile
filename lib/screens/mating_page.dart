import 'package:flutter/material.dart';

import '../api.dart';
import '../labels.dart';
import '../session.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/cow_finder.dart';

class MatingPage extends StatefulWidget {
  const MatingPage({super.key, required this.session, this.cow});
  final FarmSession session;
  final CowRecord? cow;

  @override
  State<MatingPage> createState() => _MatingPageState();
}

class _Choice {
  _Choice(this.id, this.label);
  final String id;
  final String label;
}

class _MatingPageState extends State<MatingPage> {
  CowRecord? _cow;
  List<_Choice> _straws = [];
  List<_Choice> _people = [];
  List<CowRecord> _sires = [];
  String _method = 'ARTIFICIAL_INSEMINATION';
  String _outcome = 'PENDING';
  String? _strawId;
  String? _sireId;
  String? _technicianId;
  final _reason = TextEditingController();
  final _notes = TextEditingController();
  String? _note;
  bool _ok = false;
  bool _busy = false;
  bool _loading = true;

  bool get _artificial => _method == 'ARTIFICIAL_INSEMINATION' || _method == 'EMBRYO_TRANSFER';

  @override
  void initState() {
    super.initState();
    _cow = widget.cow;
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = widget.session;
    final farmId = session.farmId;
    if (farmId == null) return;
    final cows = await session.store.cows(farmId);
    final sires = cows.where((cow) => cow.sex == 'MALE').toList();
    if (session.api == null || !session.online) {
      if (!mounted) return;
      setState(() {
        _sires = sires;
        _loading = false;
        _note = 'Mating is saved on the server, so the phone needs the farm network.';
      });
      return;
    }
    try {
      final strawBody = await session.api!.get('/api/semen-straws?page=0&size=100');
      final peopleBody = await session.api!.get('/api/people');
      final straws = <_Choice>[];
      final content = strawBody is Map ? strawBody['content'] : null;
      if (content is List) {
        for (final item in content) {
          if (item is! Map || item['active'] == false || item['id'] == null) continue;
          straws.add(_Choice('${item['id']}', '${item['code'] ?? 'Straw'}'));
        }
      }
      final people = <_Choice>[];
      if (peopleBody is List) {
        for (final item in peopleBody) {
          if (item is! Map || item['id'] == null) continue;
          people.add(_Choice('${item['id']}', '${item['fullName'] ?? 'Person'}'));
        }
      }
      if (!mounted) return;
      setState(() {
        _sires = sires;
        _straws = straws;
        _people = people;
        _strawId = straws.isEmpty ? null : straws.first.id;
        _loading = false;
        _note = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _sires = sires;
        _loading = false;
        _note = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sires = sires;
        _loading = false;
        _note = 'Cannot reach the farm server. Stay on the farm network and try again.';
      });
    }
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
    if (cow.sex != null && cow.sex != 'FEMALE') {
      setState(() {
        _ok = false;
        _note = 'Mating is recorded on a female cow.';
      });
      return;
    }
    if (_artificial && (_strawId == null || _strawId!.isEmpty)) {
      setState(() {
        _ok = false;
        _note = 'Choose the straw. That straw is the father. Add it under Catalogue on the desk if it is missing.';
      });
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.session.postLive('/api/farms/$farmId/breeding-records', compact({
        'cowId': cow.id,
        'breedingAt': DateTime.now().toUtc().toIso8601String(),
        'breedingMethod': _method,
        'outcome': _outcome,
        'sireId': _artificial ? null : _sireId,
        'semenStrawId': _artificial ? _strawId : null,
        'technicianId': _technicianId,
        'ancestryOverrideReason': _artificial ? null : _reason.text.trim(),
        'notes': _notes.text.trim(),
      }));
      if (!mounted) return;
      setState(() {
        _ok = true;
        _note = 'Mating recorded.';
      });
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
    final cow = _cow;
    return Scaffold(
      appBar: AppBar(title: Text(cow == null ? 'Mating' : 'Mating · ${cow.number}')),
      body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (cow == null)
                  CowFinder(session: widget.session, sex: 'FEMALE', onSelected: (picked) => setState(() => _cow = picked))
                else if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: CircularProgressIndicator(color: FarmColors.accent)),
                  )
                else ...[
                ChosenCow(cow: cow, onChange: widget.cow == null ? () => setState(() => _cow = null) : null),
                const SizedBox(height: 8),
                Text(
                  'Artificial mating uses a catalogue straw as the father. Natural service uses a bull on the farm. This is saved on the server and needs the farm network.',
                  style: TextStyle(color: Desk.muted(context), height: 1.35),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _method,
                  decoration: const InputDecoration(labelText: 'Method'),
                  items: breedingMethods.map((item) => DropdownMenuItem(value: item, child: Text(pretty(item)))).toList(),
                  onChanged: (value) => setState(() => _method = value ?? 'NATURAL'),
                ),
                const SizedBox(height: 12),
                if (_artificial)
                  _straws.isEmpty
                      ? Text('No active straws. Add the straw under Catalogue on the desk.', style: TextStyle(color: Desk.muted(context)))
                      : DropdownButtonFormField<String>(
                          initialValue: _strawId,
                          decoration: const InputDecoration(labelText: 'Father (straw)'),
                          items: _straws.map((item) => DropdownMenuItem(value: item.id, child: Text(item.label))).toList(),
                          onChanged: (value) => setState(() => _strawId = value),
                        )
                else
                  DropdownButtonFormField<String?>(
                    initialValue: _sireId,
                    decoration: const InputDecoration(labelText: 'Sire'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ..._sires.map((item) => DropdownMenuItem(value: item.id, child: Text(item.label))),
                    ],
                    onChanged: (value) => setState(() => _sireId = value),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _outcome,
                  decoration: const InputDecoration(labelText: 'Outcome'),
                  items: breedingOutcomes.map((item) => DropdownMenuItem(value: item, child: Text(pretty(item)))).toList(),
                  onChanged: (value) => setState(() => _outcome = value ?? 'PENDING'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _technicianId,
                  decoration: const InputDecoration(labelText: 'Technician'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ..._people.map((item) => DropdownMenuItem(value: item.id, child: Text(item.label))),
                  ],
                  onChanged: (value) => setState(() => _technicianId = value),
                ),
                if (!_artificial) ...[
                  const SizedBox(height: 12),
                  TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Ancestry override reason')),
                ],
                const SizedBox(height: 12),
                TextField(controller: _notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Notes')),
                if (_note != null) ...[
                  const SizedBox(height: 12),
                  Text(_note!, style: TextStyle(color: _ok ? FarmColors.accent : FarmColors.warn, height: 1.35)),
                ],
                const SizedBox(height: 16),
                FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Record mating')),
                ],
              ],
            ),
    );
  }
}
