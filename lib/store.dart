import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class CowRecord {
  CowRecord({
    required this.id,
    required this.farmId,
    required this.number,
    this.name,
    this.sex,
    this.status,
    required this.tags,
  });

  final String id;
  final String farmId;
  final String number;
  final String? name;
  final String? sex;
  final String? status;
  final List<String> tags;

  String get label => (name == null || name!.isEmpty) ? number : '$number · $name';
}

class ShiftRecord {
  ShiftRecord({required this.id, required this.name});
  final String id;
  final String name;
}

class StageRecord {
  StageRecord({required this.code, required this.name, required this.meaning, required this.order});
  final String code;
  final String name;
  final String meaning;
  final int order;
}

class BatchRecord {
  BatchRecord({
    required this.id,
    required this.productId,
    required this.productName,
    required this.batchNumber,
    required this.unit,
    required this.quantity,
    this.form = '',
  });

  final String id;
  final String productId;
  final String productName;
  final String batchNumber;
  final String unit;
  final double quantity;
  final String form;
}

class WatchItem {
  WatchItem({required this.animalId, required this.kind, required this.detail});
  final String animalId;
  final String kind;
  final String detail;
}

class HerdSnapshot {
  HerdSnapshot({required this.cows, required this.females, required this.males, required this.sick, required this.withdrawals});
  final int cows;
  final int females;
  final int males;
  final int sick;
  final int withdrawals;
}

class Notice {
  Notice({
    required this.id,
    required this.kind,
    required this.title,
    required this.detail,
    this.animalId,
    this.sortKey = '',
  });

  final String id;
  final String kind;
  final String title;
  final String detail;
  final String? animalId;
  final String sortKey;
}

class OutboxItem {
  OutboxItem({required this.id, required this.kind, required this.payload, this.error});
  final String id;
  final String kind;
  final Map<String, dynamic> payload;
  final String? error;
}

class FarmStore {
  Database? _db;
  final _ids = const Uuid();

