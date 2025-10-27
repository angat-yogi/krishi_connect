import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryStore {
  SearchHistoryStore({SharedPreferences? preferences})
      : _preferencesFuture =
            preferences != null ? Future.value(preferences) : SharedPreferences.getInstance();

  static const _historyKey = 'krishi_connect_recent_searches';
  static const _maxHistory = 10;

  final Future<SharedPreferences> _preferencesFuture;

  Future<List<String>> loadHistory() async {
    final prefs = await _preferencesFuture;
    final json = prefs.getString(_historyKey);
    if (json == null || json.isEmpty) return const [];
    final decoded = jsonDecode(json);
    if (decoded is List) {
      return decoded.map((e) => e.toString()).toList();
    }
    return const [];
  }

  Future<void> addTerm(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;
    final prefs = await _preferencesFuture;
    final history = await loadHistory();
    history.removeWhere((existing) => existing.toLowerCase() == trimmed.toLowerCase());
    history.insert(0, trimmed);
    if (history.length > _maxHistory) {
      history.removeRange(_maxHistory, history.length);
    }
    await prefs.setString(_historyKey, jsonEncode(history));
  }

  Future<void> removeTerm(String term) async {
    final prefs = await _preferencesFuture;
    final history = await loadHistory();
    history.removeWhere((existing) => existing.toLowerCase() == term.toLowerCase());
    await prefs.setString(_historyKey, jsonEncode(history));
  }

  Future<void> clear() async {
    final prefs = await _preferencesFuture;
    await prefs.remove(_historyKey);
  }
}
