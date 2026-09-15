import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/slider_model.dart';

class ApiService {
  static const List<String> candidateBaseUrls = [
    'http://127.0.0.1:8000/api/v1',
    'http://localhost:8000/api/v1',
    'http://192.168.0.101:8000/api/v1',
    'http://192.168.0.102:8000/api/v1',
    'http://192.168.42.184:8000/api/v1',
    'http://10.0.2.2:8000/api/v1',
  ];

  static String? _resolvedBaseUrl;
  static String? _activeSessionId;
  static String? _activeClientPhone;

  static void setSessionContext({String? sessionId, String? phone}) {
    if (sessionId != null && sessionId.isNotEmpty) _activeSessionId = sessionId;
    if (phone != null && phone.isNotEmpty) _activeClientPhone = phone;
  }

  /// Flushes in-memory response caches and resets active server resolution
  static void clearAllCache() {
    _apiResponseCache.clear();
    _cachedLiveExamPool = null;
    _resolvedBaseUrl = null;
    debugPrint('🧹 ApiService: All in-memory API caches cleared.');
  }

  /// Initialize server configuration by probing live URLs and fetching active settings
  static Future<void> initServerConfig() async {
    clearAllCache();
    for (final base in candidateBaseUrls) {
      try {
        final uri = Uri.parse('$base/settings');
        final response = await http.get(uri, headers: defaultHeaders).timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) {
          _resolvedBaseUrl = base;
          final decoded = json.decode(response.body);
          if (decoded is Map<String, dynamic>) {
            _checkAndApplyServerMode(decoded, currentCandidate: base);
          }
          break;
        }
      } catch (_) {}
    }
  }

  /// Inspect setting response payload to set server mode & active base URL dynamically
  static void _checkAndApplyServerMode(Map<String, dynamic> data, {String? currentCandidate}) {
    if (currentCandidate != null) {
      _resolvedBaseUrl = currentCandidate;
      debugPrint('📢 Active Server Base URL: $_resolvedBaseUrl');
      return;
    }
  }

  /// Get the active base URL
  static String get baseUrl => _resolvedBaseUrl ?? candidateBaseUrls.first;

  /// Standard HTTP Headers as specified in API Documentation
  static Map<String, String> get defaultHeaders {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    if (_activeSessionId != null && _activeSessionId!.isNotEmpty) {
      headers['X-Session-ID'] = _activeSessionId!;
    }
    if (_activeClientPhone != null && _activeClientPhone!.isNotEmpty) {
      headers['X-Client-Phone'] = _activeClientPhone!;
    }
    return headers;
  }

  /// Helper to convert relative image path (/uploads/...) to full absolute HTTP URL
  static String formatImageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    if (path.trim().toLowerCase() == 'null' || path.trim().toLowerCase() == 'undefined') return '';
    if (path.startsWith('file://')) return '';

    final serverOrigin = baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
    var cleanPath = path.trim();

    // Dynamically replace any localhost or local dev IP in stored URLs with the current active reachable server origin
    cleanPath = cleanPath.replaceAll(
      RegExp(r'https?://(?:127\.0\.0\.1|localhost|192\.168\.\d+\.\d+|10\.0\.2\.2):8000'),
      serverOrigin,
    );

    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) return cleanPath;
    final normalized = cleanPath.startsWith('/') ? cleanPath : '/$cleanPath';
    return '$serverOrigin$normalized';
  }

  static final Map<String, http.Response> _apiResponseCache = {};

  /// Helper to perform HTTP GET with dynamic candidate URL resolution & fallback
  static Future<http.Response?> _getWithFallback(String endpoint, {Map<String, String>? queryParameters, bool useCache = false}) async {
    final cacheKey = '$endpoint?${queryParameters?.entries.map((e) => '${e.key}=${e.value}').join('&') ?? ''}';
    if (useCache && _apiResponseCache.containsKey(cacheKey)) {
      return _apiResponseCache[cacheKey];
    }

    if (_resolvedBaseUrl != null) {
      try {
        final uri = Uri.parse('$_resolvedBaseUrl$endpoint').replace(queryParameters: queryParameters);
        final response = await http.get(uri, headers: defaultHeaders).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          if (useCache) _apiResponseCache[cacheKey] = response;
          return response;
        }
      } catch (_) {
        _resolvedBaseUrl = null;
      }
    }

    for (final base in candidateBaseUrls) {
      try {
        final uri = Uri.parse('$base$endpoint').replace(queryParameters: queryParameters);
        final response = await http.get(uri, headers: defaultHeaders).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          _resolvedBaseUrl = base;
          if (useCache) _apiResponseCache[cacheKey] = response;
          debugPrint('Active API Base URL resolved: $base');
          return response;
        }
      } catch (e) {
        debugPrint('Candidate URL $base failed for GET $endpoint');
      }
    }
    return null;
  }

  /// Helper to perform HTTP POST with dynamic candidate URL resolution & fallback
  static Future<http.Response?> _postWithFallback(String endpoint, Map<String, dynamic> body) async {
    if (_resolvedBaseUrl != null) {
      try {
        final uri = Uri.parse('$_resolvedBaseUrl$endpoint');
        final response = await http
            .post(uri, headers: defaultHeaders, body: json.encode(body))
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200 || response.statusCode == 201) return response;
      } catch (_) {
        _resolvedBaseUrl = null;
      }
    }

    for (final base in candidateBaseUrls) {
      try {
        final uri = Uri.parse('$base$endpoint');
        final response = await http
            .post(uri, headers: defaultHeaders, body: json.encode(body))
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200 || response.statusCode == 201) {
          _resolvedBaseUrl = base;
          debugPrint('Active API Base URL resolved: $base');
          return response;
        }
      } catch (e) {
        debugPrint('Candidate URL $base failed for POST $endpoint');
      }
    }
    return null;
  }

  /// Helper to perform HTTP DELETE with dynamic candidate URL resolution & fallback
  static Future<http.Response?> _deleteWithFallback(String endpoint) async {
    if (_resolvedBaseUrl != null) {
      try {
        final uri = Uri.parse('$_resolvedBaseUrl$endpoint');
        final response = await http.delete(uri, headers: defaultHeaders).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200 || response.statusCode == 204) return response;
      } catch (_) {
        _resolvedBaseUrl = null;
      }
    }

    for (final base in candidateBaseUrls) {
      try {
        final uri = Uri.parse('$base$endpoint');
        final response = await http.delete(uri, headers: defaultHeaders).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200 || response.statusCode == 204) {
          _resolvedBaseUrl = base;
          debugPrint('Active API Base URL resolved: $base');
          return response;
        }
      } catch (e) {
        debugPrint('Candidate URL $base failed for DELETE $endpoint');
      }
    }
    return null;
  }

  /// Extract list data from standard JSON response
  static List<dynamic> _extractList(http.Response? response) {
    if (response != null && (response.statusCode == 200 || response.statusCode == 201)) {
      try {
        final decoded = json.decode(response.body);
        if (decoded is List) return decoded;
        if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is List) return decoded['data'] as List<dynamic>;
          if (decoded['results'] is List) return decoded['results'] as List<dynamic>;
          if (decoded['words'] is List) return decoded['words'] as List<dynamic>;
          if (decoded['items'] is List) return decoded['items'] as List<dynamic>;
          if (decoded['data'] is Map<String, dynamic>) {
            final subMap = decoded['data'] as Map<String, dynamic>;
            if (subMap['results'] is List) return subMap['results'] as List<dynamic>;
            if (subMap['data'] is List) return subMap['data'] as List<dynamic>;
            if (subMap['words'] is List) return subMap['words'] as List<dynamic>;
          }
        }
      } catch (e) {
        debugPrint('Error parsing JSON list response: $e');
      }
    }
    return [];
  }

  /// Extract map data from standard JSON response
  static Map<String, dynamic>? _extractMap(http.Response? response) {
    if (response != null && (response.statusCode == 200 || response.statusCode == 201)) {
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is Map<String, dynamic>) {
            return decoded['data'] as Map<String, dynamic>;
          }
          return decoded;
        } else if (decoded is List) {
          return {'results': decoded};
        }
      } catch (e) {
        debugPrint('Error parsing JSON map response: $e');
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────
  // 📌 1. Sliders & Banners API
  // ─────────────────────────────────────────────────────
  /// GET /api/dashboard/banners or /api/v1/sliders
  static Future<List<SliderModel>> fetchSliders() async {
    try {
      final response = await _getWithFallback('/dashboard/banners') ??
                       await _getWithFallback('/sliders') ??
                       await _getWithFallback('/banners');
      final list = _extractList(response);
      return list.map((e) => SliderModel.fromJson(e)).where((s) => s.status && s.imageUrl.isNotEmpty).toList();
    } catch (e) {
      debugPrint('Error fetching sliders: $e');
      return [];
    }
  }

  static Future<List<String>> fetchDashboardBanners() async {
    final sliders = await fetchSliders();
    if (sliders.isNotEmpty) {
      return sliders.map((s) => s.imageUrl).where((url) => url.isNotEmpty).toList();
    }
    return [];
  }

  // ─────────────────────────────────────────────────────
  // 📌 2. Test & Practice Quiz API
  // ─────────────────────────────────────────────────────
  /// GET /api/v1/test/questions
  static Future<List<dynamic>> fetchTestQuestions({int limit = 30, int? chapterId}) async {
    try {
      final queryParams = <String, String>{'limit': limit.toString()};
      if (chapterId != null) {
        queryParams['chapter_id'] = chapterId.toString();
      }
      final response = await _getWithFallback('/test/questions', queryParameters: queryParams);
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching test questions: $e');
      return [];
    }
  }

  /// POST /api/v1/test/submit
  static Future<bool> submitTestResult(Map<String, dynamic> payload) async {
    try {
      final response = await _postWithFallback('/test/submit', payload);
      return response != null && (response.statusCode == 200 || response.statusCode == 201);
    } catch (e) {
      debugPrint('Error submitting test result: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────
  // 📌 3. Argomenti API (Theory Chapters & Pages)
  // ─────────────────────────────────────────────────────
  /// GET /api/v1/chapters
  static Future<List<dynamic>> fetchChapters() async {
    try {
      final response = await _getWithFallback('/chapters');
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching chapters: $e');
      return [];
    }
  }

  /// GET /api/v1/chapters/{id}/pages
  static Future<List<dynamic>> fetchChapterPages(int chapterId) async {
    try {
      final response = await _getWithFallback('/chapters/$chapterId/pages');
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching chapter pages: $e');
      return [];
    }
  }

  /// GET /api/v1/pages/all
  static Future<List<dynamic>> fetchAllPages() async {
    try {
      final response = await _getWithFallback('/pages/all');
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching all pages: $e');
      return [];
    }
  }

  /// GET /api/v1/pages/{id}
  static Future<Map<String, dynamic>?> fetchPageDetails(int pageId) async {
    try {
      final response = await _getWithFallback('/pages/$pageId');
      return _extractMap(response);
    } catch (e) {
      debugPrint('Error fetching page details: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────
  // 📌 4. E-Class & Lezioni Video API
  // ─────────────────────────────────────────────────────
  /// GET /api/v1/eclass
  static Future<List<dynamic>> fetchEClasses() async {
    try {
      final response = await _getWithFallback('/eclass');
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching eclasses: $e');
      return [];
    }
  }

  /// GET /api/v1/lezioni
  static Future<List<dynamic>> fetchLezioni() async {
    try {
      final response = await _getWithFallback('/lezioni');
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching lezioni: $e');
      return [];
    }
  }

  /// GET /api/v1/lezioni/{id}
  static Future<Map<String, dynamic>?> fetchLezioneDetails(int lezioneId) async {
    try {
      final response = await _getWithFallback('/lezioni/$lezioneId');
      return _extractMap(response);
    } catch (e) {
      debugPrint('Error fetching lezione details: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────
  // 📌 5. Cartelli API (Traffic Signs Catalog)
  // ─────────────────────────────────────────────────────
  /// GET /api/v1/cartelli/categories
  static Future<List<dynamic>> fetchCartelliCategories() async {
    try {
      final response = await _getWithFallback('/cartelli/categories');
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching cartelli categories: $e');
      return [];
    }
  }

  /// GET /api/v1/cartelli/chapters/{categoryId?}
  static Future<List<dynamic>> fetchCartelliChapters([int? categoryId]) async {
    try {
      final endpoint = categoryId != null ? '/cartelli/chapters/$categoryId' : '/cartelli/chapters';
      final response = await _getWithFallback(endpoint);
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching cartelli chapters: $e');
      return [];
    }
  }

  /// GET /api/v1/cartelli/pages/{chapterId}
  static Future<List<dynamic>> fetchCartelliPages(int chapterId) async {
    try {
      final response = await _getWithFallback('/cartelli/pages/$chapterId');
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching cartelli pages: $e');
      return [];
    }
  }

  /// GET /api/v1/cartelli/page-mcqs/{pageId}
  static Future<List<dynamic>> fetchCartelliPageMcqs(int pageId) async {
    try {
      final response = await _getWithFallback('/cartelli/page-mcqs/$pageId');
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching cartelli page MCQs: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────
  // 📌 6. Dizionario & Word API
  // ─────────────────────────────────────────────────────
  /// GET /api/v1/dictionary/search?q={query}&letter={letter}
  static Future<Map<String, dynamic>?> searchDictionary({String query = '', String letter = ''}) async {
    try {
      final queryParams = <String, String>{};
      if (query.trim().isNotEmpty) {
        queryParams['q'] = query.trim();
        queryParams['query'] = query.trim();
        queryParams['search'] = query.trim();
      }
      if (letter.trim().isNotEmpty) {
        queryParams['letter'] = letter.trim();
      }

      // 1. Try dedicated dictionary search endpoint
      final response = await _getWithFallback('/dictionary/search', queryParameters: queryParams.isNotEmpty ? queryParams : null) ??
          await _getWithFallback('/dictionary', queryParameters: queryParams.isNotEmpty ? queryParams : null) ??
          await _getWithFallback('/words', queryParameters: queryParams.isNotEmpty ? queryParams : null) ??
          await _getWithFallback('/dizionario', queryParameters: queryParams.isNotEmpty ? queryParams : null);

      if (response != null) {
        final map = _extractMap(response);
        if (map != null) {
          if (map['results'] is List) return map;
          if (map['data'] is List) return {'results': map['data']};
          if (map['words'] is List) return {'results': map['words']};
          return map;
        }
        final list = _extractList(response);
        if (list.isNotEmpty) {
          return {'results': list};
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error searching dictionary: $e');
      return null;
    }
  }

  /// GET /api/v1/words (or /dizionario)
  static Future<List<dynamic>> fetchWords({String query = '', String search = ''}) async {
    try {
      final searchTerm = query.isNotEmpty ? query : search;
      final queryParams = searchTerm.isNotEmpty ? {'query': searchTerm, 'search': searchTerm, 'q': searchTerm} : null;
      final response = await _getWithFallback('/words', queryParameters: queryParams) ??
          await _getWithFallback('/dizionario', queryParameters: queryParams) ??
          await _getWithFallback('/dictionary', queryParameters: queryParams);
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching words: $e');
      return [];
    }
  }

  /// GET /api/v1/dizionario (alias for backward compatibility)
  static Future<List<dynamic>> fetchDictionary({String query = '', String search = ''}) => fetchWords(query: query, search: search);

  static List<dynamic>? _cachedLiveExamPool;

  /// GET /api/v1/scheda-esame/generate with live Argomenti & Cartelli MCQ aggregation
  static Future<List<dynamic>> generateSchedaEsame({bool forceRefresh = false}) async {
    try {
      // 1. If we have a cached live pool and not forcing refresh, pick 30 random questions instantly
      if (!forceRefresh && _cachedLiveExamPool != null && _cachedLiveExamPool!.isNotEmpty) {
        final shuffled = List<dynamic>.from(_cachedLiveExamPool!)..shuffle();
        return shuffled.take(30).toList();
      }

      // 2. Try official endpoint first
      final officialRes = await _getWithFallback('/scheda-esame/generate');
      final officialList = _extractList(officialRes);
      if (officialList.isNotEmpty) {
        _cachedLiveExamPool = officialList;
        return officialList;
      }

      // 3. Parallel fetch all live MCQs from Argomenti and Cartelli
      final List<dynamic> pool = [];

      final results = await Future.wait([
        fetchChapters(),
        fetchCartelliChapters(),
      ]);

      final chapters = results[0];
      final cartelliChapters = results[1];

      final List<Future<void>> fetchTasks = [];

      // Process Argomenti chapters
      for (var ch in chapters) {
        final cId = ch['id'] is int ? ch['id'] as int : int.tryParse('${ch['id']}') ?? 1;
        final cName = (ch['name'] ?? ch['bn_name'] ?? 'Capitolo $cId').toString();

        fetchTasks.add(() async {
          final pages = await fetchChapterPages(cId);
          for (var p in pages) {
            final pId = p['id'] is int ? p['id'] as int : int.tryParse('${p['id']}') ?? 1;
            final pageDetails = await fetchPageDetails(pId);
            if (pageDetails != null && pageDetails['questions'] is List) {
              for (var q in pageDetails['questions']) {
                if (q is Map) {
                  final map = Map<String, dynamic>.from(q);
                  map['chapter_name'] = map['chapter_name'] ?? cName;
                  map['chapter_id'] = map['chapter_id'] ?? cId;
                  if ((map['image'] == null || map['image'].toString().isEmpty) && pageDetails['image'] != null) {
                    map['image'] = pageDetails['image'];
                  }
                  pool.add(map);
                }
              }
            }
          }
        }());
      }

      // Process Cartelli chapters
      for (var cch in cartelliChapters) {
        final cId = cch['id'] is int ? cch['id'] as int : int.tryParse('${cch['id']}') ?? 1;
        final cName = (cch['name'] ?? cch['bn_name'] ?? 'Cartello $cId').toString();

        fetchTasks.add(() async {
          final cPages = await fetchCartelliPages(cId);
          for (var cp in cPages) {
            final cpId = cp['id'] is int ? cp['id'] as int : int.tryParse('${cp['id']}') ?? 1;
            final mcqs = await fetchCartelliPageMcqs(cpId);
            for (var mq in mcqs) {
              if (mq is Map) {
                final map = Map<String, dynamic>.from(mq);
                map['chapter_name'] = map['chapter_name'] ?? cName;
                map['chapter_id'] = map['chapter_id'] ?? cId;
                if ((map['image'] == null || map['image'].toString().isEmpty) && cp['image'] != null) {
                  map['image'] = cp['image'];
                }
                pool.add(map);
              }
            }
          }
        }());
      }

      await Future.wait(fetchTasks);

      if (pool.isNotEmpty) {
        _cachedLiveExamPool = pool;
        final shuffled = List<dynamic>.from(pool)..shuffle();
        return shuffled.take(30).toList();
      }

      return [];
    } catch (e) {
      debugPrint('Error generating scheda esame: $e');
      return [];
    }
  }

  /// POST /api/v1/scheda-esame/submit
  static Future<Map<String, dynamic>?> submitSchedaEsame(Map<String, dynamic> payload) async {
    try {
      final response = await _postWithFallback('/scheda-esame/submit', payload);
      return _extractMap(response);
    } catch (e) {
      debugPrint('Error submitting scheda esame: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────
  // 📌 8. Sfida Speed Challenge API
  // ─────────────────────────────────────────────────────
  /// GET /api/v1/sfida/questions
  static Future<List<dynamic>> fetchSfidaQuestions() async {
    try {
      final response = await _getWithFallback('/sfida/questions');
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching sfida questions: $e');
      return [];
    }
  }

  static Future<Map<String, String>> _getUserAuthParams() async {
    final params = <String, String>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final firstName = prefs.getString('app_client_first_name') ??
          prefs.getString('first_name') ??
          prefs.getString('user_name') ??
          prefs.getString('name');
      final lastName = prefs.getString('app_client_last_name') ??
          prefs.getString('last_name');
      final phone = prefs.getString('app_client_phone') ??
          prefs.getString('user_phone') ??
          prefs.getString('phone');
      var sessionId = prefs.getString('app_client_session_id') ??
          prefs.getString('app_session_id') ??
          prefs.getString('session_id') ??
          prefs.getString('device_id');
      if (sessionId == null || sessionId.trim().isEmpty) {
        sessionId = 'app_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('app_client_session_id', sessionId);
      }
      final userId = prefs.getInt('user_id');

      if (firstName != null && firstName.trim().isNotEmpty) {
        params['first_name'] = firstName.trim();
        params['name'] = firstName.trim();
      }
      if (lastName != null && lastName.trim().isNotEmpty) {
        params['last_name'] = lastName.trim();
      }
      if (phone != null && phone.trim().isNotEmpty) {
        params['phone'] = phone.trim();
        params['user_phone'] = phone.trim();
      }
      if (sessionId.trim().isNotEmpty) {
        params['session_id'] = sessionId.trim();
      }
      if (userId != null && userId > 0) {
        params['user_id'] = '$userId';
      }
    } catch (_) {}
    return params;
  }

  // ─────────────────────────────────────────────────────
  // 📌 9. Saved MCQs & Notes API
  // ─────────────────────────────────────────────────────
  /// GET /api/v1/saved-mcqs
  static Future<List<dynamic>> fetchSavedMcqs() async {
    try {
      final params = await _getUserAuthParams();
      final response = await _getWithFallback('/saved-mcqs', queryParameters: params.isNotEmpty ? params : null);
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching saved mcqs: $e');
      return [];
    }
  }

  /// POST /api/v1/saved-mcqs/toggle
  static Future<Map<String, dynamic>?> toggleSavedMcq(dynamic questionId, {String? type, String? italian}) async {
    try {
      final authParams = await _getUserAuthParams();
      final body = <String, dynamic>{
        'question_id': questionId,
        if (italian != null && italian.isNotEmpty) 'italian': italian,
        if (type != null && type.isNotEmpty) 'type': type,
        ...authParams,
      };
      final response = await _postWithFallback('/saved-mcqs/toggle', body);
      return _extractMap(response);
    } catch (e) {
      debugPrint('Error toggling saved mcq: $e');
      return null;
    }
  }

  /// GET /api/v1/noted-mcqs
  static Future<List<dynamic>> fetchNotedMcqs() async {
    try {
      final params = await _getUserAuthParams();
      final response = await _getWithFallback('/noted-mcqs', queryParameters: params.isNotEmpty ? params : null) ??
          await _getWithFallback('/notes', queryParameters: params.isNotEmpty ? params : null);
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching noted mcqs: $e');
      return [];
    }
  }

  /// GET /api/v1/notes (alias for backward compatibility)
  static Future<List<dynamic>> fetchNotes() => fetchNotedMcqs();

  /// POST /api/v1/noted-mcqs/save (or /notes)
  static Future<bool> saveNote({required dynamic questionId, required String note, String? type}) async {
    try {
      final authParams = await _getUserAuthParams();
      final payload = {
        'question_id': questionId,
        'note': note,
        'note_text': note,
        if (type != null && type.isNotEmpty) 'type': type,
        ...authParams,
      };
      final response = await _postWithFallback('/noted-mcqs/save', payload) ??
          await _postWithFallback('/notes', payload);
      return response != null && (response.statusCode == 200 || response.statusCode == 201);
    } catch (e) {
      debugPrint('Error saving note: $e');
      return false;
    }
  }

  /// DELETE /api/v1/noted-mcqs/{id}
  static Future<bool> deleteNote(dynamic noteId) async {
    try {
      final response = await _deleteWithFallback('/noted-mcqs/$noteId') ??
          await _deleteWithFallback('/notes/$noteId');
      return response != null && (response.statusCode == 200 || response.statusCode == 204);
    } catch (e) {
      debugPrint('Error deleting note: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────
  // 📌 10. Correct & Wrong MCQs API
  // ─────────────────────────────────────────────────────
  /// GET /api/v1/correct-mcqs
  static Future<List<dynamic>> fetchCorrectMcqs() async {
    try {
      final params = await _getUserAuthParams();
      final response = await _getWithFallback('/correct-mcqs', queryParameters: params.isNotEmpty ? params : null);
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching correct mcqs: $e');
      return [];
    }
  }

  /// GET /api/v1/wrong-mcqs
  static Future<List<dynamic>> fetchWrongMcqs() async {
    try {
      final params = await _getUserAuthParams();
      final response = await _getWithFallback('/wrong-mcqs', queryParameters: params.isNotEmpty ? params : null);
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching wrong mcqs: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────
  // 📌 11. Support & Live Chat API
  // ─────────────────────────────────────────────────────
  /// GET /api/v1/support/messages
  static Future<List<dynamic>> fetchSupportMessages({String? sessionId, String? phone}) async {
    try {
      final queryParams = <String, String>{};
      if (sessionId != null && sessionId.isNotEmpty) queryParams['session_id'] = sessionId;
      if (phone != null && phone.isNotEmpty) queryParams['phone'] = phone;

      final response = await _getWithFallback('/support/messages', queryParameters: queryParams.isNotEmpty ? queryParams : null);
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching support messages: $e');
      return [];
    }
  }

  /// POST /api/v1/support/messages
  static Future<bool> sendSupportMessage({
    required String message,
    String? sessionId,
    String? phone,
    String? firstName,
    String? lastName,
    String? attachmentPath,
  }) async {
    try {
      final payload = <String, dynamic>{
        'message': message,
        if (sessionId != null && sessionId.isNotEmpty) ...{
          'session_id': sessionId,
          'sessionId': sessionId,
        },
        if (phone != null && phone.isNotEmpty) ...{
          'phone': phone,
          'phoneNumber': phone,
          'phone_number': phone,
          'mobile': phone,
        },
        if (firstName != null && firstName.isNotEmpty) ...{
          'first_name': firstName,
          'firstName': firstName,
        },
        if (lastName != null && lastName.isNotEmpty) ...{
          'last_name': lastName,
          'lastName': lastName,
        },
        if (attachmentPath != null && attachmentPath.isNotEmpty) 'attachment_path': attachmentPath,
      };
      final response = await _postWithFallback('/support/messages', payload);
      return response != null && (response.statusCode == 200 || response.statusCode == 201);
    } catch (e) {
      debugPrint('Error sending support message: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────
  // 📌 12. Translation API
  // ─────────────────────────────────────────────────────
  /// GET /api/v1/translation
  static Future<Map<String, dynamic>?> fetchTranslation({int? questionId, String? text}) async {
    try {
      final queryParams = <String, String>{};
      if (questionId != null) queryParams['question_id'] = questionId.toString();
      if (text != null && text.isNotEmpty) queryParams['text'] = text;
      final response = await _getWithFallback('/translation', queryParameters: queryParams.isNotEmpty ? queryParams : null);
      return _extractMap(response);
    } catch (e) {
      debugPrint('Error fetching translation: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────
  // 📌 13. Patente Social API
  // ─────────────────────────────────────────────────────
  /// GET /api/v1/patente-social/cards
  static Future<List<dynamic>> fetchPatenteSocialCards() async {
    try {
      final response = await _getWithFallback('/patente-social/cards') ?? await _getWithFallback('/dashboard/cards');
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching patente social cards: $e');
      return [];
    }
  }

  /// GET /api/v1/patente-social/banners
  static Future<List<dynamic>> fetchPatenteSocialBanners() async {
    try {
      final response = await _getWithFallback('/patente-social/banners');
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching patente social banners: $e');
      return [];
    }
  }

  /// GET /api/v1/patente-social/settings
  static Future<Map<String, dynamic>?> fetchPatenteSocialSettings() async {
    try {
      final response = await _getWithFallback('/patente-social/settings');
      return _extractMap(response);
    } catch (e) {
      debugPrint('Error fetching patente social settings: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────
  // 📌 14. Manuale API (Theory Study Manual)
  // ─────────────────────────────────────────────────────
  /// GET /api/v1/manuale/chapters
  static Future<List<dynamic>> fetchManualeChapters() async {
    try {
      final response = await _getWithFallback('/manuale/chapters');
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching manuale chapters: $e');
      return [];
    }
  }

  /// GET /api/v1/manuale/pages/{chapterId}
  static Future<List<dynamic>> fetchManualePages(int chapterId) async {
    try {
      final response = await _getWithFallback('/manuale/pages/$chapterId');
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching manuale pages: $e');
      return [];
    }
  }

  /// GET /api/v1/manuale/page/{id}
  static Future<Map<String, dynamic>?> fetchManualePageDetails(int pageId) async {
    try {
      final response = await _getWithFallback('/manuale/page/$pageId');
      return _extractMap(response);
    } catch (e) {
      debugPrint('Error fetching manuale page details: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────
  // 📌 15. Leaderboard API (Top Members & Rank)
  // ─────────────────────────────────────────────────────
  /// GET /api/v1/leaderboard
  static Future<List<dynamic>> fetchLeaderboard() async {
    try {
      final response = await _getWithFallback('/leaderboard');
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────
  // 📌 16. Client Verification & App Licensing API
  // ─────────────────────────────────────────────────────
  static String? _authToken;
  static void setAuthToken(String token) {
    _authToken = token;
  }

  /// GET /api/v1/client/status
  static Future<Map<String, dynamic>?> fetchClientStatus({String? sessionId, String? phone}) async {
    try {
      final queryParams = <String, String>{};
      if (sessionId != null && sessionId.isNotEmpty) queryParams['session_id'] = sessionId;
      if (phone != null && phone.isNotEmpty) queryParams['phone'] = phone;

      final response = await _getWithFallback('/client/status', queryParameters: queryParams.isNotEmpty ? queryParams : null);
      return _extractMap(response);
    } catch (e) {
      debugPrint('Error fetching client status: $e');
      return null;
    }
  }

  /// Check license status for user phone or session ID
  static Future<String> checkLicenseStatus({String? userPhone, String? sessionId}) async {
    final statusMap = await fetchClientStatus(sessionId: sessionId, phone: userPhone);
    if (statusMap != null) {
      final bool isActive = (statusMap['free_access_mode'] == true ||
          statusMap['qr_protection_enabled'] == false ||
          statusMap['is_active'] == true ||
          statusMap['license_status'] == 'active' ||
          statusMap['status'] == 'active');
      return isActive ? 'active' : (statusMap['license_status'] ?? statusMap['status'] ?? 'inactive').toString();
    }
    return 'active';
  }




  // ─────────────────────────────────────────────────────
  // Backward Compatibility & Utility Methods
  // ─────────────────────────────────────────────────────
  static Future<List<dynamic>> fetchDashboardCards() => fetchPatenteSocialCards();

  static Future<List<dynamic>> fetchQuestionsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    try {
      final response = await _getWithFallback('/questions/by-ids', queryParameters: {'ids': ids.join(',')});
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching questions by IDs: $e');
      return [];
    }
  }

  static Future<bool> logUserMcqResult(int questionId, bool isCorrect, String userAnswer) async {
    try {
      final authParams = await _getUserAuthParams();
      final response = await _postWithFallback('/user-mcq-results/log', {
        ...authParams,
        'results': [
          {
            'question_id': questionId,
            'user_answer': userAnswer,
            'is_correct': isCorrect,
          }
        ]
      });
      return response != null && (response.statusCode == 200 || response.statusCode == 201);
    } catch (e) {
      debugPrint('Error logging user MCQ result: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> fetchSettings() => fetchPatenteSocialSettings();

  static Future<bool> unlockWebQrGate(
    String qrData, {
    String? userPhone,
    String? sessionId,
    String? firstName,
    String? lastName,
    String? licenseKey,
  }) async {
    // --- Parse token and origin from the scanned QR URL ---
    String token = qrData;
    String? qrOrigin; // base URL embedded in the QR code (always live server)
    String targetSessionId = '';

    if (qrData.startsWith('http')) {
      try {
        final uri = Uri.parse(qrData);
        qrOrigin = '${uri.scheme}://${uri.host}${uri.hasPort && uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}';
        token = uri.queryParameters['token']
            ?? uri.queryParameters['session_id']
            ?? qrData;
        targetSessionId = uri.queryParameters['session_id'] ?? '';
      } catch (_) {}
    } else if (qrData.contains('session_id=')) {
      final match = RegExp(r'session_id=([a-zA-Z0-9_\-\.]+)').firstMatch(qrData);
      if (match != null) targetSessionId = match.group(1)!;
    }

    final payload = {
      'token': token,
      'qr_code': qrData,
      'code': token,
      'target_session_id': targetSessionId,
      'session_id': targetSessionId.isNotEmpty ? targetSessionId : (sessionId ?? ''),
      if (userPhone != null && userPhone.isNotEmpty) 'phone': userPhone,
      if (userPhone != null && userPhone.isNotEmpty) 'user_phone': userPhone,
      if (firstName != null && firstName.isNotEmpty) 'first_name': firstName,
      if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
      if (licenseKey != null && licenseKey.isNotEmpty) 'license_key': licenseKey,
    };

    // Build ordered list of origins to try:
    // 1. The exact origin from the QR code (should be mbanglapatenteb.com)
    // 2. Live domain fallbacks
    // 3. Local candidates (for dev mode)
    final orderedOrigins = <String>{};
    if (qrOrigin != null && !qrOrigin.contains('mbanglapatenteb.com')) orderedOrigins.add(qrOrigin);
    for (final base in candidateBaseUrls) {
      orderedOrigins.add(base.replaceAll(RegExp(r'/api/v1/?$'), ''));
    }

    for (final origin in orderedOrigins) {
      for (final path in ['/qr-unlock', '/api/qr-unlock', '/api/v1/qr-unlock']) {
        try {
          final uri = Uri.parse('$origin$path');
          debugPrint('🔓 Trying QR unlock: $uri');
          final res = await http.post(
            uri,
            headers: defaultHeaders,
            body: json.encode(payload),
          ).timeout(const Duration(seconds: 3));
          if (res.statusCode == 200 || res.statusCode == 201) {
            debugPrint('✅ QR gate unlocked via: $uri');
            return true;
          }
          debugPrint('⚠️ QR unlock got ${res.statusCode} from $uri');
          break; // this origin responded — don't try other paths on it
        } catch (e) {
          debugPrint('❌ QR unlock failed for $origin$path: $e');
        }
      }
    }

    debugPrint('❌ QR gate unlock failed for all origins');
    return false;
  }

  static Future<List<dynamic>> fetchExamQuestions() => generateSchedaEsame();
  static Future<List<dynamic>> fetchClasses() async {
    try {
      final response = await _getWithFallback('/classes') ?? await _getWithFallback('/lezioni');
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching classes: $e');
      return [];
    }
  }
  static Future<List<dynamic>> fetchLiveClasses() => fetchEClasses();

  /// Verification endpoint for live chat support (First Name, Last Name, Phone Number)
  static Future<Map<String, dynamic>?> verifyClient({
    required String firstName,
    required String lastName,
    required String phone,
    String? sessionId,
  }) async {
    final payload = {
      'first_name': firstName,
      'firstName': firstName,
      'last_name': lastName,
      'lastName': lastName,
      'phone': phone,
      'phoneNumber': phone,
      'phone_number': phone,
      'mobile': phone,
      if (sessionId != null && sessionId.isNotEmpty) ...{
        'session_id': sessionId,
        'sessionId': sessionId,
      },
    };

    setSessionContext(sessionId: sessionId, phone: phone);

    // 1. Try /support/register (Primary endpoint per API guide)
    final resp1 = await _postWithFallback('/support/register', payload);
    if (resp1 != null && (resp1.statusCode == 200 || resp1.statusCode == 201)) {
      try {
        final decoded = json.decode(resp1.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded['token'] != null) {
            setAuthToken(decoded['token'].toString());
          }
          return decoded;
        }
      } catch (e) {
        debugPrint('Error decoding /support/register response: $e');
      }
    }

    // 2. Fallback to /client/verify
    final resp2 = await _postWithFallback('/client/verify', payload);
    if (resp2 != null && (resp2.statusCode == 200 || resp2.statusCode == 201)) {
      try {
        final decoded = json.decode(resp2.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded['token'] != null) {
            setAuthToken(decoded['token'].toString());
          }
          return decoded;
        }
      } catch (e) {
        debugPrint('Error decoding /client/verify response: $e');
      }
    }

    return null;
  }

  /// Fetch live chat messages for client by session_id or phone
  static Future<List<dynamic>> fetchChatMessages([String? sessionId, String? phone]) async {
    try {
      final queryParams = <String, String>{};
      if (sessionId != null && sessionId.isNotEmpty) queryParams['session_id'] = sessionId;
      if (phone != null && phone.isNotEmpty) queryParams['phone'] = phone;

      // 1. Primary: /support/messages
      final response = await _getWithFallback('/support/messages', queryParameters: queryParams.isNotEmpty ? queryParams : null);
      if (response != null && (response.statusCode == 200 || response.statusCode == 201)) {
        return _extractList(response);
      }

      // 2. Fallback: /chat/messages
      final resp2 = await _getWithFallback('/chat/messages', queryParameters: queryParams.isNotEmpty ? queryParams : null);
      if (resp2 != null && (resp2.statusCode == 200 || resp2.statusCode == 201)) {
        return _extractList(resp2);
      }
    } catch (e) {
      debugPrint('Error fetching chat messages: $e');
    }
    return [];
  }

  /// Send live chat message from client
  static Future<bool> sendChatMessage(
    String message, [
    String? sessionId,
    String? phone,
    String? firstName,
    String? lastName,
    String? attachmentPath,
  ]) async {
    try {
      final payload = <String, dynamic>{
        'message': message,
        if (sessionId != null && sessionId.isNotEmpty) ...{
          'session_id': sessionId,
          'sessionId': sessionId,
        },
        if (phone != null && phone.isNotEmpty) ...{
          'phone': phone,
          'phoneNumber': phone,
          'phone_number': phone,
          'mobile': phone,
        },
        if (firstName != null && firstName.isNotEmpty) ...{
          'first_name': firstName,
          'firstName': firstName,
        },
        if (lastName != null && lastName.isNotEmpty) ...{
          'last_name': lastName,
          'lastName': lastName,
        },
        if (attachmentPath != null && attachmentPath.isNotEmpty) 'attachment_path': attachmentPath,
      };

      // 1. Primary: /support/messages
      final response = await _postWithFallback('/support/messages', payload);
      if (response != null && (response.statusCode == 200 || response.statusCode == 201)) {
        return true;
      }

      // 2. Fallback: /chat/messages
      final resp2 = await _postWithFallback('/chat/messages', payload);
      if (resp2 != null && (resp2.statusCode == 200 || resp2.statusCode == 201)) {
        return true;
      }
    } catch (e) {
      debugPrint('Error sending chat message: $e');
    }
    return false;
  }

  /// Activate client license when customer clicks Attiva Licenza button in chat
  static Future<bool> activateClientLicense({String? sessionId, String? phone, int days = 365}) async {
    try {
      final payload = {
        'days': days,
        if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      };

      final response = await _postWithFallback('/client/activate', payload);
      if (response != null && (response.statusCode == 200 || response.statusCode == 201)) {
        final decoded = json.decode(response.body);
        return decoded is Map && (decoded['success'] == true || decoded['status'] == 'success');
      }
    } catch (e) {
      debugPrint('Error activating client license: $e');
    }
    return false;
  }

  // ─────────────────────────────────────────────────────
  // 📌 15. Patente Social (Community Feed) API
  // ─────────────────────────────────────────────────────
  /// GET /api/social/posts
  static Future<List<dynamic>> fetchSocialPosts({String userPhone = ''}) async {
    try {
      final serverOrigin = baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
      final uri = Uri.parse('$serverOrigin/api/social/posts').replace(queryParameters: {
        if (userPhone.isNotEmpty) 'user_phone': userPhone,
      });
      final response = await http.get(uri, headers: defaultHeaders).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map && decoded['status'] == 'success') {
          return decoded['data'] ?? [];
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching social posts: $e');
      return [];
    }
  }

  /// POST /api/social/posts/store
  static Future<Map<String, dynamic>?> createSocialPost({
    required String authorName,
    String authorPhone = '',
    String authorAvatar = '',
    required String content,
    String? imageUrl,
  }) async {
    try {
      final serverOrigin = baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
      final uri = Uri.parse('$serverOrigin/api/social/posts/store');
      final body = {
        'author_name': authorName,
        'author_phone': authorPhone,
        'author_avatar': authorAvatar,
        'content': content,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
      };
      final response = await http.post(uri, headers: defaultHeaders, body: json.encode(body)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error creating social post: $e');
      return null;
    }
  }

  /// POST /api/social/posts/like/{id}
  static Future<Map<String, dynamic>?> likeSocialPost(int postId, String userPhone) async {
    try {
      final serverOrigin = baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
      final uri = Uri.parse('$serverOrigin/api/social/posts/like/$postId');
      final response = await http.post(uri, headers: defaultHeaders, body: json.encode({'user_phone': userPhone})).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error liking social post: $e');
      return null;
    }
  }

  /// POST /api/social/posts/comments/store
  static Future<Map<String, dynamic>?> addSocialComment({
    required int postId,
    required String authorName,
    String authorPhone = '',
    String authorAvatar = '',
    required String comment,
  }) async {
    try {
      final serverOrigin = baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
      final uri = Uri.parse('$serverOrigin/api/social/posts/comments/store');
      final body = {
        'post_id': postId,
        'author_name': authorName,
        'author_phone': authorPhone,
        'author_avatar': authorAvatar,
        'comment': comment,
      };
      final response = await http.post(uri, headers: defaultHeaders, body: json.encode(body)).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error adding comment: $e');
      return null;
    }
  }

  /// POST /api/social/posts/delete/{id}
  static Future<bool> deleteSocialPost(int postId, String authorPhone) async {
    try {
      final serverOrigin = baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
      final uri = Uri.parse('$serverOrigin/api/social/posts/delete/$postId');
      final response = await http.post(uri, headers: defaultHeaders, body: json.encode({'author_phone': authorPhone})).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting social post: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────
  // 📌 16. Translation API
  // ─────────────────────────────────────────────────────
  /// POST /api/translate
  static Future<Map<String, dynamic>?> translateText({
    required String text,
    required String fromLang,
    required String toLang,
  }) async {
    try {
      final serverOrigin = baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
      final uri = Uri.parse('$serverOrigin/api/translate');
      final body = {
        'text': text,
        'from_lang': fromLang,
        'to_lang': toLang,
      };
      final response = await http.post(uri, headers: defaultHeaders, body: json.encode(body)).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error performing translation: $e');
      return null;
    }
  }
}