  Future<Database> get db async {
    if (_db != null) return _db!;
    final folder = await getDatabasesPath();
    _db = await openDatabase(
      p.join(folder, 'farm_desk.db'),
      version: 4,
      onCreate: (database, version) async {
        await database.execute('create table meta (key text primary key, value text)');
        await database.execute('''
          create table cows (
            id text primary key,
            farm_id text,
            number text,
            name text,
            sex text,
            status text,
            tags text
          )
        ''');
        await database.execute('create table shifts (id text primary key, farm_id text, name text)');
        await database.execute('''
          create table stages (
            code text primary key,
            name text,
            meaning text,
            display_order integer
          )
        ''');
        await database.execute('''
          create table batches (
            id text primary key,
            farm_id text,
            product_id text,
            product_name text,
            batch_number text,
            unit text,
            quantity real,
            form text
          )
        ''');
        await database.execute('''
          create table outbox (
            id text primary key,
            kind text,
            payload text,
            created_at text,
            error text
          )
        ''');
        await database.execute('''
          create table watch (
            animal_id text,
            farm_id text,
            kind text,
            detail text,
            primary key (animal_id, kind)
          )
        ''');
        await database.execute('''
          create table notices (
            farm_id text,
            kind text,
            id text,
            title text,
            detail text,
            animal_id text,
            sort_key text,
            primary key (farm_id, kind, id)
          )
        ''');
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute('''
            create table if not exists watch (
              animal_id text,
              farm_id text,
              kind text,
              detail text,
              primary key (animal_id, kind)
            )
          ''');
        }
        if (oldVersion < 3) {
          await database.execute('alter table batches add column form text');
          await database.execute('''
            create table if not exists notices (
              farm_id text,
              kind text,
              id text,
              title text,
              detail text,
              animal_id text,
              sort_key text,
              primary key (farm_id, kind, id)
            )
          ''');
        }
        if (oldVersion < 4) {
          await database.execute('''
            create table if not exists stages (
              code text primary key,
              name text,
              meaning text,
              display_order integer
            )
          ''');
        }
      },
    );
    return _db!;
  }

  Future<void> setMeta(String key, String? value) async {
    final database = await db;
    if (value == null) {
      await database.delete('meta', where: 'key = ?', whereArgs: [key]);
    } else {
      await database.insert('meta', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<String?> meta(String key) async {
    final rows = await (await db).query('meta', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> replaceCows(String farmId, List<CowRecord> cows) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete('cows', where: 'farm_id = ?', whereArgs: [farmId]);
      for (final cow in cows) {
        await txn.insert('cows', {
          'id': cow.id,
          'farm_id': farmId,
          'number': cow.number,
          'name': cow.name,
          'sex': cow.sex,
          'status': cow.status,
          'tags': jsonEncode(cow.tags),
        });
      }
    });
  }

  Future<void> replaceHerd(String farmId, List<CowRecord> cows, List<ShiftRecord> shifts, List<BatchRecord> batches) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete('cows', where: 'farm_id = ?', whereArgs: [farmId]);
      await txn.delete('shifts', where: 'farm_id = ?', whereArgs: [farmId]);
      await txn.delete('batches', where: 'farm_id = ?', whereArgs: [farmId]);
      for (final cow in cows) {
        await txn.insert('cows', {
          'id': cow.id,
          'farm_id': farmId,
          'number': cow.number,
          'name': cow.name,
          'sex': cow.sex,
          'status': cow.status,
          'tags': jsonEncode(cow.tags),
        });
      }
      for (final shift in shifts) {
        await txn.insert('shifts', {'id': shift.id, 'farm_id': farmId, 'name': shift.name});
      }
      for (final batch in batches) {
        await txn.insert('batches', {
          'id': batch.id,
          'farm_id': farmId,
          'product_id': batch.productId,
          'product_name': batch.productName,
          'batch_number': batch.batchNumber,
          'unit': batch.unit,
          'quantity': batch.quantity,
          'form': batch.form,
        });
      }
    });
  }

  Future<void> saveCow(CowRecord cow) async {
    await (await db).insert('cows', {
      'id': cow.id,
      'farm_id': cow.farmId,
      'number': cow.number,
      'name': cow.name,
      'sex': cow.sex,
      'status': cow.status,
      'tags': jsonEncode(cow.tags),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CowRecord>> cows(String farmId) async {
    final rows = await (await db).query('cows', where: 'farm_id = ?', whereArgs: [farmId], orderBy: 'number');
    return rows.map(_cow).toList();
  }

  Future<void> replaceWatch(String farmId, List<WatchItem> items) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete('watch', where: 'farm_id = ?', whereArgs: [farmId]);
      for (final item in items) {
        await txn.insert('watch', {
          'animal_id': item.animalId,
          'farm_id': farmId,
          'kind': item.kind,
          'detail': item.detail,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<WatchItem>> watch(String farmId, String kind) async {
    final rows = await (await db).query('watch', where: 'farm_id = ? and kind = ?', whereArgs: [farmId, kind]);
    return rows
        .map((row) => WatchItem(animalId: row['animal_id'] as String, kind: kind, detail: (row['detail'] as String?) ?? ''))
        .toList();
  }

  Future<void> replaceBatches(String farmId, List<BatchRecord> batches) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete('batches', where: 'farm_id = ?', whereArgs: [farmId]);
      for (final batch in batches) {
        await txn.insert('batches', {
          'id': batch.id,
          'farm_id': farmId,
          'product_id': batch.productId,
          'product_name': batch.productName,
          'batch_number': batch.batchNumber,
          'unit': batch.unit,
          'quantity': batch.quantity,
          'form': batch.form,
        });
      }
    });
  }

  Future<void> replaceNotices(String farmId, List<Notice> items) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete('notices', where: 'farm_id = ?', whereArgs: [farmId]);
      for (final item in items) {
        await txn.insert('notices', {
          'farm_id': farmId,
          'kind': item.kind,
          'id': item.id,
          'title': item.title,
          'detail': item.detail,
          'animal_id': item.animalId,
          'sort_key': item.sortKey,
        });
      }
    });
  }

  Future<void> replaceNoticeKind(String farmId, String kind, List<Notice> items) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete('notices', where: 'farm_id = ? and kind = ?', whereArgs: [farmId, kind]);
      for (final item in items) {
        await txn.insert('notices', {
          'farm_id': farmId,
          'kind': item.kind,
          'id': item.id,
          'title': item.title,
          'detail': item.detail,
          'animal_id': item.animalId,
          'sort_key': item.sortKey,
        });
      }
    });
  }

  Future<List<Notice>> notices(String farmId, [String? kind]) async {
    final rows = await (await db).query(
      'notices',
      where: kind == null ? 'farm_id = ?' : 'farm_id = ? and kind = ?',
      whereArgs: kind == null ? [farmId] : [farmId, kind],
      orderBy: 'sort_key',
    );
    return rows
        .map((row) => Notice(
              id: row['id'] as String,
              kind: row['kind'] as String,
              title: row['title'] as String,
              detail: (row['detail'] as String?) ?? '',
              animalId: row['animal_id'] as String?,
              sortKey: (row['sort_key'] as String?) ?? '',
            ))
        .toList();
  }

  Future<HerdSnapshot> snapshot(String farmId) async {
    final herd = await cows(farmId);
    final sick = await watch(farmId, 'sick');
    final held = await watch(farmId, 'withdrawal');
    return HerdSnapshot(
      cows: herd.length,
      females: herd.where((cow) => cow.sex == 'FEMALE').length,
      males: herd.where((cow) => cow.sex == 'MALE').length,
      sick: sick.length,
      withdrawals: held.length,
    );
  }

  Future<CowRecord?> findCow(String farmId, String code) async {
    final needle = code.trim().toLowerCase();
    if (needle.isEmpty) return null;
    final rows = await (await db).query('cows', where: 'farm_id = ?', whereArgs: [farmId]);
    for (final row in rows) {
      final number = (row['number'] as String).toLowerCase();
      final tags = (jsonDecode(row['tags'] as String) as List).map((item) => '$item'.toLowerCase()).toList();
      if (number == needle || tags.contains(needle)) {
        return _cow(row);
      }
    }
    return null;
  }

  Future<void> replaceStages(List<StageRecord> stages) async {
    final database = await db;
    await database.transaction((tx) async {
      await tx.delete('stages');
      for (final stage in stages) {
        await tx.insert('stages', {
          'code': stage.code,
          'name': stage.name,
          'meaning': stage.meaning,
          'display_order': stage.order,
        });
      }
    });
  }

  Future<List<StageRecord>> stages() async {
    final rows = await (await db).query('stages', orderBy: 'display_order');
    return rows
        .map((row) => StageRecord(
              code: row['code'] as String,
              name: row['name'] as String,
              meaning: row['meaning'] as String? ?? '',
              order: (row['display_order'] as num?)?.toInt() ?? 0,
            ))
        .toList();
  }

  Future<List<ShiftRecord>> shifts(String farmId) async {
    final rows = await (await db).query('shifts', where: 'farm_id = ?', whereArgs: [farmId], orderBy: 'name');
    return rows.map((row) => ShiftRecord(id: row['id'] as String, name: row['name'] as String)).toList();
  }

  Future<List<BatchRecord>> batches(String farmId) async {
    final rows = await (await db).query('batches', where: 'farm_id = ?', whereArgs: [farmId], orderBy: 'product_name');
    return rows
        .map((row) => BatchRecord(
              id: row['id'] as String,
              productId: row['product_id'] as String,
              productName: row['product_name'] as String,
              batchNumber: row['batch_number'] as String,
              unit: row['unit'] as String? ?? '',
              quantity: (row['quantity'] as num?)?.toDouble() ?? 0,
              form: row['form'] as String? ?? '',
            ))
        .toList();
  }

  Future<void> enqueue(String kind, Map<String, dynamic> payload) async {
    await (await db).insert('outbox', {
      'id': _ids.v4(),
      'kind': kind,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'error': null,
    });
  }

  Future<List<OutboxItem>> pending() async {
    final rows = await (await db).query('outbox', orderBy: 'created_at');
    return rows
        .map((row) => OutboxItem(
              id: row['id'] as String,
              kind: row['kind'] as String,
              payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
              error: row['error'] as String?,
            ))
        .toList();
  }

  Future<void> updatePayload(String id, Map<String, dynamic> payload) async {
    await (await db).update('outbox', {'payload': jsonEncode(payload)}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markError(String id, String message, Map<String, dynamic> payload) async {
    await (await db).update('outbox', {'error': message, 'payload': jsonEncode(payload)}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> remove(String id) async {
    await (await db).delete('outbox', where: 'id = ?', whereArgs: [id]);
  }

  CowRecord _cow(Map<String, Object?> row) {
    return CowRecord(
      id: row['id'] as String,
      farmId: row['farm_id'] as String,
      number: row['number'] as String,
      name: row['name'] as String?,
      sex: row['sex'] as String?,
      status: row['status'] as String?,
      tags: (jsonDecode(row['tags'] as String) as List).map((item) => '$item').toList(),
    );
  }
}
