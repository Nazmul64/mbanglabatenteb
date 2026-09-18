import 'dart:convert';

class McqQuestion {
  final int id;
  final int chapter;
  final String chapterName;
  final String italian;
  final String bangla;
  final bool isVero;
  final String? image;
  final String? imagePosition;
  final String? audio;
  final List<dynamic>? vocabulary;

  final String? userNote;

  final int giustoCount;
  final int sbagliatoCount;

  const McqQuestion({
    this.id = 0,
    required this.chapter,
    required this.chapterName,
    required this.italian,
    required this.bangla,
    required this.isVero,
    this.image,
    this.imagePosition,
    this.audio,
    this.vocabulary,
    this.userNote,
    this.giustoCount = 0,
    this.sbagliatoCount = 0,
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
    final rawImgPos = json['image_position'] ?? json['position'] ?? json['img_position'] ?? json['image_location'];

    final rawVocab = json['vocabulary'] ?? json['vocabulary_underlines'] ?? json['underlines'];
    List<dynamic>? parsedVocab;
    if (rawVocab is List) {
      parsedVocab = rawVocab;
    } else if (rawVocab is String && rawVocab.isNotEmpty) {
      try {
        parsedVocab = jsonDecode(rawVocab);
      } catch (_) {}
    }

    final rawUserNote = json['user_note'] ?? json['userNote'] ?? json['note_text'] ?? json['note'] ?? json['notes'];

    final int rawGiusto = json['giusto_count'] is int
        ? json['giusto_count']
        : int.tryParse(json['giusto_count']?.toString() ?? json['giustoCount']?.toString() ?? '0') ?? 0;
    final int rawSbagliato = json['sbagliato_count'] is int
        ? json['sbagliato_count']
        : int.tryParse(json['sbagliato_count']?.toString() ?? json['sbagliatoCount']?.toString() ?? '0') ?? 0;

    String? rawImage = (json['image'] ?? json['image_path'] ?? json['cover_image'] ?? json['image_url'] ?? json['img'] ?? json['photo'] ?? json['picture'] ?? json['page_image'] ?? json['thumbnail'])?.toString();

    if (rawImage == null || rawImage.trim().isEmpty || rawImage.trim().toLowerCase() == 'null' || rawImage.trim().toLowerCase() == 'undefined') {
      if (parsedVocab != null && parsedVocab.isNotEmpty) {
        for (var v in parsedVocab) {
          if (v is Map) {
            final vImg = (v['image'] ?? v['image_path'] ?? v['img'] ?? v['photo'] ?? v['image_url'])?.toString().trim();
            if (vImg != null && vImg.isNotEmpty && vImg.toLowerCase() != 'null' && vImg.toLowerCase() != 'undefined') {
              rawImage = vImg;
              break;
            }
          }
        }
      }
    }

    return McqQuestion(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      chapter: json['chapter_id'] is int ? json['chapter_id'] : int.tryParse(json['chapter_id']?.toString() ?? '1') ?? 1,
      chapterName: json['chapter_name']?.toString() ?? json['category_name']?.toString() ?? 'Capitolo 1',
      italian: json['italian']?.toString() ?? json['question']?.toString() ?? json['domanda'] ?? '',
      bangla: json['bangla']?.toString() ?? json['bn_question']?.toString() ?? json['bn_translation']?.toString() ?? json['traduzione'] ?? '',
      isVero: isVeroBool,
      image: rawImage,
      imagePosition: rawImgPos?.toString(),
      audio: rawAudio?.toString(),
      vocabulary: parsedVocab,
      userNote: rawUserNote?.toString(),
      giustoCount: rawGiusto,
      sbagliatoCount: rawSbagliato,
    );
  }

  McqQuestion copyWith({
    int? id,
    int? chapter,
    String? chapterName,
    String? italian,
    String? bangla,
    bool? isVero,
    String? image,
    String? imagePosition,
    String? audio,
    List<dynamic>? vocabulary,
    String? userNote,
    int? giustoCount,
    int? sbagliatoCount,
  }) {
    return McqQuestion(
      id: id ?? this.id,
      chapter: chapter ?? this.chapter,
      chapterName: chapterName ?? this.chapterName,
      italian: italian ?? this.italian,
      bangla: bangla ?? this.bangla,
      isVero: isVero ?? this.isVero,
      image: image ?? this.image,
      imagePosition: imagePosition ?? this.imagePosition,
      audio: audio ?? this.audio,
      vocabulary: vocabulary ?? this.vocabulary,
      userNote: userNote ?? this.userNote,
      giustoCount: giustoCount ?? this.giustoCount,
      sbagliatoCount: sbagliatoCount ?? this.sbagliatoCount,
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
      'imagePosition': imagePosition,
      'audio': audio,
      'vocabulary': vocabulary,
      'userNote': userNote,
      'giustoCount': giustoCount,
      'sbagliatoCount': sbagliatoCount,
    };
  }
}
