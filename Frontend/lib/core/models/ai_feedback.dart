class Suggestion {
  final String category;
  final String title;
  final String detail;

  const Suggestion({
    required this.category,
    required this.title,
    required this.detail,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      category: json['category'] as String,
      title: json['title'] as String,
      detail: json['detail'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'title': title,
        'detail': detail,
      };
}

class AiFeedback {
  final String id;
  final String outfitId;
  final double score;
  final String verdict;
  final List<Suggestion> suggestions;
  final DateTime createdAt;

  const AiFeedback({
    required this.id,
    required this.outfitId,
    required this.score,
    required this.verdict,
    this.suggestions = const [],
    required this.createdAt,
  });

  factory AiFeedback.fromJson(Map<String, dynamic> json) {
    return AiFeedback(
      id: json['id'] as String,
      outfitId: json['outfit_id'] as String,
      score: (json['score'] as num).toDouble(),
      verdict: json['verdict'] as String,
      suggestions: (json['suggestions'] as List<dynamic>?)
              ?.map((e) => Suggestion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'outfit_id': outfitId,
        'score': score,
        'verdict': verdict,
        'suggestions': suggestions.map((e) => e.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };
}
