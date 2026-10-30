import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api.dart';
import 'labels.dart';
import 'scan.dart';
import 'store.dart';

class FarmSession extends ChangeNotifier {
  FarmSession(this.store);

  final FarmStore store;
  final scanner = RfidScanner();
  FarmApi? api;

  static const apiRoot = 'http://10.186.139.10:8080';
  String baseUrl = apiRoot;
  String? token;
  String? userName;
  String? farmId;
  String? farmName;
  List<Map<String, String>> farms = [];
  int pendingCount = 0;
  bool online = true;
  String themeMode = 'system';
  String? message;
  bool busy = false;
  Future<void>? _syncing;

  void Function(String code)? onTag;

  Future<void> restore() async {
    baseUrl = apiRoot;
    await store.setMeta('baseUrl', baseUrl);
    token = await store.meta('token');
    userName = await store.meta('userName');
    farmId = await store.meta('farmId');
    farmName = await store.meta('farmName');
    themeMode = await store.meta('theme') ?? 'system';
    await _restoreFarms();
    if (token != null) api = FarmApi(baseUrl: baseUrl, token: token);
    pendingCount = (await store.pending()).length;
    online = await _isOnline();
    Connectivity().onConnectivityChanged.listen((_) async {
      final now = await _isOnline();
      if (now != online) {
        online = now;
        notifyListeners();
        if (now) await sync();
      }
    });
    scanner.tags.listen((code) => onTag?.call(code));
    notifyListeners();
    if (token != null && farmId != null) await sync();
  }

  Future<void> setTheme(String mode) async {
    themeMode = mode;
    await store.setMeta('theme', mode);
    notifyListeners();
  }

  Future<Map<String, dynamic>> postLive(String path, Map<String, dynamic> body) async {
    if (api == null || !await _isOnline()) {
      online = false;
      notifyListeners();
      throw ApiException('This needs the farm network. Connect and try again.');
    }
    online = true;
    try {
      return await api!.post(path, body);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Cannot reach the farm server. Stay on the farm network and try again.');
    }
  }

  Future<List<BatchRecord>> loadStock() async {
    final id = farmId;
    if (id == null) return [];
    if (api != null && await _isOnline()) {
      try {
        final body = await api!.get('/api/farms/$id/medicine-batches?page=0&size=100');
        await store.replaceBatches(id, _parseBatches(body));
      } catch (_) {
        // The last sync stays on the phone until the server answers.
      }
    }
    return store.batches(id);
  }

