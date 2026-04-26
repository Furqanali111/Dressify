class ClothingItem {
  final String id;
  final String name;
  final String type;
  final String rawUrl;
  final String processedUrl;
  final Map<String, dynamic>? anchorPoints;
  final double? detectionConfidence;
  final String? color;
  final String? pattern;
  final String? style;
  final String? subType;
  final String processingStatus;
  final DateTime createdAt;

  const ClothingItem({
    required this.id,
    required this.name,
    required this.type,
    this.rawUrl = '',
    this.processedUrl = '',
    this.anchorPoints,
    this.detectionConfidence,
    this.color,
    this.pattern,
    this.style,
    this.subType,
    required this.processingStatus,
    required this.createdAt,
  });

  factory ClothingItem.fromJson(Map<String, dynamic> json) {
    return ClothingItem(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      rawUrl: json['raw_url'] as String? ?? '',
      processedUrl: json['processed_url'] as String? ?? '',
      anchorPoints: json['anchor_points'] as Map<String, dynamic>?,
      detectionConfidence: (json['detection_confidence'] as num?)?.toDouble(),
      color: json['color'] as String?,
      pattern: json['pattern'] as String?,
      style: json['style'] as String?,
      subType: json['sub_type'] as String?,
      processingStatus: json['processing_status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'raw_url': rawUrl,
        'processed_url': processedUrl,
        'anchor_points': anchorPoints,
        'detection_confidence': detectionConfidence,
        'color': color,
        'pattern': pattern,
        'style': style,
        'sub_type': subType,
        'processing_status': processingStatus,
        'created_at': createdAt.toIso8601String(),
      };
}
