/// A single AI-generated interview question, grouped by [category] for
/// display (e.g. "Behavioral", "Technical", "Role-specific").
class InterviewQuestion {
  final String question;
  final String category;
  final String answerTip;

  InterviewQuestion({
    required this.question,
    required this.category,
    required this.answerTip,
  });

  factory InterviewQuestion.fromJson(Map<String, dynamic> json) => InterviewQuestion(
        question: json['question'] ?? '',
        category: json['category'] ?? 'General',
        answerTip: json['answerTip'] ?? '',
      );
}
