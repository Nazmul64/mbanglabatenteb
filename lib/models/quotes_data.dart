class BanglaQuote {
  final String text;
  final String author;
  final String category;

  const BanglaQuote({
    required this.text,
    required this.author,
    required this.category,
  });
}

class QuotesData {
  static const List<BanglaQuote> quotes = [
    BanglaQuote(
      text: "বিপত্তি যখন আসে তখন একা আসে না, দল বেঁধে আসে।",
      author: "রবীন্দ্রনাথ ঠাকুর",
      category: "জীবন দর্শন",
    ),
    BanglaQuote(
      text: "অন্যায় যে করে আর অন্যায় যে সহে, তব ঘৃণা তারে যেন তৃণসম দহে।",
      author: "রবীন্দ্রনাথ ঠাকুর",
      category: "নীতিশিক্ষা",
    ),
    BanglaQuote(
      text: "নদীর এপার কহে ছাড়িয়া নিশ্বাস, ওপারেতে সর্বসুখ আমার বিশ্বাস।",
      author: "রবীন্দ্রনাথ ঠাকুর",
      category: "জীবন দর্শন",
    ),
    BanglaQuote(
      text: "বল বীর, বল উন্নত মম শির! শির নেহারি' আমারি, নতশির ওই শিখর হিমাদ্রির!",
      author: "কাজী নজরুল ইসলাম",
      category: "অনুপ্রেরণা",
    ),
    BanglaQuote(
      text: "গাহি সাম্যের গান— যেখানে আসিয়া এক হয়ে গেছে সব বাধা-ব্যবধান।",
      author: "কাজী নজরুল ইসলাম",
      category: "সাম্যবাদ",
    ),
    BanglaQuote(
      text: "মানুষের মন বড়ই অদ্ভুত, কষ্টের কথা ভুলে যায় কিন্তু অপমানের কথা সহজে ভোলে না।",
      author: "হুমায়ুন আহমেদ",
      category: "মনস্তত্ত্ব",
    ),
    BanglaQuote(
      text: "কিছু কিছু মানুষ আসলেই ভাগ্য গড়ে জন্মায়, আবার কেউ কেউ ভাগ্য গড়ে নেয় নিজের পরিশ্রমে।",
      author: "হুমায়ুন আহমেদ",
      category: "অনুপ্রেরণা",
    ),
    BanglaQuote(
      text: "পৃথিবীতে সবথেকে বড় সত্যি হচ্ছে মৃত্যু, আর সবথেকে বড় মিথ্যা হচ্ছে বেঁচে থাকার অভিনয়।",
      author: "হুমায়ুন আহমেদ",
      category: "জীবন দর্শন",
    ),
    BanglaQuote(
      text: "আবার আসিব ফিরে ধানসিঁড়িটির তীরে— এই বাংলায় হয়তো মানুষ নয়— হয়তো বা শঙ্খচিল শালিখের বেশে।",
      author: "জীবনানন্দ দাশ",
      category: "দেশপ্রেম",
    ),
    BanglaQuote(
      text: "স্বপ্ন সেটা নয় যা আমরা ঘুমিয়ে দেখি, স্বপ্ন সেটাই যা আমাদের ঘুমাতে দেয় না।",
      author: "এ পি জে আব্দুল কালাম",
      category: "অনুপ্রেরণা",
    ),
    BanglaQuote(
      text: "যদি তুমি সূর্যের মতো উজ্জ্বল হতে চাও, তবে প্রথমে সূর্যের মতো পুড়তে শেখো।",
      author: "এ পি জে আব্দুল কালাম",
      category: "অনুপ্রেরণা",
    ),
    BanglaQuote(
      text: "কঠিন সময়ে ধৈর্য ধরা হচ্ছে সফলতার অন্যতম বড় চাবিকাঠি।",
      author: "হযরত আলী (রাঃ)",
      category: "ধর্মীয় ও নৈতিক",
    ),
    BanglaQuote(
      text: "লোভ মানুষকে ধ্বংসের পথে নিয়ে যায়, আর সন্তুষ্টি মানুষকে শান্তি দেয়।",
      author: "হযরত আলী (রাঃ)",
      category: "ধর্মীয় ও নৈতিক",
    ),
  ];

  static BanglaQuote getRandomQuote() {
    final list = List<BanglaQuote>.from(quotes);
    list.shuffle();
    return list.first;
  }
}
