import 'package:flutter/material.dart';

import '../session.dart';
import '../store.dart';
import '../theme.dart';

class CowPicker extends StatefulWidget {
  const CowPicker({super.key, required this.session, required this.onSelected, this.sex});
  final FarmSession session;
  final ValueChanged<CowRecord> onSelected;
  final String? sex;

  @override
  State<CowPicker> createState() => _CowPickerState();
}

class _CowPickerState extends State<CowPicker> {
  List<CowRecord> _cows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final farmId = widget.session.farmId;
    if (farmId == null) return;
    final cows = await widget.session.store.cows(farmId);
    if (mounted) setState(() => _cows = cows);
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<CowRecord>(
      displayStringForOption: (cow) => cow.label,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<CowRecord>.empty();
        return _cows.where((cow) {
          if (widget.sex != null && cow.sex != widget.sex) return false;
          final name = (cow.name ?? '').toLowerCase();
          return cow.number.toLowerCase().contains(query) || name.contains(query) || cow.tags.any((tag) => tag.toLowerCase().contains(query));
        });
      },
      onSelected: widget.onSelected,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Cow',
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
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 420),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final cow = items[index];
                  return ListTile(title: Text(cow.label), onTap: () => onSelected(cow));
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
