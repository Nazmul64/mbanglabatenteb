import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/quotes_data.dart';
import '../theme.dart';

class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key});

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  String _selectedCategory = 'সব';
  String _searchQuery = '';
  final List<String> _categories = ['সব', 'অনুপ্রেরণা', 'জীবন দর্শন', 'নীতিশিক্ষা', 'ধর্মীয় ও নৈতিক', 'দেশপ্রেম'];

  List<BanglaQuote> get _filteredQuotes {
    return QuotesData.quotes.where((quote) {
      final matchesCategory = _selectedCategory == 'সব' || quote.category == _selectedCategory;
      final matchesSearch = quote.text.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          quote.author.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  Future<void> _copyQuote(BanglaQuote quote) async {
    final textToCopy = '"${quote.text}" - ${quote.author}';
    await Clipboard.setData(ClipboardData(text: textToCopy));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('উক্তিটি কপি করা হয়েছে! 📋'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Search Bar & Filter Chips
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E294B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade300,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'উক্তি বা লেখক খুঁজুন...',
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                    prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.cyan : Colors.blue),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Category Slider
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          cat,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: Colors.blue,
                        backgroundColor: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedCategory = cat;
                            });
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Quotes List
        Expanded(
          child: _filteredQuotes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_stories_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'কোনো উক্তি পাওয়া যায়নি!',
                        style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: _filteredQuotes.length,
                  itemBuilder: (context, index) {
                    final quote = _filteredQuotes[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildQuoteCard(quote, isDark),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildQuoteCard(BanglaQuote quote, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E294B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Category Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    quote.category,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Copy Action Icon
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => _copyQuote(quote),
                    icon: Icon(Icons.copy_rounded, size: 16, color: isDark ? Colors.cyan : Colors.blue),
                    tooltip: 'কপি করুন',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Quote content
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded, color: Colors.blue.withOpacity(0.3), size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    quote.text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Author
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                '- ${quote.author}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.cyan.shade400 : Colors.indigo.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
