import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mcq_question.dart';
import '../services/api_service.dart';
import '../screens/exam_result_screen.dart';

class BookmarkManager {
  static const String _key = 'bookmarked_questions';
  static const String _notedKey = 'noted_questions';
  static const String _correctKey = 'correct_questions';
  static const String _wrongKey = 'wrong_questions';

  static String _cleanKey(String text) => text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  // ══════════════════════════════════════════════════════
  // 📌 1. BOOKMARKS / SAVED MCQS (Local + Server Sync)
  // ══════════════════════════════════════════════════════

  // Sync local bookmarks with backend API database
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

      // Combine unique questions by clean Italian text
      final Map<String, McqQuestion> uniqueMap = {};
      for (var q in serverQuestions) {
        if (q.italian.trim().isNotEmpty) {
          uniqueMap[_cleanKey(q.italian)] = q;
        }
      }
      for (var q in localQuestions) {
        if (q.italian.trim().isNotEmpty) {
          uniqueMap[_cleanKey(q.italian)] = q;
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
    final targetKey = _cleanKey(question.italian);
    
    // Check if already saved (by Italian text)
    final bool exists = list.any((item) {
      try {
        final map = json.decode(item);
        return _cleanKey(map['italian']?.toString() ?? '') == targetKey;
      } catch (_) {
        return false;
      }
    });

    if (!exists) {
      list.insert(0, json.encode(question.toJson()));
      await prefs.setStringList(_key, list);
    }

    // Sync to Laravel API backend database
    try {
      await ApiService.toggleSavedMcq(question.id, type: type, italian: question.italian);
    } catch (_) {}
  }

  // Remove a question
  static Future<void> removeQuestion(String italianText, [dynamic questionId, String? type]) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_key) ?? [];
    final targetKey = _cleanKey(italianText);
    
    list.removeWhere((item) {
      try {
        final map = json.decode(item);
        return _cleanKey(map['italian']?.toString() ?? '') == targetKey;
      } catch (_) {
        return false;
      }
    });

    await prefs.setStringList(_key, list);

    // Sync to Laravel API backend database
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
    final targetKey = _cleanKey(italianText);
    
