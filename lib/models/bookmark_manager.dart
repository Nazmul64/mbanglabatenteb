import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mcq_question.dart';
import '../services/api_service.dart';

class BookmarkManager {
  static const String _key = 'bookmarked_questions';
  static const String _notedKey = 'noted_questions';

  // Sync local bookmarks with backend API database (Web <-> App two-way synchronization)
  static Future<List<McqQuestion>?> syncWithServer() async {
    try {
      final serverItems = await ApiService.fetchSavedMcqs();
      final prefs = await SharedPreferences.getInstance();

      final List<McqQuestion> serverQuestions = [];
      for (var jsonItem in serverItems) {
        final raw = (jsonItem is Map && jsonItem.containsKey('question') && jsonItem['question'] != null)
            ? jsonItem['question']
            : (jsonItem is Map && jsonItem.containsKey('cartelloQuestion') && jsonItem['cartelloQuestion'] != null
                ? jsonItem['cartelloQuestion']
                : (jsonItem is Map && jsonItem.containsKey('cartello_question') && jsonItem['cartello_question'] != null
                    ? jsonItem['cartello_question']
                    : jsonItem));
        if (raw is Map) {
          final map = Map<String, dynamic>.from(raw);
          serverQuestions.add(McqQuestion.fromJson(map));
        }
      }

      // Read local saved items and merge
      final List<String> localList = prefs.getStringList(_key) ?? [];
      final List<McqQuestion> localQuestions = [];
      for (var item in localList) {
        try {
          final map = json.decode(item);
          if (map is Map<String, dynamic>) {
            localQuestions.add(McqQuestion.fromJson(map));
          }
        } catch (_) {}
      }

      // Combine unique questions by ID or Italian text
      final Map<String, McqQuestion> uniqueMap = {};
      for (var q in serverQuestions) {
        final key = q.id != 0 ? '${q.id}' : q.italian;
        uniqueMap[key] = q;
      }
      for (var q in localQuestions) {
        final key = q.id != 0 ? '${q.id}' : q.italian;
        if (!uniqueMap.containsKey(key)) {
          uniqueMap[key] = q;
        }
      }

      final mergedList = uniqueMap.values.toList();
      final List<String> encodedList = mergedList.map((q) => json.encode(q.toJson())).toList();
      await prefs.setStringList(_key, encodedList);
      return mergedList;
    } catch (e) {
      debugPrint('Error syncing bookmarks with server: $e');
      return null;
    }
  }

