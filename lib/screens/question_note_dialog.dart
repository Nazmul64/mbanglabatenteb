import 'package:flutter/material.dart';

class QuestionNoteDialog extends StatefulWidget {
  final String questionId;
  final String initialNote;
  final Function(String) onSave;

  const QuestionNoteDialog({
    super.key,
    required this.questionId,
    required this.initialNote,
    required this.onSave,
  });

  @override
  State<QuestionNoteDialog> createState() => _QuestionNoteDialogState();
}

class _QuestionNoteDialogState extends State<QuestionNoteDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      title: Row(
        children: const [
          Icon(Icons.edit_note_rounded, color: Color(0xFF4CAF50), size: 24),
          SizedBox(width: 8),
          Text(
            'প্রশ্ন নোট (Question Note)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: TextField(
        controller: _controller,
        maxLines: 5,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'আপনার ব্যক্তিগত নোট এখানে লিখুন...',
          hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('বাতিল', style: TextStyle(color: isDark ? Colors.white60 : Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            widget.onSave(_controller.text.trim());
            Navigator.pop(context);
          },
          child: const Text('সেভ করুন', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