    return list.any((item) {
      try {
        final map = json.decode(item);
        return _cleanKey(map['italian']?.toString() ?? '') == targetKey;
      } catch (_) {
        return false;
      }
    });
  }

  // Get all saved questions
  static Future<List<McqQuestion>> getSavedQuestions() async {
    final synced = await syncWithServer();
    if (synced != null && synced.isNotEmpty) {
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
  // 📝 2. NOTES MANAGEMENT (Strict Isolation per Question)
  // ══════════════════════════════════════════════════════

  /// Save or update a note for a specific question (Strictly isolated by Italian text)
  static Future<void> saveNote(McqQuestion question, String noteText, {String? type}) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_notedKey) ?? [];
    final targetKey = _cleanKey(question.italian);
    
    final updatedQ = question.copyWith(userNote: noteText.trim());

    // Remove existing entry for THIS exact question only
    list.removeWhere((item) {
      try {
        final map = json.decode(item);
        return _cleanKey(map['italian']?.toString() ?? '') == targetKey;
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

  /// Remove a note for a question
  static Future<void> removeNote(String italianText, [dynamic questionId]) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_notedKey) ?? [];
    final targetKey = _cleanKey(italianText);
    
    list.removeWhere((item) {
      try {
        final map = json.decode(item);
        return _cleanKey(map['italian']?.toString() ?? '') == targetKey;
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

  /// Get the stored note for a question (Strictly matches only the exact Italian statement)
  static Future<String?> getNoteForQuestion(String italianText, [dynamic questionId]) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_notedKey) ?? [];
    final targetKey = _cleanKey(italianText);
    if (targetKey.isEmpty) return null;

    for (var item in list) {
      try {
        final map = json.decode(item);
        final itemKey = _cleanKey(map['italian']?.toString() ?? '');
        if (itemKey == targetKey) {
          final note = map['userNote']?.toString() ?? map['user_note']?.toString();
          if (note != null && note.trim().isNotEmpty) {
            return note.trim();
          }
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

        // Merge server and local
        final Map<String, McqQuestion> uniqueMap = {};
        for (var q in serverNoted) {
          if (q.italian.trim().isNotEmpty) {
            uniqueMap[_cleanKey(q.italian)] = q;
          }
        }
        for (var q in localNoted) {
          if (q.italian.trim().isNotEmpty) {
            uniqueMap[_cleanKey(q.italian)] = q;
          }
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

  // ══════════════════════════════════════════════════════
  // ✅ 3. CORRECT & WRONG MCQS MANAGEMENT (Local + Server)
  // ══════════════════════════════════════════════════════

  /// Record a single question answer result (Correct or Wrong)
  static Future<void> recordQuestionResult(McqQuestion question, bool isCorrect, {String? userAnswer}) async {
    final prefs = await SharedPreferences.getInstance();
    final targetKey = _cleanKey(question.italian);
    if (targetKey.isEmpty) return;

    final key = isCorrect ? _correctKey : _wrongKey;
    final otherKey = isCorrect ? _wrongKey : _correctKey;

    final List<String> targetList = prefs.getStringList(key) ?? [];
    final List<String> otherList = prefs.getStringList(otherKey) ?? [];

    // 1. Remove from opposing list if moving from wrong -> correct or correct -> wrong
    otherList.removeWhere((item) {
      try {
        final map = json.decode(item);
        return _cleanKey(map['italian']?.toString() ?? '') == targetKey;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(otherKey, otherList);

    // 2. Add or update in target list
    int existingIndex = targetList.indexWhere((item) {
      try {
        final map = json.decode(item);
        return _cleanKey(map['italian']?.toString() ?? '') == targetKey;
      } catch (_) {
        return false;
      }
    });

    final updatedQ = question.copyWith(
      giustoCount: isCorrect ? (question.giustoCount + 1) : question.giustoCount,
      sbagliatoCount: !isCorrect ? (question.sbagliatoCount + 1) : question.sbagliatoCount,
    );

    if (existingIndex >= 0) {
      targetList[existingIndex] = json.encode(updatedQ.toJson());
    } else {
      targetList.insert(0, json.encode(updatedQ.toJson()));
    }
    await prefs.setStringList(key, targetList);

    // 3. Log to API backend database
    try {
      final answer = userAnswer ?? (question.isVero ? (isCorrect ? 'V' : 'F') : (isCorrect ? 'F' : 'V'));
      await ApiService.logUserMcqResult(question.id, isCorrect, answer);
    } catch (_) {}
  }

  /// Record all attempted questions from an exam / test simulation
  static Future<void> recordExamResults(List<ExamResultItem> results, {int? timeSpentSeconds}) async {
    final List<Map<String, dynamic>> loggedAnswers = [];
    int correctCount = 0;
    int wrongCount = 0;
    int nonRisposteCount = 0;

    for (var item in results) {
      if (!item.isAttempted) {
        nonRisposteCount++;
        continue;
      }
      if (item.isCorrect) {
        correctCount++;
      } else {
        wrongCount++;
      }
      final mcq = McqQuestion(
        id: item.id,
        chapter: item.chapter,
        chapterName: item.chapterName,
        italian: item.italian,
        bangla: item.bangla,
        isVero: item.isVero,
        image: item.image,
        audio: item.audio,
        vocabulary: item.vocabulary,
        userNote: item.userNote,
      );
      await recordQuestionResult(
        mcq,
        item.isCorrect,
        userAnswer: item.userSelectedVero != null ? (item.userSelectedVero! ? 'V' : 'F') : null,
      );

      loggedAnswers.add({
        'question_id': item.id,
        'user_answer': item.userSelectedVero,
        'is_correct': item.isCorrect,
      });
    }

    // Submit complete exam report to /scheda-esame/submit
    if (results.isNotEmpty) {
      try {
        final authParams = await ApiService.getUserAuthParams();
        await ApiService.submitSchedaEsame({
          ...authParams,
          'total_questions': results.length,
          'correct_count': correctCount,
          'wrong_count': wrongCount,
          'non_risposte_count': nonRisposteCount,
          'duration_seconds': timeSpentSeconds ?? 600,
          'time_spent_seconds': timeSpentSeconds ?? 600,
          'answers': loggedAnswers,
        });
      } catch (_) {}
    }
  }

  /// Get all correct questions (merging local + server)
  static Future<List<McqQuestion>> getCorrectQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> localList = prefs.getStringList(_correctKey) ?? [];
    final List<McqQuestion> localCorrect = [];

    for (var item in localList) {
      try {
        final map = json.decode(item);
        if (map is Map<String, dynamic>) {
          localCorrect.add(McqQuestion.fromJson(map));
        }
      } catch (_) {}
    }

    try {
      final serverItems = await ApiService.fetchCorrectMcqs();
      if (serverItems.isNotEmpty) {
        final List<McqQuestion> serverCorrect = [];
        for (var jsonItem in serverItems) {
          final raw = (jsonItem is Map && jsonItem.containsKey('question') && jsonItem['question'] != null)
              ? jsonItem['question']
              : (jsonItem is Map && jsonItem.containsKey('cartelloQuestion') && jsonItem['cartelloQuestion'] != null
                  ? jsonItem['cartelloQuestion']
                  : (jsonItem is Map && jsonItem.containsKey('cartello_question') && jsonItem['cartello_question'] != null
                      ? jsonItem['cartello_question']
                      : jsonItem));
          if (raw is Map) {
            serverCorrect.add(McqQuestion.fromJson(Map<String, dynamic>.from(raw)));
          }
        }

        // Merge unique by Italian
        final Map<String, McqQuestion> uniqueMap = {};
        for (var q in serverCorrect) {
          if (q.italian.trim().isNotEmpty) {
            uniqueMap[_cleanKey(q.italian)] = q;
          }
        }
        for (var q in localCorrect) {
          if (q.italian.trim().isNotEmpty) {
            uniqueMap[_cleanKey(q.italian)] = q;
          }
        }

        final mergedList = uniqueMap.values.toList();
        final List<String> encodedList = mergedList.map((q) => json.encode(q.toJson())).toList();
        await prefs.setStringList(_correctKey, encodedList);
        return mergedList;
      }
    } catch (e) {
      debugPrint('Error syncing correct MCQs with server: $e');
    }

    return localCorrect;
  }

  /// Get all wrong questions (merging local + server)
  static Future<List<McqQuestion>> getWrongQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> localList = prefs.getStringList(_wrongKey) ?? [];
    final List<McqQuestion> localWrong = [];

    for (var item in localList) {
      try {
        final map = json.decode(item);
        if (map is Map<String, dynamic>) {
          localWrong.add(McqQuestion.fromJson(map));
        }
      } catch (_) {}
    }

    try {
      final serverItems = await ApiService.fetchWrongMcqs();
      if (serverItems.isNotEmpty) {
        final List<McqQuestion> serverWrong = [];
        for (var jsonItem in serverItems) {
          final raw = (jsonItem is Map && jsonItem.containsKey('question') && jsonItem['question'] != null)
              ? jsonItem['question']
              : (jsonItem is Map && jsonItem.containsKey('cartelloQuestion') && jsonItem['cartelloQuestion'] != null
                  ? jsonItem['cartelloQuestion']
                  : (jsonItem is Map && jsonItem.containsKey('cartello_question') && jsonItem['cartello_question'] != null
                      ? jsonItem['cartello_question']
                      : jsonItem));
          if (raw is Map) {
            serverWrong.add(McqQuestion.fromJson(Map<String, dynamic>.from(raw)));
          }
        }

        // Merge unique by Italian
        final Map<String, McqQuestion> uniqueMap = {};
        for (var q in serverWrong) {
          if (q.italian.trim().isNotEmpty) {
            uniqueMap[_cleanKey(q.italian)] = q;
          }
        }
        for (var q in localWrong) {
          if (q.italian.trim().isNotEmpty) {
            uniqueMap[_cleanKey(q.italian)] = q;
          }
        }

        final mergedList = uniqueMap.values.toList();
        final List<String> encodedList = mergedList.map((q) => json.encode(q.toJson())).toList();
        await prefs.setStringList(_wrongKey, encodedList);
        return mergedList;
      }
    } catch (e) {
      debugPrint('Error syncing wrong MCQs with server: $e');
    }

    return localWrong;
  }
}
