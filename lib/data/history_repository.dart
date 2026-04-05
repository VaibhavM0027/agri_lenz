import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/analysis_models.dart';
import 'history_entry.dart';

class HistoryRepository {
  HistoryRepository._();

  static const _prefsKey = 'agri_lenz_history_v2';
  static const _maxItems = 28;

  static Future<Directory> _historyDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/agri_lenz_scans');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<List<HistoryEntry>> loadEntries() async {
    if (kIsWeb) return [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = HistoryEntry.decodeList(raw);
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _persist(List<HistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, HistoryEntry.encodeList(entries));
  }

  static Future<void> saveReport(CropAnalysisReport report) async {
    if (kIsWeb) return;
    final id = const Uuid().v4();
    final fileName = '$id.jpg';
    final dir = await _historyDir();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(report.previewBytes, flush: true);

    final entry = HistoryEntry.fromReport(report, id: id, imageFileName: fileName);
    var list = await loadEntries();
    list = [entry, ...list.where((e) => e.id != id)];
    if (list.length > _maxItems) {
      final removed = list.sublist(_maxItems);
      list = list.sublist(0, _maxItems);
      for (final r in removed) {
        try {
          await File('${dir.path}/${r.imageFileName}').delete();
        } catch (_) {}
      }
    }
    await _persist(list);
  }

  static Future<CropAnalysisReport?> reportForEntry(HistoryEntry entry) async {
    if (kIsWeb) return null;
    final dir = await _historyDir();
    final file = File('${dir.path}/${entry.imageFileName}');
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return entry.toReport(Uint8List.fromList(bytes));
  }

  static Future<void> deleteEntry(HistoryEntry entry) async {
    if (kIsWeb) return;
    final dir = await _historyDir();
    try {
      await File('${dir.path}/${entry.imageFileName}').delete();
    } catch (_) {}
    final list = (await loadEntries()).where((e) => e.id != entry.id).toList();
    await _persist(list);
  }

  static Future<void> clearAll() async {
    if (kIsWeb) return;
    final dir = await _historyDir();
    if (await dir.exists()) {
      await for (final e in dir.list()) {
        try {
          if (e is File) await e.delete();
        } catch (_) {}
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
