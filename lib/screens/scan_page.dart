import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../scan.dart';
import '../session.dart';
import '../store.dart';
import '../theme.dart';
import 'cow_page.dart';

class _SeenTag {
  _SeenTag(this.code, this.cow);
  final String code;
  final CowRecord? cow;
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key, required this.session});
  final FarmSession session;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _code = TextEditingController();
  final _picker = ImagePicker();
  String? _error;
  bool _reading = false;
  List<_SeenTag> _seen = [];

  @override
  void initState() {
    super.initState();
    widget.session.scanner.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.session.scanner.removeListener(_refresh);
    _code.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _submit(String code) async {
    final cow = await widget.session.openCode(code);
    if (!mounted) return;
    if (cow == null) {
      setState(() => _error = widget.session.message ?? 'No cow matches this tag. Sync the herd or check the number.');
      return;
    }
    setState(() => _error = null);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CowPage(session: widget.session, cow: cow)));
  }

  Future<void> _openSeen(_SeenTag seen) async {
    if (seen.cow != null) {
      setState(() => _error = null);
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CowPage(session: widget.session, cow: seen.cow!)));
      return;
    }
    await _submit(seen.code);
  }

  CowRecord? _match(String code, List<CowRecord> cows) {
    final needle = code.toLowerCase();
    for (final cow in cows) {
      if (cow.number.toLowerCase() == needle || cow.tags.any((tag) => tag.toLowerCase() == needle)) return cow;
    }
    if (needle.length < 4) return null;
    for (final cow in cows) {
      if (cow.number.toLowerCase().endsWith(needle) || cow.tags.any((tag) => tag.toLowerCase().endsWith(needle))) return cow;
    }
    return null;
  }

  Future<void> _readPhoto() async {
    final camera = await Permission.camera.request();
    if (!camera.isGranted) {
      setState(() => _error = 'Allow the camera to read ear tags.');
      return;
    }
    final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 92);
    if (photo == null) return;
    setState(() {
      _reading = true;
      _error = null;
      _seen = [];
    });
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(InputImage.fromFilePath(photo.path));
      final lines = recognized.blocks.expand((block) => block.lines).toList()
        ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
      final codes = RfidScanner.extractEarTags(lines.map((line) => line.text).join('\n'));
      final farmId = widget.session.farmId;
      final cows = farmId == null ? <CowRecord>[] : await widget.session.store.cows(farmId);
      if (!mounted) return;
      setState(() {
        _seen = codes.map((code) => _SeenTag(code, _match(code, cows))).toList();
        _error = codes.isEmpty ? 'No ear tag could be read. Move closer so the numbers fill the frame, then try again.' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'The photo could not be read. Try again in better light.');
    } finally {
      await recognizer.close();
      try {
        await File(photo.path).delete();
      } catch (_) {}
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Find a cow', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(session.scanner.status, style: TextStyle(color: Desk.muted(context))),
          const SizedBox(height: 18),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Ear tag or RFID'),
            onSubmitted: _submit,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: FarmColors.danger, height: 1.35)),
          ],
          const SizedBox(height: 12),
          FilledButton(onPressed: () => _submit(_code.text), child: const Text('Open cow')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: session.scanner.listen, child: const Text('Listen for the stick')),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _reading ? null : _readPhoto,
            child: Text(_reading ? 'Reading the photo…' : 'Read ear tags in a photo'),
          ),
          const SizedBox(height: 12),
          Text(
            'Photograph the cows. The phone lists every ear tag it can read, and you pick the number you know. The photo is not kept.',
            style: TextStyle(color: Desk.muted(context), height: 1.4),
          ),
          if (_seen.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Tags in this photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Desk.ink(context))),
            const SizedBox(height: 8),
            for (final seen in _seen) ...[
              Material(
                color: Desk.card(context),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Desk.line(context))),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  title: Text(seen.code, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                  subtitle: Text(seen.cow?.label ?? 'Not in the saved herd', style: TextStyle(color: Desk.muted(context))),
                  trailing: Icon(Icons.chevron_right, color: Desk.muted(context)),
                  onTap: () => _openSeen(seen),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}
