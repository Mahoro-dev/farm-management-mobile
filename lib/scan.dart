import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';
import 'package:permission_handler/permission_handler.dart';

/// Reads tag numbers from a Bluetooth RFID stick.
/// Classic sticks usually send one ASCII line per scan. BLE sticks notify a UART characteristic.
class RfidScanner extends ChangeNotifier {
  final _tags = StreamController<String>.broadcast();
  Stream<String> get tags => _tags.stream;

  final _classic = FlutterClassicBluetooth();
  dynamic _classicLink;
  StreamSubscription<dynamic>? _discovery;
  StreamSubscription<String>? _classicLines;
  StreamSubscription<List<ScanResult>>? _bleScan;
  final List<StreamSubscription<List<int>>> _bleInputs = [];
  bool _starting = false;
  String _status = 'Reader idle';

  String get status => _status;

  set status(String value) {
    _status = value;
    notifyListeners();
  }

  Future<void> listen() async {
    if (_classicLink != null) {
      status = _status;
      return;
    }
    if (_starting) return;
    _starting = true;
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    status = 'Looking for a reader';
    try {
      await _listenClassic();
      if (_classicLink == null) await _listenBle();
    } finally {
      _starting = false;
    }
  }

  Future<void> stop() async {
    await _discovery?.cancel();
    _discovery = null;
    await _classicLines?.cancel();
    _classicLines = null;
    try {
      await _classic.stopDiscovery();
      await _classicLink?.disconnect();
    } catch (_) {}
    _classicLink = null;
    await _bleScan?.cancel();
    _bleScan = null;
    for (final sub in _bleInputs) {
      await sub.cancel();
    }
    _bleInputs.clear();
    await FlutterBluePlus.stopScan();
    status = 'Reader idle';
  }

  Future<void> _listenClassic() async {
    try {
      if (!await _classic.isSupported()) return;
      await _classic.requestPermissions();
      if (!await _classic.isEnabled()) await _classic.enableBluetooth();
    } catch (_) {
      return;
    }
    final bonded = await _classic.getPairedDevices();
    for (final device in bonded) {
      if (!_looksLikeReader(device.displayName)) continue;
      if (await _openClassic(device.address, device.displayName)) return;
    }
    _discovery = _classic.discoveryResults.listen((device) async {
      if (_classicLink != null) return;
      if (!_looksLikeReader(device.displayName)) return;
      await _classic.stopDiscovery();
      await _openClassic(device.address, device.displayName);
    });
    await _classic.startDiscovery();
  }

  bool _looksLikeReader(String? name) {
    final text = (name ?? '').toLowerCase();
    const hints = ['rfid', 'reader', 'stick', 'scanner', 'barcode', 'hc-05', 'hc-06', 'uart', 'spp'];
    return hints.any(text.contains);
  }

  Future<bool> _openClassic(String address, String name) async {
    if (_classicLink != null) return true;
    try {
      final connection = await _classic.connect(address: address, timeout: const Duration(seconds: 8));
      _classicLink = connection;
      status = 'Connected to ${name.isEmpty ? address : name}';
      _classicLines = connection.input.lines().listen((line) {
        final tag = extractTag(line);
        if (tag != null) _tags.add(tag);
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _listenBle() async {
    if (await FlutterBluePlus.isSupported == false) return;
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    _bleScan = FlutterBluePlus.scanResults.listen((results) async {
      for (final result in results) {
        if (_looksLikeReader(result.device.platformName)) {
          await FlutterBluePlus.stopScan();
          await _openBle(result.device);
          return;
        }
      }
    });
  }

  Future<void> _openBle(BluetoothDevice device) async {
    await device.connect(timeout: const Duration(seconds: 8));
    status = 'Connected to ${device.platformName}';
    final services = await device.discoverServices();
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if (!characteristic.properties.notify && !characteristic.properties.indicate) continue;
        await characteristic.setNotifyValue(true);
        _bleInputs.add(characteristic.lastValueStream.listen((value) {
          final tag = extractTag(ascii.decode(value, allowInvalid: true));
          if (tag != null) _tags.add(tag);
        }));
      }
    }
  }

  static String? extractTag(String raw) {
    final match = RegExp(r'[A-Za-z0-9]{8,}').firstMatch(raw.trim());
    return match?.group(0);
  }

  /// Ear-tag numbers a person could pick out of a photo. Short visual tags and longer printed codes both count.
  static List<String> extractEarTags(String raw) {
    final found = <String>[];
    void consider(String piece) {
      final tag = piece.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (!RegExp(r'^[A-Z]{0,4}\d{3,15}[A-Z]?$').hasMatch(tag)) return;
      if (!found.contains(tag)) found.add(tag);
    }

    for (final line in raw.split(RegExp(r'[\r\n]+'))) {
      consider(line);
      for (final piece in line.split(RegExp(r'[\s,;:|/]+'))) {
        consider(piece);
      }
    }
    return found;
  }

  Future<void> close() async {
    await stop();
    await _tags.close();
    super.dispose();
  }
}
