import 'dart:convert';

class McqQuestion {
  final int id;
  final int chapter;
  final String chapterName;
  final String italian;
  final String bangla;
  final bool isVero;
  final String? image;
  final String? audio;
  final List<dynamic>? vocabulary;

  const McqQuestion({
    this.id = 0,
    required this.chapter,
    required this.chapterName,
    required this.italian,
    required this.bangla,
    required this.isVero,
    this.image,
    this.audio,
    this.vocabulary,
  });

  factory McqQuestion.fromJson(Map<String, dynamic> json) {
    final rawIsVero = json['is_vero'] ?? json['correct_answer'] ?? json['answer'] ?? json['isVero'];
    bool isVeroBool = true;
    if (rawIsVero is bool) {
      isVeroBool = rawIsVero;
    } else if (rawIsVero is String) {
      isVeroBool = rawIsVero.toLowerCase() == 'vero' || rawIsVero == '1' || rawIsVero.toLowerCase() == 'true';
    } else if (rawIsVero is int) {
      isVeroBool = rawIsVero == 1;
    }

    final rawAudio = json['audio'] ?? json['voice'] ?? json['mp3'] ?? json['audio_file'] ?? json['audio_url'];

    final rawVocab = json['vocabulary'] ?? json['vocabulary_underlines'] ?? json['underlines'];
    List<dynamic>? parsedVocab;
    if (rawVocab is List) {
      parsedVocab = rawVocab;
    } else if (rawVocab is String && rawVocab.isNotEmpty) {
      try {
        parsedVocab = jsonDecode(rawVocab);
      } catch (_) {}
    }

    return McqQuestion(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      chapter: json['chapter_id'] is int ? json['chapter_id'] : int.tryParse(json['chapter_id']?.toString() ?? '1') ?? 1,
      chapterName: json['chapter_name']?.toString() ?? json['category_name']?.toString() ?? 'Capitolo 1',
      italian: json['italian']?.toString() ?? json['question']?.toString() ?? '',
      bangla: json['bangla']?.toString() ?? json['bn_question']?.toString() ?? json['bn_translation']?.toString() ?? '',
      isVero: isVeroBool,
      image: json['image']?.toString(),
      audio: rawAudio?.toString(),
      vocabulary: parsedVocab,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapter': chapter,
      'chapterName': chapterName,
      'italian': italian,
      'bangla': bangla,
      'isVero': isVero,
      'image': image,
      'audio': audio,
      'vocabulary': vocabulary,
    };
  }
}