  Future<bool> _isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result.any((item) => item != ConnectivityResult.none)) return true;
    } catch (_) {
      // The status check can fail while the farm Wi-Fi still reaches the server.
    }
    try {
      final response = await http.get(Uri.parse('$apiRoot/api/health')).timeout(const Duration(seconds: 5));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<void> login(String email, String password) async {
    busy = true;
    message = null;
    notifyListeners();
    final account = email.trim();
    try {
      if (account.isEmpty || password.isEmpty) {
        message = 'Enter the email and password.';
        return;
      }
      if (await _isOnline()) {
        try {
          await _loginOnline(account, password);
          return;
        } on ApiException catch (error) {
          message = error.message;
          return;
        } catch (_) {
          // The phone has a network, but the farm server did not answer.
        }
      }
      await _loginOffline(account, password);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _loginOnline(String email, String password) async {
    baseUrl = apiRoot;
    final client = FarmApi(baseUrl: baseUrl);
    final body = await client.post('/api/auth/login', {'email': email, 'password': password});
    token = body['token'] as String;
    userName = (body['user'] as Map)['fullName'] as String?;
    client.token = token;
    api = client;
    await store.setMeta('baseUrl', baseUrl);
    await store.setMeta('token', token);
    await store.setMeta('savedToken', token);
    await store.setMeta('userName', userName);
    await _rememberAccount(email, password);
    await _loadFarms(body['user'] as Map<String, dynamic>);
    if (farmId != null) await sync();
  }

  Future<void> _loginOffline(String email, String password) async {
    final savedEmail = await store.meta('loginEmail');
    final savedVerifier = await store.meta('loginVerifier');
    final salt = await store.meta('loginSalt');
    final savedToken = await store.meta('savedToken');
    final known = savedEmail != null && savedVerifier != null && salt != null && savedToken != null;
    if (!known || savedEmail.toLowerCase() != email.toLowerCase() || savedVerifier != _verifier(salt, email, password)) {
      message = known
          ? 'Email or password does not match the account saved on this phone.'
          : 'Sign in once on the farm network. After that, this phone can open without it.';
      online = await _isOnline();
      return;
    }
    token = savedToken;
    userName = await store.meta('userName');
    farmId = await store.meta('farmId');
    farmName = await store.meta('farmName');
    await _restoreFarms();
    api = FarmApi(baseUrl: apiRoot, token: token);
    await store.setMeta('token', token);
    online = false;
  }

  Future<void> _rememberAccount(String email, String password) async {
    var salt = await store.meta('loginSalt');
    if (salt == null || salt.isEmpty) {
      final random = Random.secure();
      salt = base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
      await store.setMeta('loginSalt', salt);
    }
    await store.setMeta('loginEmail', email.trim().toLowerCase());
    await store.setMeta('loginVerifier', _verifier(salt, email, password));
  }

  String _verifier(String salt, String email, String password) {
    final mac = Hmac(sha256, utf8.encode(salt));
    return mac.convert(utf8.encode('${email.trim().toLowerCase()}\n$password')).toString();
  }

  Future<void> _restoreFarms() async {
    final raw = await store.meta('farms');
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      farms = [
        for (final item in decoded)
          if (item is Map && item['id'] != null) {'id': '${item['id']}', 'name': '${item['name'] ?? 'Farm'}'},
      ];
    } catch (_) {}
  }

  Future<void> _loadFarms(Map<String, dynamic> user) async {
    final assignments = (user['assignments'] as List?) ?? [];
    final seen = <String, String>{};
    for (final item in assignments) {
      if (item is Map && item['endedAt'] == null && item['farmId'] != null) {
        seen[item['farmId'] as String] = (item['farmName'] as String?) ?? 'Farm';
      }
    }
    if (seen.isEmpty && api != null) {
      final listed = await api!.get('/api/farms?page=0&size=100');
      final content = listed is Map ? listed['content'] : listed;
      if (content is List) {
        for (final item in content) {
          if (item is Map && item['id'] != null && item['active'] != false) {
            seen[item['id'] as String] = (item['name'] as String?) ?? 'Farm';
          }
        }
      }
    }
    farms = seen.entries.map((entry) => {'id': entry.key, 'name': entry.value}).toList();
    if (farmId == null && farms.isNotEmpty) await selectFarm(farms.first['id']!, farms.first['name']!);
    await store.setMeta('farms', jsonEncode(farms));
  }

  Future<void> selectFarm(String id, String name) async {
    farmId = id;
    farmName = name;
    await store.setMeta('farmId', id);
    await store.setMeta('farmName', name);
    notifyListeners();
    await sync();
  }

  Future<void> logout() async {
    token = null;
    api = null;
    await store.setMeta('token', null);
    notifyListeners();
  }

  Future<CowRecord?> openCode(String code) async {
    if (farmId == null) return null;
    final local = await store.findCow(farmId!, code);
    if (local != null) return local;
    if (api == null || !await _isOnline()) return null;
    try {
      final body = await api!.get('/api/animals/lookup?code=${Uri.encodeQueryComponent(code.trim())}');
      if (body is Map<String, dynamic>) {
        final tags = <String>{
          if (body['primaryIdentifier'] is String) body['primaryIdentifier'] as String,
          code.trim(),
        }.where((tag) => tag.isNotEmpty).toList();
        final cow = CowRecord(
          id: body['id'] as String,
          farmId: (body['currentFarmId'] as String?) ?? farmId!,
          number: body['animalNumber'] as String,
          name: body['name'] as String?,
          sex: body['sex'] as String?,
          status: body['status'] as String?,
          tags: tags,
        );
        await store.saveCow(cow);
        return cow;
      }
    } on ApiException catch (error) {
      message = error.message;
      notifyListeners();
    }
    return null;
  }

  Future<void> queue(String kind, Map<String, dynamic> payload) async {
    payload['farmId'] ??= farmId;
    await store.enqueue(kind, payload);
    pendingCount = (await store.pending()).length;
    notifyListeners();
    if (await _isOnline()) await sync();
  }

  Future<void> sync() {
    final running = _syncing;
    if (running != null) return running.then((_) => sync());
    final run = _syncBody();
    _syncing = run;
    return run.whenComplete(() {
      if (identical(_syncing, run)) _syncing = null;
    });
  }

  Future<void> _syncBody() async {
    if (api == null || farmId == null) {
      message = 'Sign in again';
      notifyListeners();
      return;
    }
    try {
      await _pull();
      message = await _push();
      online = true;
    } on ApiException catch (error) {
      message = error.message;
      online = error.message != 'Sign in again';
    } catch (error) {
      debugPrint('sync failed: $error');
      online = false;
      message = 'Sync paused until the server answers';
    }
    pendingCount = (await store.pending()).length;
    notifyListeners();
  }

  Future<void> _pull() async {
    final herd = await api!.get('/api/farms/$farmId/tag-index');
    final shiftBody = await api!.get('/api/farms/$farmId/shifts');
    final batchBody = await api!.get('/api/farms/$farmId/medicine-batches?page=0&size=100');
    final cows = <CowRecord>[];
    if (herd is List) {
      for (final item in herd) {
        if (item is! Map) continue;
        final tags = <String>[];
        final rawTags = item['tags'];
        if (rawTags is List) {
          for (final tag in rawTags) {
            if (tag is Map && tag['value'] is String) tags.add(tag['value'] as String);
          }
        }
        final id = item['id'];
        final number = item['animalNumber'];
        if (id is! String || number is! String) continue;
        cows.add(CowRecord(
          id: id,
          farmId: farmId!,
          number: number,
          name: item['name'] as String?,
          sex: item['sex'] as String?,
          status: item['status'] as String?,
          tags: tags,
        ));
      }
    }
    await store.replaceCows(farmId!, cows);
    notifyListeners();
    final shifts = <ShiftRecord>[];
    if (shiftBody is List) {
      for (final item in shiftBody) {
        if (item is Map && item['active'] != false) {
          shifts.add(ShiftRecord(id: item['id'] as String, name: item['name'] as String));
        }
      }
    }
    final batches = _parseBatches(batchBody);
    await store.replaceHerd(farmId!, cows, shifts, batches);
    await _pullStages();
    await _pullWatch();
    await _pullNotices();
  }

  Future<void> _pullStages() async {
    try {
      final body = await api!.get('/api/lactation-stages');
      if (body is! List) return;
      final stages = <StageRecord>[];
      for (final item in body) {
        if (item is! Map || item['code'] is! String) continue;
        stages.add(StageRecord(
          code: item['code'] as String,
          name: (item['name'] as String?) ?? item['code'] as String,
          meaning: (item['meaning'] as String?) ?? '',
          order: (item['displayOrder'] as num?)?.toInt() ?? 0,
        ));
      }
      if (stages.isNotEmpty) await store.replaceStages(stages);
    } catch (_) {
      // Keep the stages already on the phone if the catalogue is not available yet.
    }
  }

  List<BatchRecord> _parseBatches(dynamic batchBody) {
    final batches = <BatchRecord>[];
    final content = batchBody is Map ? batchBody['content'] : null;
    if (content is! List) return batches;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    for (final item in content) {
      if (item is! Map) continue;
      final quantity = num.tryParse('${item['quantityOnHand']}')?.toDouble() ?? 0;
      final expiry = item['expiryDate'];
      if (quantity <= 0) continue;
      if (expiry is String && expiry.compareTo(today) < 0) continue;
      batches.add(BatchRecord(
        id: item['id'] as String,
        productId: item['medicineProductId'] as String,
        productName: item['medicineName'] as String,
        batchNumber: (item['batchNumber'] as String?) ?? '',
        unit: (item['baseUnit'] as String?) ?? '',
        quantity: quantity,
        form: (item['form'] as String?) ?? '',
      ));
    }
    return batches;
  }

  Future<void> _pullWatch() async {
    final items = <WatchItem>[];
    final seenSick = <String>{};
    try {
      final treatments = await api!.get('/api/farms/$farmId/treatments?page=0&size=100');
      final content = treatments is Map ? treatments['content'] : null;
      if (content is List) {
        for (final item in content) {
          if (item is! Map) continue;
          final outcome = item['outcome'];
          final animalId = item['animalId'];
          if (animalId is! String || seenSick.contains(animalId)) continue;
          if (outcome != 'IN_PROGRESS' && outcome != 'FOLLOW_UP_REQUIRED') continue;
          seenSick.add(animalId);
          final diagnosis = (item['diagnosis'] as String?)?.trim();
          items.add(WatchItem(animalId: animalId, kind: 'sick', detail: diagnosis == null || diagnosis.isEmpty ? 'In treatment' : diagnosis));
        }
      }
      final held = await api!.get('/api/reports/withdrawals?farmId=$farmId');
      if (held is List) {
        for (final item in held) {
          if (item is! Map || item['animalId'] is! String) continue;
          items.add(WatchItem(animalId: item['animalId'] as String, kind: 'withdrawal', detail: 'Milk or meat withdrawal'));
        }
      }
      await store.replaceWatch(farmId!, items);
    } on ApiException {
      // The herd is already saved. Sick and withdrawal counts stay as they were.
    }
  }

  Future<void> _pullNotices() async {
    final until = ymd(DateTime.now().add(const Duration(days: 30)));
    await _saveNoticeKind('vaccine', () async {
      final due = await api!.get('/api/farms/$farmId/vaccinations/due?until=$until');
      final items = <Notice>[];
      if (due is List) {
        for (final item in due) {
          if (item is! Map || item['id'] == null) continue;
          final next = '${item['nextDueOn'] ?? ''}';
          items.add(Notice(
            id: '${item['id']}',
            kind: 'vaccine',
            title: '${item['animalNumber'] ?? 'Cow'} · ${item['vaccineName'] ?? 'Vaccine'}',
            detail: dueLabel(next),
            animalId: item['animalId'] as String?,
            sortKey: next,
          ));
        }
      }
      return items;
    });
    await _saveNoticeKind('expiry', () async {
      final expiry = await api!.get('/api/reports/medicine-expiry?farmId=$farmId&withinDays=90');
      final items = <Notice>[];
      if (expiry is List) {
        for (final item in expiry) {
          if (item is! Map || item['batchId'] == null) continue;
          final date = '${item['expiryDate'] ?? ''}';
          items.add(Notice(
            id: '${item['batchId']}',
            kind: 'expiry',
            title: '${item['medicineName'] ?? 'Medicine'} · ${item['batchNumber'] ?? ''}',
            detail: '${dueLabel(date)} · ${item['quantityOnHand']} left',
            sortKey: date,
          ));
        }
      }
      return items;
    });
    await _saveNoticeKind('calving', () async {
      final pregnancies = await api!.get('/api/farms/$farmId/pregnancies?page=0&size=100');
      final content = pregnancies is Map ? pregnancies['content'] : null;
      final items = <Notice>[];
      if (content is List) {
        for (final item in content) {
          if (item is! Map) continue;
          final status = item['status'];
          final expected = item['expectedCalvingOn'];
          if (status != 'SUSPECTED' && status != 'CONFIRMED') continue;
          if (expected is! String || expected.compareTo(until) > 0) continue;
          items.add(Notice(
            id: '${item['id']}',
            kind: 'calving',
            title: '${item['cowNumber'] ?? 'Cow'}',
            detail: '${dueLabel(expected)} · ${pretty('$status')}',
            animalId: item['cowId'] as String?,
            sortKey: expected,
          ));
        }
      }
      return items;
    });
    await _saveNoticeKind('withdrawal', () async {
      final held = await api!.get('/api/reports/withdrawals?farmId=$farmId');
      final items = <Notice>[];
      if (held is List) {
        for (final item in held) {
          if (item is! Map || item['treatmentId'] == null) continue;
          final milk = item['milkWithdrawalUntil'];
          final meat = item['meatWithdrawalUntil'];
          final parts = <String>[
            if (milk != null) 'Milk ${dueLabel('$milk')}',
            if (meat != null) 'Meat ${dueLabel('$meat')}',
          ];
          items.add(Notice(
            id: '${item['treatmentId']}',
            kind: 'withdrawal',
            title: '${item['animalNumber'] ?? 'Cow'}',
            detail: parts.isEmpty ? 'Active withdrawal' : parts.join(' · '),
            animalId: item['animalId'] as String?,
            sortKey: '${milk ?? meat ?? ''}',
          ));
        }
      }
      return items;
    });
  }

  Future<void> _saveNoticeKind(String kind, Future<List<Notice>> Function() read) async {
    try {
      await store.replaceNoticeKind(farmId!, kind, await read());
    } catch (_) {
      // Keep the last list for this card if that report is unavailable.
    }
  }

  Future<String?> _push() async {
    String? problem;
    final items = await store.pending();
    for (final item in items) {
      try {
        if (item.kind == 'milk') {
          await api!.post('/api/farms/${item.payload['farmId']}/milk-records', {
            'animalId': item.payload['animalId'],
            'shiftId': item.payload['shiftId'],
            'milkingDate': item.payload['milkingDate'],
            'quantityLiters': item.payload['quantityLiters'],
            'lactationStage': item.payload['lactationStage'],
          });
        } else if (item.kind == 'visit') {
          await api!.post('/api/farms/${item.payload['farmId']}/veterinary-visits', compact({
            'animalId': item.payload['animalId'],
            'visitAt': item.payload['visitAt'],
            'visitType': item.payload['visitType'],
            'symptoms': item.payload['symptoms'],
            'diagnosis': item.payload['diagnosis'],
            'temperatureC': item.payload['temperatureC'],
            'weightKg': item.payload['weightKg'],
            'vetNotes': item.payload['vetNotes'],
            'followUpAt': item.payload['followUpAt'],
          }));
        } else if (item.kind == 'treatment') {
          var treatmentId = item.payload['treatmentId'] as String?;
          if (treatmentId == null) {
            final created = await api!.post('/api/farms/${item.payload['farmId']}/treatments', {
              'animalId': item.payload['animalId'],
              'treatmentDate': item.payload['treatmentDate'],
              'diagnosis': item.payload['diagnosis'],
              'outcome': 'IN_PROGRESS',
            });
            treatmentId = created['id'] as String;
            item.payload['treatmentId'] = treatmentId;
            await store.updatePayload(item.id, item.payload);
          }
          final batchId = item.payload['batchId'];
          if (batchId != null && item.payload['medicationPosted'] != true) {
            await api!.post('/api/treatments/$treatmentId/medications', {
              'medicineProductId': item.payload['medicineProductId'],
              'batchId': batchId,
              'doseAmount': item.payload['quantityUsed'],
              'doseUnit': item.payload['doseUnit'],
              'route': item.payload['route'],
              'administrationsCount': 1,
              'quantityUsed': item.payload['quantityUsed'],
            });
            item.payload['medicationPosted'] = true;
            await store.updatePayload(item.id, item.payload);
          }
        } else if (item.kind == 'vaccination') {
          await api!.post('/api/farms/${item.payload['farmId']}/vaccinations', {
            'animalId': item.payload['animalId'],
            'medicineProductId': item.payload['medicineProductId'],
            'medicineBatchId': item.payload['medicineBatchId'],
            'quantityUsed': item.payload['quantityUsed'],
            'administeredAt': item.payload['administeredAt'],
            if (item.payload['notes'] != null && '${item.payload['notes']}'.isNotEmpty) 'notes': item.payload['notes'],
          });
        }
        await store.remove(item.id);
      } on ApiException catch (error) {
        await store.markError(item.id, error.message, item.payload);
        problem ??= error.message;
      }
    }
    return problem;
  }
}
