import '../services/api_service.dart';

class LivePassedExamItem {
  final int id;
  final String nome;
  final String motorizzazione;
  final String examDate;
  final String status;
  final int corrette;
  final int errori;
  final int nonRisposte;
  final int totale;
  final String? pdfUrl;

  LivePassedExamItem({
    required this.id,
    required this.nome,
    required this.motorizzazione,
    required this.examDate,
    this.status = 'completato',
    this.corrette = 28,
    this.errori = 2,
    this.nonRisposte = 0,
    this.totale = 30,
    this.pdfUrl,
  });

  factory LivePassedExamItem.fromJson(Map<String, dynamic> json) {
    String? rawPdf = json['pdf_url']?.toString() ?? json['pdf_path']?.toString();
    String? formattedPdf;
    if (rawPdf != null && rawPdf.trim().isNotEmpty) {
      formattedPdf = ApiService.formatImageUrl(rawPdf);
    }

    return LivePassedExamItem(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      nome: (json['nome'] ?? json['student_name'] ?? 'Candidato').toString(),
      motorizzazione: (json['motorizzazione'] ?? 'Motorizzazione Civile').toString(),
      examDate: (json['exam_date'] ?? json['date'] ?? '').toString(),
      status: (json['status'] ?? 'completato').toString(),
      corrette: json['corrette'] is int
          ? json['corrette']
          : int.tryParse('${json['corrette']}') ?? (json['correct_count'] is int ? json['correct_count'] : 28),
      errori: json['errori'] is int
          ? json['errori']
          : int.tryParse('${json['errori']}') ?? (json['wrong_count'] is int ? json['wrong_count'] : 2),
      nonRisposte: json['non_risposte'] is int
          ? json['non_risposte']
          : int.tryParse('${json['non_risposte']}') ?? (json['unanswered_count'] is int ? json['unanswered_count'] : 0),
      totale: json['totale'] is int
          ? json['totale']
          : int.tryParse('${json['totale']}') ?? (json['total_count'] is int ? json['total_count'] : 30),
      pdfUrl: formattedPdf,
    );
  }
}
