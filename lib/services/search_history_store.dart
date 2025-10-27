import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryStore {
  SearchHistoryStore({SharedPreferences? preferences})
      : _preferencesFuture = preferences != null
            ? Future.value(preferences)
            : SharedPreferences.getInstance();

  static const _historyKey = 'krishi_connect_recent_searches';
  static const _maxHistory = 10;

  final Future<SharedPreferences> _preferencesFuture;
  bool _preferencesUnavailable = false;
  final List<String> _memoryHistory = [];

  Future<SharedPreferences?> _prefsOrNull() async {
    if (_preferencesUnavailable) return null;
    try {
      return await _preferencesFuture;
    } catch (_) {
      _preferencesUnavailable = true;
      return null;
    }
  }

  Future<List<String>> loadHistory() async {
    final prefs = await _prefsOrNull();
    if (prefs == null) return List<String>.from(_memoryHistory);
    final json = prefs.getString(_historyKey);
    if (json == null || json.isEmpty) return const [];
    final decoded = jsonDecode(json);
    if (decoded is List) {
      final list = decoded.map((e) => e.toString()).toList();
      _memoryHistory
        ..clear()
        ..addAll(list);
      return list;
    }
    return const [];
  }

  Future<void> addTerm(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;

    final history = await loadHistory();
    final mutable = List<String>.from(history);
    mutable.removeWhere((existing) => existing.toLowerCase() == trimmed.toLowerCase());
    mutable.insert(0, trimmed);
    if (mutable.length > _maxHistory) {
      mutable.removeRange(_maxHistory, mutable.length);
    }
    _memoryHistory
      ..clear()
      ..addAll(mutable);

    final prefs = await _prefsOrNull();
    if (prefs != null) {
      await prefs.setString(_historyKey, jsonEncode(mutable));
    }
  }

  Future<void> removeTerm(String term) async {
    final history = await loadHistory();
    final mutable = List<String>.from(history);
    mutable.removeWhere((existing) => existing.toLowerCase() == term.toLowerCase());
    _memoryHistory
      ..clear()
      ..addAll(mutable);
    final prefs = await _prefsOrNull();
    if (prefs != null) {
      await prefs.setString(_historyKey, jsonEncode(mutable));
    }
  }

  Future<void> clear() async {
    _memoryHistory.clear();
    final prefs = await _prefsOrNull();
    if (prefs != null) {
      await prefs.remove(_historyKey);
    }
  }
}
