import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/slider_model.dart';
import '../models/home_card_model.dart';

class ApiService {
  static const String liveProductionUrl = 'https://mbanglapatenteb.com/api/v1';
  static const String liveOrigin = 'https://mbanglapatenteb.com';

  static const List<String> candidateBaseUrls = [
    'https://mbanglapatenteb.com/api/v1',
    'https://mbanglapatenteb.com/api',
  ];

  static String? _resolvedBaseUrl = 'https://mbanglapatenteb.com/api/v1';
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
    _resolvedBaseUrl = liveProductionUrl;
    debugPrint('🧹 ApiService: All in-memory API caches cleared.');
  }

  /// Initialize server configuration by probing live URLs and fetching active settings
  static Future<void> initServerConfig() async {
    _resolvedBaseUrl = liveProductionUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_cached_base_url', liveProductionUrl);

      // Immediately restore stored user identity into memory
      final phone = prefs.getString('app_client_phone') ??
          prefs.getString('user_phone') ??
          prefs.getString('phone');
      final sessionId = prefs.getString('app_client_session_id') ??
          prefs.getString('session_id');
      final token = prefs.getString('app_client_token');

      if (phone != null && phone.trim().isNotEmpty) _activeClientPhone = phone.trim();
      if (sessionId != null && sessionId.trim().isNotEmpty) _activeSessionId = sessionId.trim();
      if (token != null && token.trim().isNotEmpty) _authToken = token.trim();

      // Probe live server settings
      final uri = Uri.parse('$liveProductionUrl/settings');
      final response = await http.get(uri, headers: defaultHeaders).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          _checkAndApplyServerMode(decoded, currentCandidate: liveProductionUrl);
        }
      }
    } catch (e) {
      debugPrint('Live Server Probe Note: $e');
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
      headers['X-Client-Session-ID'] = _activeSessionId!;
    }
    if (_activeClientPhone != null && _activeClientPhone!.isNotEmpty) {
      headers['X-Client-Phone'] = _activeClientPhone!;
    }
    return headers;
  }

  /// Helper to convert relative image path (/uploads/...) to full absolute HTTP URL
  static String formatImageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    var cleanPath = path.trim();
    if (cleanPath.toLowerCase() == 'null' ||
        cleanPath.toLowerCase() == 'undefined' ||
        cleanPath.toLowerCase() == 'none') {
      return '';
    }
    if (cleanPath.startsWith('file://') ||
        cleanPath.startsWith('/data/user/') ||
        cleanPath.startsWith('/data/data/') ||
        cleanPath.startsWith('/storage/emulated/')) {
      return '';
    }

    // Ignore/reject any seeder image files
    final lower = cleanPath.toLowerCase();
    if (lower.contains('seeder') ||
        lower.contains('seeders') ||
        lower.contains('/seed') ||
        lower.contains('seed/') ||
        lower.contains('seed_') ||
        lower.contains('_seed') ||
        lower.startsWith('seed')) {
      return '';
    }

    // Normalize backslashes (e.g. from Windows server DB seeding or paths)
    cleanPath = cleanPath.replaceAll(r'\', '/');

    // Replace any localhost or local dev IP in stored URLs with the live production origin
    cleanPath = cleanPath.replaceAll(
      RegExp(r'https?://(?:127\.0\.0\.1|localhost|192\.168\.\d+\.\d+|10\.0\.2\.2)(?::\d+)?'),
      liveOrigin,
    );

    // Fix /api/v1/uploads or /api/uploads if mistakenly stored or concatenated
    cleanPath = cleanPath.replaceAll('/api/v1/uploads', '/uploads').replaceAll('/api/uploads', '/uploads');

    // Protocol-relative URLs (e.g. //mbanglapatenteb.com/uploads/...)
    if (cleanPath.startsWith('//')) {
      return 'https:$cleanPath';
    }

    // Always enforce HTTPS for the production domain
    if (cleanPath.startsWith('http://mbanglapatenteb.com')) {
      cleanPath = cleanPath.replaceFirst('http://', 'https://');
    }

    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
      return cleanPath;
    }

    final normalized = cleanPath.startsWith('/') ? cleanPath : '/$cleanPath';
    return '$liveOrigin$normalized';
  }

  static final Map<String, http.Response> _apiResponseCache = {};

  /// Invalidate cached user records when actions happen
  static void invalidateUserDataCache() {
    _apiResponseCache.removeWhere((key, _) =>
        key.startsWith('/saved-mcqs') ||
        key.startsWith('/noted-mcqs') ||
        key.startsWith('/notes') ||
        key.startsWith('/correct-mcqs') ||
        key.startsWith('/wrong-mcqs') ||
        key.startsWith('/user-mcq-results') ||
        key.startsWith('/mcq-results'));
  }

  /// Helper to perform HTTP GET with dynamic candidate URL resolution & fallback (ultra-fast sub-second caching)
  static Future<http.Response?> _getWithFallback(String endpoint, {Map<String, String>? queryParameters, bool useCache = true}) async {
    final cacheKey = '$endpoint?${queryParameters?.entries.map((e) => '${e.key}=${e.value}').join('&') ?? ''}';
    if (useCache && _apiResponseCache.containsKey(cacheKey)) {
      return _apiResponseCache[cacheKey];
    }

    if (_resolvedBaseUrl != null) {
      try {
        final uri = Uri.parse('$_resolvedBaseUrl$endpoint').replace(queryParameters: queryParameters);
        final response = await http.get(uri, headers: defaultHeaders).timeout(const Duration(milliseconds: 2500));
        if (response.statusCode == 200) {
          if (useCache) _apiResponseCache[cacheKey] = response;
          return response;
        }
      } catch (_) {}
    }

    // Fast parallel race across all candidate base URLs
    final completer = Completer<http.Response?>();
    int pending = candidateBaseUrls.length;

    for (final base in candidateBaseUrls) {
      final uri = Uri.parse('$base$endpoint').replace(queryParameters: queryParameters);
      http.get(uri, headers: defaultHeaders).timeout(const Duration(milliseconds: 2500)).then((resp) {
        if (resp.statusCode == 200 && !completer.isCompleted) {
          _resolvedBaseUrl = base;
          SharedPreferences.getInstance().then((p) => p.setString('app_cached_base_url', base)).catchError((_) => false);
          if (useCache) _apiResponseCache[cacheKey] = resp;
          completer.complete(resp);
        } else {
          pending--;
          if (pending == 0 && !completer.isCompleted) completer.complete(null);
        }
      }).catchError((_) {
        pending--;
        if (pending == 0 && !completer.isCompleted) completer.complete(null);
      });
    }

    return completer.future;
  }

  /// Helper to perform HTTP POST with dynamic candidate URL resolution & fallback
  static Future<http.Response?> _postWithFallback(String endpoint, Map<String, dynamic> body) async {
    if (_resolvedBaseUrl != null) {
      try {
        final uri = Uri.parse('$_resolvedBaseUrl$endpoint');
        final response = await http
            .post(uri, headers: defaultHeaders, body: json.encode(body))
            .timeout(const Duration(milliseconds: 3000));
        if (response.statusCode == 200 || response.statusCode == 201) return response;
      } catch (_) {}
    }

    // Parallel attempt across candidates
    final completer = Completer<http.Response?>();
    int pending = candidateBaseUrls.length;

    for (final base in candidateBaseUrls) {
      final uri = Uri.parse('$base$endpoint');
      http.post(uri, headers: defaultHeaders, body: json.encode(body)).timeout(const Duration(milliseconds: 3000)).then((resp) {
        if ((resp.statusCode == 200 || resp.statusCode == 201) && !completer.isCompleted) {
          _resolvedBaseUrl = base;
          SharedPreferences.getInstance().then((p) => p.setString('app_cached_base_url', base)).catchError((_) => false);
          completer.complete(resp);
        } else {
          pending--;
          if (pending == 0 && !completer.isCompleted) completer.complete(null);
        }
      }).catchError((_) {
        pending--;
        if (pending == 0 && !completer.isCompleted) completer.complete(null);
      });
    }

    return completer.future;
  }

  /// Helper to perform HTTP DELETE with dynamic candidate URL resolution & fallback
  static Future<http.Response?> _deleteWithFallback(String endpoint) async {
    if (_resolvedBaseUrl != null) {
      try {
        final uri = Uri.parse('$_resolvedBaseUrl$endpoint');
        final response = await http.delete(uri, headers: defaultHeaders).timeout(const Duration(milliseconds: 3000));
        if (response.statusCode == 200 || response.statusCode == 204) return response;
      } catch (_) {}
    }

    for (final base in candidateBaseUrls) {
      try {
        final uri = Uri.parse('$base$endpoint');
        final response = await http.delete(uri, headers: defaultHeaders).timeout(const Duration(milliseconds: 3000));
        if (response.statusCode == 200 || response.statusCode == 204) {
          _resolvedBaseUrl = base;
          return response;
        }
      } catch (_) {}
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
          if (decoded['messages'] is List) return decoded['messages'] as List<dynamic>;
          if (decoded['results'] is List) return decoded['results'] as List<dynamic>;
          if (decoded['words'] is List) return decoded['words'] as List<dynamic>;
          if (decoded['items'] is List) return decoded['items'] as List<dynamic>;
          if (decoded['mcqs'] is List) return decoded['mcqs'] as List<dynamic>;
          if (decoded['data'] is Map<String, dynamic>) {
            final subMap = decoded['data'] as Map<String, dynamic>;
            if (subMap['messages'] is List) return subMap['messages'] as List<dynamic>;
            if (subMap['results'] is List) return subMap['results'] as List<dynamic>;
            if (subMap['data'] is List) return subMap['data'] as List<dynamic>;
            if (subMap['words'] is List) return subMap['words'] as List<dynamic>;
            if (subMap['items'] is List) return subMap['items'] as List<dynamic>;
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
      invalidateUserDataCache();
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

  static Future<Map<String, String>> _getUserAuthParams() => getUserAuthParams();

  static Future<Map<String, String>> getUserAuthParams() async {
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

      if (phone != null && phone.trim().isNotEmpty) {
        _activeClientPhone = phone.trim();
        params['phone'] = phone.trim();
        params['user_phone'] = phone.trim();
      } else if (_activeClientPhone != null && _activeClientPhone!.isNotEmpty) {
        params['phone'] = _activeClientPhone!;
        params['user_phone'] = _activeClientPhone!;
      }

      if (sessionId.trim().isNotEmpty) {
        _activeSessionId = sessionId.trim();
        params['session_id'] = sessionId.trim();
      } else if (_activeSessionId != null && _activeSessionId!.isNotEmpty) {
        params['session_id'] = _activeSessionId!;
      }

      if (firstName != null && firstName.trim().isNotEmpty) {
        params['first_name'] = firstName.trim();
        params['name'] = firstName.trim();
      }
      if (lastName != null && lastName.trim().isNotEmpty) {
        params['last_name'] = lastName.trim();
      }
      if (userId != null && userId > 0) {
        params['user_id'] = '$userId';
      }
    } catch (_) {}
    return params;
  }

  // ─────────────────────────────────────────────────────
  // 📌 9. Saved MCQs & Notes API (100% Cross-Platform Sync)
  // ─────────────────────────────────────────────────────
  /// GET /api/v1/saved-mcqs
  static Future<List<dynamic>> fetchSavedMcqs({String? sessionId, String? phone, int? userId}) async {
    try {
      final params = await _getUserAuthParams();
      if (sessionId != null && sessionId.isNotEmpty) params['session_id'] = sessionId;
      if (phone != null && phone.isNotEmpty) {
        params['phone'] = phone;
        params['user_phone'] = phone;
      }
      if (userId != null) params['user_id'] = '$userId';
      final response = await _getWithFallback('/saved-mcqs', queryParameters: params.isNotEmpty ? params : null, useCache: false);
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching saved mcqs: $e');
      return [];
    }
  }

  /// POST /api/v1/saved-mcqs/toggle
  static Future<Map<String, dynamic>?> toggleSavedMcq(
    dynamic questionId, {
    String? type = 'argomenti',
    String? italian,
    String? sessionId,
    String? phone,
  }) async {
    try {
      final authParams = await _getUserAuthParams();
      final body = <String, dynamic>{
        'question_id': questionId,
        if (italian != null && italian.isNotEmpty) 'italian': italian,
        'type': type ?? 'argomenti',
        ...authParams,
        if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
        if (phone != null && phone.isNotEmpty) ...{
          'phone': phone,
          'user_phone': phone,
        },
      };
      final response = await _postWithFallback('/saved-mcqs/toggle', body) ??
          await _postWithFallback('/saved-mcqs', body);
      invalidateUserDataCache();
      return _extractMap(response);
    } catch (e) {
      debugPrint('Error toggling saved mcq: $e');
      return null;
    }
  }

  /// GET /api/v1/noted-mcqs
  static Future<List<dynamic>> fetchNotedMcqs({String? sessionId, String? phone, int? userId}) async {
    try {
      final params = await _getUserAuthParams();
      if (sessionId != null && sessionId.isNotEmpty) params['session_id'] = sessionId;
      if (phone != null && phone.isNotEmpty) {
        params['phone'] = phone;
        params['user_phone'] = phone;
      }
      if (userId != null) params['user_id'] = '$userId';
      final response = await _getWithFallback('/noted-mcqs', queryParameters: params.isNotEmpty ? params : null, useCache: false) ??
          await _getWithFallback('/notes', queryParameters: params.isNotEmpty ? params : null, useCache: false);
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching noted mcqs: $e');
      return [];
    }
  }

  /// GET /api/v1/notes (alias for backward compatibility)
  static Future<List<dynamic>> fetchNotes({String? sessionId, String? phone, int? userId}) =>
      fetchNotedMcqs(sessionId: sessionId, phone: phone, userId: userId);

  /// POST /api/v1/noted-mcqs/save (or /notes)
  static Future<bool> saveNote({
    required dynamic questionId,
    required String note,
    int? pageId,
    String? type = 'argomenti',
    String? sessionId,
    String? phone,
  }) async {
    try {
      final authParams = await _getUserAuthParams();
      final payload = {
        'question_id': questionId,
        if (pageId != null) 'page_id': pageId,
        'note': note,
        'note_text': note,
        'text': note,
        'type': type ?? 'argomenti',
        ...authParams,
        if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
        if (phone != null && phone.isNotEmpty) ...{
          'phone': phone,
          'user_phone': phone,
        },
      };
      final response = await _postWithFallback('/noted-mcqs/save', payload) ??
          await _postWithFallback('/noted-mcqs', payload) ??
          await _postWithFallback('/notes/save', payload) ??
          await _postWithFallback('/notes', payload);
      invalidateUserDataCache();
      return response != null && (response.statusCode == 200 || response.statusCode == 201);
    } catch (e) {
      debugPrint('Error saving note: $e');
      return false;
    }
  }

  /// DELETE /api/v1/noted-mcqs/{id} or POST /api/v1/noted-mcqs/delete
  static Future<bool> deleteNote(dynamic noteId, {String? sessionId, String? phone}) async {
    try {
      final authParams = await _getUserAuthParams();
      final payload = {
        'id': noteId,
        'question_id': noteId,
        ...authParams,
        if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
        if (phone != null && phone.isNotEmpty) ...{
          'phone': phone,
          'user_phone': phone,
        },
      };
      final response = await _deleteWithFallback('/noted-mcqs/$noteId') ??
          await _deleteWithFallback('/notes/$noteId') ??
          await _postWithFallback('/noted-mcqs/delete', payload) ??
          await _postWithFallback('/notes/delete', payload);
      invalidateUserDataCache();
      return response != null && (response.statusCode == 200 || response.statusCode == 204);
    } catch (e) {
      debugPrint('Error deleting note: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────
  // 📌 10. Correct & Wrong MCQs API (100% Cross-Platform Sync)
  // ─────────────────────────────────────────────────────
  /// GET /api/v1/correct-mcqs
  static Future<List<dynamic>> fetchCorrectMcqs({String? sessionId, String? phone}) async {
    try {
      final params = await _getUserAuthParams();
      if (sessionId != null && sessionId.isNotEmpty) params['session_id'] = sessionId;
      if (phone != null && phone.isNotEmpty) {
        params['phone'] = phone;
        params['user_phone'] = phone;
      }
      final response = await _getWithFallback('/correct-mcqs', queryParameters: params.isNotEmpty ? params : null, useCache: false);
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching correct mcqs: $e');
      return [];
    }
  }

  /// GET /api/v1/wrong-mcqs
  static Future<List<dynamic>> fetchWrongMcqs({String? sessionId, String? phone}) async {
    try {
      final params = await _getUserAuthParams();
      if (sessionId != null && sessionId.isNotEmpty) params['session_id'] = sessionId;
      if (phone != null && phone.isNotEmpty) {
        params['phone'] = phone;
        params['user_phone'] = phone;
      }
      final response = await _getWithFallback('/wrong-mcqs', queryParameters: params.isNotEmpty ? params : null, useCache: false);
      return _extractList(response);
    } catch (e) {
      debugPrint('Error fetching wrong mcqs: $e');
      return [];
    }
  }

  /// POST /api/v1/user-mcq-results/log (Two-way sync for question practice results)
  static Future<bool> logUserMcqResult(
    dynamic questionId,
    bool isCorrect,
    String? userAnswer, {
    String? type = 'argomenti',
    String? sessionId,
    String? phone,
  }) async {
    try {
      final authParams = await _getUserAuthParams();
      final qId = questionId is int ? questionId : int.tryParse('$questionId') ?? 0;
      final answer = userAnswer ?? (isCorrect ? 'V' : 'F');
      final body = <String, dynamic>{
        'question_id': qId,
        'is_correct': isCorrect ? 1 : 0,
        'user_answer': answer,
        'type': type ?? 'argomenti',
        'results': [
          {
            'question_id': qId,
            'user_answer': answer,
            'is_correct': isCorrect ? 1 : 0,
          }
        ],
        ...authParams,
        if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
        if (phone != null && phone.isNotEmpty) ...{
          'phone': phone,
          'user_phone': phone,
        },
      };
      final response = await _postWithFallback('/user-mcq-results/log', body) ??
          await _postWithFallback('/mcq-results/log', body) ??
          await _postWithFallback('/user-mcq-results', body) ??
          await _postWithFallback('/mcq-results', body);
      invalidateUserDataCache();
      return response != null && (response.statusCode == 200 || response.statusCode == 201);
    } catch (e) {
      debugPrint('Error logging user mcq result: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────
  // 📌 11. Support & Live Chat API
  // ─────────────────────────────────────────────────────
  /// GET /api/v1/support/messages
  static Future<List<dynamic>> fetchSupportMessages({String? sessionId, String? phone}) async {
    try {
      final authParams = await _getUserAuthParams();
      final queryParams = <String, String>{};
      final effectivePhone = (phone != null && phone.isNotEmpty) ? phone : authParams['phone'];
      final effectiveSessionId = (sessionId != null && sessionId.isNotEmpty) ? sessionId : authParams['session_id'];

      if (effectiveSessionId != null && effectiveSessionId.isNotEmpty) queryParams['session_id'] = effectiveSessionId;
      if (effectivePhone != null && effectivePhone.isNotEmpty) {
        queryParams['phone'] = effectivePhone;
        queryParams['user_phone'] = effectivePhone;
      }

      final response = await _getWithFallback('/support/messages', queryParameters: queryParams.isNotEmpty ? queryParams : null, useCache: false);
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
  // 📌 13. Drag & Drop Home Cards API & Patente Social
  // ─────────────────────────────────────────────────────
  /// GET /api/v1/home-cards (sorted by order_index ASC)
  static Future<List<HomeCardModel>> fetchHomeCards() async {
    try {
      final response = await _getWithFallback('/home-cards') ??
          await _getWithFallback('/dashboard/cards') ??
          await _getWithFallback('/patente-social/cards') ??
          await _getWithFallback('/cards');

      final list = _extractList(response);
      if (list.isNotEmpty) {
        final models = list.map((item) {
          if (item is Map<String, dynamic>) {
            return HomeCardModel.fromJson(item);
          } else if (item is Map) {
            return HomeCardModel.fromJson(Map<String, dynamic>.from(item));
          }
          return null;
        }).whereType<HomeCardModel>().toList();

        // Sort strictly by order_index ASC, then id ASC
        models.sort((a, b) {
          final comp = a.orderIndex.compareTo(b.orderIndex);
          if (comp != 0) return comp;
          return a.id.compareTo(b.id);
        });

        return models;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching home cards: $e');
      return [];
    }
  }

  /// POST /api/v1/home-cards/reorder (Drag & drop bulk reorder sync)
  static Future<bool> reorderHomeCards(List<int> cardIds) async {
    try {
      final response = await _postWithFallback('/home-cards/reorder', {
        'orders': cardIds,
      });
      if (response != null && (response.statusCode == 200 || response.statusCode == 201)) {
        final data = _extractMap(response);
        if (data != null && (data['status'] == 'success' || data['success'] == true)) {
          return true;
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error reordering home cards: $e');
      return false;
    }
  }

  /// GET /api/v1/patente-social/cards
  static Future<List<dynamic>> fetchPatenteSocialCards() async {
    try {
      final response = await _getWithFallback('/home-cards') ??
          await _getWithFallback('/patente-social/cards') ??
          await _getWithFallback('/dashboard/cards');
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

  /// GET /api/v1/license/status or /client/status
  static Future<Map<String, dynamic>?> fetchClientStatus({String? sessionId, String? phone}) async {
    try {
      final authParams = await _getUserAuthParams();
      final queryParams = <String, String>{};
      final effectivePhone = (phone != null && phone.isNotEmpty) ? phone : authParams['phone'];
      final effectiveSessionId = (sessionId != null && sessionId.isNotEmpty) ? sessionId : authParams['session_id'];

      if (effectiveSessionId != null && effectiveSessionId.isNotEmpty) queryParams['session_id'] = effectiveSessionId;
      if (effectivePhone != null && effectivePhone.isNotEmpty) {
        queryParams['phone'] = effectivePhone;
        queryParams['user_phone'] = effectivePhone;
      }

      final response = await _getWithFallback('/license/status', queryParameters: queryParams.isNotEmpty ? queryParams : null, useCache: false) ??
          await _getWithFallback('/client/status', queryParameters: queryParams.isNotEmpty ? queryParams : null, useCache: false) ??
          await _getWithFallback('/settings', queryParameters: queryParams.isNotEmpty ? queryParams : null, useCache: false);
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
      final bool isFreeAccess = statusMap['protection_disabled'] == true ||
          statusMap['free_access_mode'] == true ||
          statusMap['qr_protection_enabled'] == false;
      final bool isExplicitlyInactive = statusMap['status'] == 'inactive' ||
          statusMap['license_status'] == 'inactive' ||
          (statusMap.containsKey('is_active') && statusMap['is_active'] == false && !isFreeAccess);
      if (isExplicitlyInactive) return 'inactive';

      final bool isActive = isFreeAccess ||
          statusMap['is_active'] == true ||
          statusMap['license_status'] == 'active' ||
          statusMap['status'] == 'active' ||
          (statusMap['success'] == true && statusMap['status'] != 'inactive');
      return isActive ? 'active' : 'inactive';
    }
    return 'inactive';
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
      'qr_data': qrData,
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
      for (final path in [
        '/api/v1/qr-verification/verify',
        '/qr-verification/verify',
        '/qr-unlock',
        '/api/qr-unlock',
        '/api/v1/qr-unlock',
      ]) {
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

  /// Fetch live chat messages for client by session_id or phone (Real-time sync, never cached)
  static Future<List<dynamic>> fetchChatMessages([String? sessionId, String? phone]) async {
    try {
      final authParams = await _getUserAuthParams();
      final queryParams = <String, String>{};
      final effectivePhone = (phone != null && phone.isNotEmpty) ? phone : authParams['phone'];
      final effectiveSessionId = (sessionId != null && sessionId.isNotEmpty) ? sessionId : authParams['session_id'];

      if (effectiveSessionId != null && effectiveSessionId.isNotEmpty) queryParams['session_id'] = effectiveSessionId;
      if (effectivePhone != null && effectivePhone.isNotEmpty) {
        queryParams['phone'] = effectivePhone;
        queryParams['user_phone'] = effectivePhone;
      }

      // 1. Primary: /support/messages
      final response = await _getWithFallback('/support/messages', queryParameters: queryParams.isNotEmpty ? queryParams : null, useCache: false);
      if (response != null && (response.statusCode == 200 || response.statusCode == 201)) {
        return _extractList(response);
      }

      // 2. Fallback: /chat/messages
      final resp2 = await _getWithFallback('/chat/messages', queryParameters: queryParams.isNotEmpty ? queryParams : null, useCache: false);
      if (resp2 != null && (resp2.statusCode == 200 || resp2.statusCode == 201)) {
        return _extractList(resp2);
      }
    } catch (e) {
      debugPrint('Error fetching chat messages: $e');
    }
    return [];
  }

  /// Direct Image & Screenshot Upload to /chat/upload-image (saved in public/uploads/live_chat/)
  static Future<String?> uploadChatImage(File imageFile) async {
    try {
      if (!imageFile.existsSync()) return null;

      final endpoints = [
        '/chat/upload-image',
        '/support/upload-image',
      ];

      final extension = imageFile.path.split('.').last.toLowerCase();
      String mimeType = 'image/jpeg';
      if (extension == 'png') {
        mimeType = 'image/png';
      } else if (extension == 'webp') {
        mimeType = 'image/webp';
      } else if (extension == 'gif') {
        mimeType = 'image/gif';
      }

      final activeBases = _resolvedBaseUrl != null
          ? [_resolvedBaseUrl!, ...candidateBaseUrls.where((b) => b != _resolvedBaseUrl)]
          : candidateBaseUrls;

      for (final base in activeBases) {
        for (final ep in endpoints) {
          try {
            final uri = Uri.parse('$base$ep');
            final request = http.MultipartRequest('POST', uri);
            request.headers.addAll({
              'Accept': 'application/json',
              if (_authToken != null) 'Authorization': 'Bearer $_authToken',
            });

            request.files.add(
              await http.MultipartFile.fromPath(
                'image',
                imageFile.path,
                contentType: MediaType.parse(mimeType),
              ),
            );

            final streamedResponse = await request.send().timeout(const Duration(seconds: 12));
            final response = await http.Response.fromStream(streamedResponse);

            if (response.statusCode == 200 || response.statusCode == 201) {
              _resolvedBaseUrl = base;
              final data = json.decode(response.body);
              final uploadedUrl = (data['image_url'] ??
                      data['attachment_path'] ??
                      data['url'] ??
                      data['file_path'] ??
                      data['data']?['attachment_path'] ??
                      data['data']?['image_url'])
                  ?.toString();
              if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
                return uploadedUrl;
              }
            }
          } catch (e) {
            debugPrint('Error uploading chat image to $base$ep: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('General error uploading chat image: $e');
    }
    return null;
  }

  /// Send live chat message from client with optional image attachment
  static Future<bool> sendChatMessage(
    String message, [
    String? sessionId,
    String? phone,
    String? firstName,
    String? lastName,
    String? localOrServerAttachmentPath,
  ]) async {
    try {
      String? serverAttachmentPath;
      File? localImageFile;

      // If a local file path was provided, upload it to the server first
      if (localOrServerAttachmentPath != null && localOrServerAttachmentPath.isNotEmpty) {
        final localFile = File(localOrServerAttachmentPath);
        if (localFile.existsSync()) {
          localImageFile = localFile;
          serverAttachmentPath = await uploadChatImage(localFile);
          debugPrint('Uploaded chat image path: $serverAttachmentPath');
        } else {
          serverAttachmentPath = localOrServerAttachmentPath;
        }
      }

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
        if (serverAttachmentPath != null && serverAttachmentPath.isNotEmpty) ...{
          'attachment_path': serverAttachmentPath,
          'attachment': serverAttachmentPath,
          'image_url': serverAttachmentPath,
        },
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

      // 3. Fallback: direct multipart request if JSON failed and local file is available
      if (localImageFile != null) {
        final activeBases = _resolvedBaseUrl != null
            ? [_resolvedBaseUrl!, ...candidateBaseUrls.where((b) => b != _resolvedBaseUrl)]
            : candidateBaseUrls;

        for (final base in activeBases) {
          for (final ep in ['/chat/messages', '/support/messages']) {
            try {
              final uri = Uri.parse('$base$ep');
              final request = http.MultipartRequest('POST', uri);
              request.headers['Accept'] = 'application/json';
              if (_authToken != null) request.headers['Authorization'] = 'Bearer $_authToken';

              if (sessionId != null && sessionId.isNotEmpty) request.fields['session_id'] = sessionId;
              if (phone != null && phone.isNotEmpty) request.fields['phone'] = phone;
              if (firstName != null && firstName.isNotEmpty) request.fields['first_name'] = firstName;
              if (lastName != null && lastName.isNotEmpty) request.fields['last_name'] = lastName;
              request.fields['message'] = message.isNotEmpty ? message : 'ছবি পাঠানো হয়েছে';
              if (serverAttachmentPath != null) request.fields['attachment_path'] = serverAttachmentPath;

              final extension = localImageFile.path.split('.').last.toLowerCase();
              final mime = extension == 'png' ? 'image/png' : 'image/jpeg';
              request.files.add(
                await http.MultipartFile.fromPath('image', localImageFile.path, contentType: MediaType.parse(mime)),
              );

              final streamed = await request.send().timeout(const Duration(seconds: 12));
              final res = await http.Response.fromStream(streamed);
              if (res.statusCode == 200 || res.statusCode == 201) {
                return true;
              }
            } catch (_) {}
          }
        }
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
  /// POST /api/v1/translate (or fallback GET /api/v1/translate or direct Google Translate)
  static Future<Map<String, dynamic>?> translateText({
    required String text,
    String fromLang = 'it',
    String toLang = 'bn',
  }) async {
    final queryText = text.trim();
    if (queryText.isEmpty) return null;

    // 1. Google Translate API (fast, reliable, handles Bangla <-> Italian accurately)
    try {
      final gUrl = 'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$fromLang&tl=$toLang&dt=t&q=${Uri.encodeComponent(queryText)}';
      final gResponse = await http.get(Uri.parse(gUrl)).timeout(const Duration(seconds: 8));
      if (gResponse.statusCode == 200) {
        final decoded = json.decode(utf8.decode(gResponse.bodyBytes));
        if (decoded is List && decoded.isNotEmpty && decoded[0] is List) {
          final List parts = decoded[0];
          String result = '';
          for (var part in parts) {
            if (part is List && part.isNotEmpty && part[0] != null) {
              result += part[0].toString();
            }
          }
          if (result.trim().isNotEmpty) {
            return {
              'success': true,
              'translated_text': result.trim(),
              'original_text': queryText,
              'from_lang': fromLang,
              'to_lang': toLang,
            };
          }
        }
      }
    } catch (e) {
      debugPrint('Google Translate API error: $e');
    }

    // 2. Fallback to backend API endpoint
    try {
      final payload = {
        'text': queryText,
        'from_lang': fromLang,
        'to_lang': toLang,
      };
      final response = await _postWithFallback('/translate', payload);
      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          if (data['translated_text'] != null) return data;
          if (data['data'] != null && data['data'] is Map && data['data']['translated_text'] != null) {
            return Map<String, dynamic>.from(data['data']);
          }
          if (data['translation'] != null) {
            return {'translated_text': data['translation']};
          }
        }
      }
      final resp2 = await _getWithFallback('/translate', queryParameters: {'text': queryText, 'from_lang': fromLang, 'to_lang': toLang});
      if (resp2 != null && resp2.statusCode == 200) {
        final data = json.decode(resp2.body);
        if (data is Map<String, dynamic>) {
          if (data['translated_text'] != null) return data;
          if (data['data'] != null && data['data'] is Map && data['data']['translated_text'] != null) {
            return Map<String, dynamic>.from(data['data']);
          }
          if (data['translation'] != null) {
            return {'translated_text': data['translation']};
          }
        }
      }
    } catch (e) {
      debugPrint('Backend translate API fallback error: $e');
    }
    return null;
  }

  /// GET /api/v1/translation?question_id={id}
  static Future<Map<String, dynamic>?> getQuestionTranslation(dynamic questionId) async {
    try {
      final response = await _getWithFallback('/translation', queryParameters: {'question_id': '$questionId'}, useCache: true);
      if (response != null && response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map && decoded['data'] is Map<String, dynamic>) {
          return decoded['data'];
        } else if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (e) {
      debugPrint('Error getting question translation: $e');
    }
    return null;
  }
}


