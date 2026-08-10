import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'mcq_question.dart';
import '../services/api_service.dart';

class BookmarkManager {
  static const String _key = 'bookmarked_questions';

  // Save a question
  static Future<void> saveQuestion(McqQuestion question) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_key) ?? [];
    
    // Check if already saved (by Italian text)
    final bool exists = list.any((item) {
      final map = json.decode(item);
      return map['italian'] == question.italian;
    });

    if (!exists) {
      final map = {
        'id': question.id,
        'chapter': question.chapter,
        'chapterName': question.chapterName,
        'italian': question.italian,
        'bangla': question.bangla,
        'isVero': question.isVero,
        'image': question.image,
        'audio': question.audio,
      };
      list.add(json.encode(map));
      await prefs.setStringList(_key, list);
    }

    // Sync to Laravel API backend database for website
    try {
      ApiService.toggleSavedMcq(question.id);
    } catch (_) {}
  }

  // Remove a question
  static Future<void> removeQuestion(String italianText, [dynamic questionId]) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_key) ?? [];
    
    list.removeWhere((item) {
      final map = json.decode(item);
      return map['italian'] == italianText;
    });

    await prefs.setStringList(_key, list);

    // Sync to Laravel API backend database for website
    if (questionId != null) {
      try {
        ApiService.toggleSavedMcq(questionId);
      } catch (_) {}
    }
  }

  // Toggle bookmark status
  static Future<bool> toggleBookmark(McqQuestion question) async {
    final saved = await isSaved(question.italian);
    if (saved) {
      await removeQuestion(question.italian);
      return false;
    } else {
      await saveQuestion(question);
      return true;
    }
  }

  // Check if a question is saved
  static Future<bool> isSaved(String italianText) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_key) ?? [];
    
    return list.any((item) {
      final map = json.decode(item);
      return map['italian'] == italianText;
    });
  }

  // Get all saved questions
  static Future<List<McqQuestion>> getSavedQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_key) ?? [];
    
    return list.map((item) {
      final map = json.decode(item);
      return McqQuestion(
        id: map['id'] ?? 0,
        chapter: map['chapter'] ?? 1,
        chapterName: map['chapterName'] ?? '',
        italian: map['italian'] ?? '',
        bangla: map['bangla'] ?? '',
        isVero: map['isVero'] ?? true,
        image: map['image'],
      );
    }).toList();
  }
}