  // Save a question
  static Future<void> saveQuestion(McqQuestion question, {String? type}) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_key) ?? [];
    
    // Check if already saved (by Italian text or ID)
    final bool exists = list.any((item) {
      try {
        final map = json.decode(item);
        if (question.id != 0 && map['id'] == question.id) return true;
        return map['italian'] == question.italian;
      } catch (_) {
        return false;
      }
    });

    if (!exists) {
      list.add(json.encode(question.toJson()));
      await prefs.setStringList(_key, list);
    }

    // Sync to Laravel API backend database for website
    try {
      await ApiService.toggleSavedMcq(question.id, type: type, italian: question.italian);
    } catch (_) {}
  }

  // Remove a question
  static Future<void> removeQuestion(String italianText, [dynamic questionId, String? type]) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_key) ?? [];
    
    list.removeWhere((item) {
      try {
        final map = json.decode(item);
        if (questionId != null && questionId != 0 && map['id'] == questionId) return true;
        return map['italian'] == italianText;
      } catch (_) {
        return false;
      }
    });

    await prefs.setStringList(_key, list);

    // Sync to Laravel API backend database for website
    try {
      await ApiService.toggleSavedMcq(questionId ?? 0, type: type, italian: italianText);
    } catch (_) {}
  }

  // Toggle bookmark status
  static Future<bool> toggleBookmark(McqQuestion question) async {
    final saved = await isSaved(question.italian, question.id);
    if (saved) {
      await removeQuestion(question.italian, question.id);
      return false;
    } else {
      await saveQuestion(question);
      return true;
    }
  }

  // Check if a question is saved
  static Future<bool> isSaved(String italianText, [dynamic questionId]) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_key) ?? [];
    
    return list.any((item) {
      try {
        final map = json.decode(item);
        if (questionId != null && questionId != 0 && map['id'] == questionId) return true;
        return map['italian'] == italianText;
      } catch (_) {
        return false;
      }
    });
  }

  // Get all saved questions
  static Future<List<McqQuestion>> getSavedQuestions() async {
    // Attempt background sync with server first
    final synced = await syncWithServer();
    if (synced != null) {
      return synced;
    }

    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_key) ?? [];
    
    final List<McqQuestion> results = [];
    for (var item in list) {
      try {
        final map = json.decode(item);
        if (map is Map<String, dynamic>) {
          results.add(McqQuestion.fromJson(map));
        }
      } catch (_) {}
    }
    return results;
  }

  // ══════════════════════════════════════════════════════
  // 📝 NOTES MANAGEMENT (Local Persistence & Server Sync)
  // ══════════════════════════════════════════════════════

  /// Save or update a note for a question
  static Future<void> saveNote(McqQuestion question, String noteText, {String? type}) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_notedKey) ?? [];
    
    final updatedQ = question.copyWith(userNote: noteText);

    // Remove existing entry if present
    list.removeWhere((item) {
      try {
        final map = json.decode(item);
        if (question.id != 0 && map['id'] == question.id) return true;
        return map['italian'] == question.italian;
      } catch (_) {
        return false;
      }
    });

    if (noteText.trim().isNotEmpty) {
      list.insert(0, json.encode(updatedQ.toJson()));
    }
    await prefs.setStringList(_notedKey, list);

    // Sync to Server in background
    try {
      if (noteText.trim().isNotEmpty) {
        await ApiService.saveNote(
          questionId: question.id,
          note: noteText.trim(),
          type: type,
        );
      } else {
        await ApiService.deleteNote(question.id);
      }
    } catch (_) {}
  }

  /// Remove a note
  static Future<void> removeNote(String italianText, [dynamic questionId]) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_notedKey) ?? [];
    
    list.removeWhere((item) {
      try {
        final map = json.decode(item);
        if (questionId != null && questionId != 0 && map['id'] == questionId) return true;
        return map['italian'] == italianText;
      } catch (_) {
        return false;
      }
    });

    await prefs.setStringList(_notedKey, list);

    try {
      if (questionId != null && questionId != 0) {
        await ApiService.deleteNote(questionId);
      }
    } catch (_) {}
  }

  /// Get the stored note for a question
  static Future<String?> getNoteForQuestion(String italianText, [dynamic questionId]) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_notedKey) ?? [];
    for (var item in list) {
      try {
        final map = json.decode(item);
        if ((questionId != null && questionId != 0 && map['id'] == questionId) || map['italian'] == italianText) {
          return map['userNote']?.toString() ?? map['user_note']?.toString();
        }
      } catch (_) {}
    }
    return null;
  }

  /// Get all noted questions (merging local + server)
  static Future<List<McqQuestion>> getNotedQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> localList = prefs.getStringList(_notedKey) ?? [];
    final List<McqQuestion> localNoted = [];

    for (var item in localList) {
      try {
        final map = json.decode(item);
        if (map is Map<String, dynamic>) {
          localNoted.add(McqQuestion.fromJson(map));
        }
      } catch (_) {}
    }

    try {
      final serverItems = await ApiService.fetchNotedMcqs();
      if (serverItems.isNotEmpty) {
        final List<McqQuestion> serverNoted = [];
        for (var jsonItem in serverItems) {
          final raw = (jsonItem is Map && jsonItem.containsKey('question') && jsonItem['question'] != null)
              ? jsonItem['question']
              : jsonItem;
          if (raw is Map) {
            final baseQ = McqQuestion.fromJson(Map<String, dynamic>.from(raw));
            final noteStr = (jsonItem is Map && jsonItem['note_text'] != null)
                ? jsonItem['note_text'].toString()
                : ((jsonItem is Map && jsonItem['note'] != null) ? jsonItem['note'].toString() : null);
            serverNoted.add(noteStr != null ? baseQ.copyWith(userNote: noteStr) : baseQ);
          }
        }

        // Merge server and local, giving local precedence for recent edits
        final Map<String, McqQuestion> uniqueMap = {};
        for (var q in serverNoted) {
          final key = q.id != 0 ? '${q.id}' : q.italian;
          uniqueMap[key] = q;
        }
        for (var q in localNoted) {
          final key = q.id != 0 ? '${q.id}' : q.italian;
          uniqueMap[key] = q;
        }

        final mergedList = uniqueMap.values.toList();
        final List<String> encodedList = mergedList.map((q) => json.encode(q.toJson())).toList();
        await prefs.setStringList(_notedKey, encodedList);
        return mergedList;
      }
    } catch (e) {
      debugPrint('Error syncing noted MCQs with server: $e');
    }

    return localNoted;
  }
}
