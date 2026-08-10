import 'mcq_question.dart';

class QuestionDatabase {
  static final List<McqQuestion> _allQuestions = [];

  // Glossary map for auto-generating vocabulary help
  static const Map<String, String> globalGlossary = {
    'strada': 'রাস্তা / রোড',
    'carreggiata': 'মূল রাস্তা / ক্যারেজওয়ে',
    'corsia': 'লেন',
    'banchina': 'রাস্তার কিনারা / ব্যাংকিনা',
    'marciapiede': 'ফুটপাথ',
    'pedoni': 'পথচারী',
    'veicolo': 'যানবাহন / গাড়ি',
    'veicoli': 'যানবাহনগুলো / গাড়িগুলো',
    'conducente': 'চালক / ড্রাইভার',
    'velocità': 'গতি / স্পিড',
    'sosta': 'পার্কিং করা',
    'fermata': 'ক্ষণিকের থামা / স্টপ',
    'sorpasso': 'ওভারটেক করা',
    'vietato': 'নিষেধ / বেআইনি',
    'consentito': 'অনুমোদিত / বৈধ',
    'obbligo': 'বাধ্যতামূলক',
    'pericolo': 'বিপদ',
    'limite': 'সীমা / লিমিট',
    'sicurezza': 'নিরাপত্তা',
    'distanza': 'দূরত্ব',
    'incrocio': 'মোড় / চৌরাস্তা',
    'precedenza': 'অগ্রাধিকার / আগে যাওয়ার সুযোগ',
    'destra': 'ডানদিক',
    'sinistra': 'বামদিক',
    'freni': 'ব্রেকসমূহ',
    'pneumatici': 'টায়ারসমূহ',
    'motore': 'ইঞ্জিন',
    'luci': 'লাইটসমূহ',
    'nebbia': 'কুয়াশা',
    'ghiaccio': 'বরফ / তুষারপাত',
    'pioggia': 'বৃষ্টি',
    'autostrada': 'হাইওয়ে / এক্সপ্রেসওয়ে',
    'passaggio': 'ক্রসিং / পথ',
    'livello': 'লেভেল',
    'segnali': 'সংকেতসমূহ',
    'segnaletica': 'রোড সাইন / চিহ্ন',
    'continua': 'অবিচ্ছিন্ন / টানা',
    'discontinua': 'বিচ্ছিন্ন / ভাঙা',
    'doppio': 'দ্বিগুণ / উভয়',
    'senso': 'দিক / অভিমুখ',
    'unico': 'একমুখী',
    'arrestarsi': 'থামা',
    'guidare': 'ড্রাইভ করা / চালানো',
    'patente': 'ড্রাইভিং লাইসেন্স',
    'cintura': 'বেল্ট / সিটবেল্ট',
    'casco': 'হেলমেট',
    'animali': 'পশু / জানোয়ার',
    'tenere': 'রাখা / বজায় রাখা',
    'vicino': 'কাছে / নিকটে',
    'margine': 'প্রান্ত / কিনারা',
    'destro': 'ডানদিক',
  };

  static void initialize() {
    // Dynamic database-driven - no hardcoded questions initialized here
  }

  static List<McqQuestion> getExamQuestions() {
    return List.from(_allQuestions);
  }

  static List<McqQuestion> getQuestionsForChapter(int chapterNum) {
    return _allQuestions.where((q) => q.chapter == chapterNum).toList();
  }
}
