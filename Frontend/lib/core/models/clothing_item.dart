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
  final String? sizeLabel;
  final String? fitNotes;
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
    this.sizeLabel,
    this.fitNotes,
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
      sizeLabel: json['size_label'] as String?,
      fitNotes: json['fit_notes'] as String?,
      processingStatus: json['processing_status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  ClothingItem copyWith({
    String? id,
    String? name,
    String? type,
    String? rawUrl,
    String? processedUrl,
    Map<String, dynamic>? anchorPoints,
    double? detectionConfidence,
    String? color,
    String? pattern,
    String? style,
    String? subType,
    String? sizeLabel,
    String? fitNotes,
    String? processingStatus,
    DateTime? createdAt,
  }) {
    return ClothingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      rawUrl: rawUrl ?? this.rawUrl,
      processedUrl: processedUrl ?? this.processedUrl,
      anchorPoints: anchorPoints ?? this.anchorPoints,
      detectionConfidence: detectionConfidence ?? this.detectionConfidence,
      color: color ?? this.color,
      pattern: pattern ?? this.pattern,
      style: style ?? this.style,
      subType: subType ?? this.subType,
      sizeLabel: sizeLabel ?? this.sizeLabel,
      fitNotes: fitNotes ?? this.fitNotes,
      processingStatus: processingStatus ?? this.processingStatus,
      createdAt: createdAt ?? this.createdAt,
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
        'size_label': sizeLabel,
        'fit_notes': fitNotes,
        'processing_status': processingStatus,
        'created_at': createdAt.toIso8601String(),
      };
}
