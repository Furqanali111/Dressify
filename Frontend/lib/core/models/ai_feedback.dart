class AiSuggestion {
  final String category;
  final String title;
  final String detail;

  const AiSuggestion({
    required this.category,
    required this.title,
    required this.detail,
  });

  factory AiSuggestion.fromJson(Map<String, dynamic> json) {
    return AiSuggestion(
      category: json['category'] as String,
      title: json['title'] as String,
      detail: json['detail'] as String,
    );
  }
}

class AiFeedbackResponse {
  final String? id;
  final String? outfitId;
  final double score;
  final String verdict;
  final List<AiSuggestion> suggestions;
  final DateTime? createdAt;

  const AiFeedbackResponse({
    this.id,
    this.outfitId,
    required this.score,
    required this.verdict,
    required this.suggestions,
    this.createdAt,
  });

  factory AiFeedbackResponse.fromJson(Map<String, dynamic> json) {
    return AiFeedbackResponse(
      id: json['id'] as String?,
      outfitId: json['outfit_id'] as String?,
      score: (json['score'] as num).toDouble(),
      verdict: json['verdict'] as String,
      suggestions: (json['suggestions'] as List<dynamic>)
          .map((e) => AiSuggestion.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
    );
  }
}
