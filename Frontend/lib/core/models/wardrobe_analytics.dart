class WornItem {
  final String id;
  final String name;
  final String type;
  final int wearCount;
  final String processedUrl;

  const WornItem({
    required this.id,
    required this.name,
    required this.type,
    required this.wearCount,
    this.processedUrl = '',
  });

  factory WornItem.fromJson(Map<String, dynamic> json) => WornItem(
        id:           json['id'] as String,
        name:         json['name'] as String,
        type:         json['type'] as String,
        wearCount:    json['wear_count'] as int,
        processedUrl: json['processed_url'] as String? ?? '',
      );
}

class WeeklyFrequency {
  final String week;
  final int count;
  const WeeklyFrequency({required this.week, required this.count});

  factory WeeklyFrequency.fromJson(Map<String, dynamic> json) => WeeklyFrequency(
        week:  json['week'] as String,
        count: json['count'] as int,
      );
}

class WardrobeAnalytics {
  final int totalItems;
  final int totalOutfits;
  final List<WornItem> mostWorn;
  final List<WornItem> underutilised;
  final Map<String, int> colorDistribution;
  final Map<String, int> styleBreakdown;
  final List<WeeklyFrequency> outfitFrequency;

  const WardrobeAnalytics({
    required this.totalItems,
    required this.totalOutfits,
    required this.mostWorn,
    required this.underutilised,
    required this.colorDistribution,
    required this.styleBreakdown,
    required this.outfitFrequency,
  });

  factory WardrobeAnalytics.fromJson(Map<String, dynamic> json) => WardrobeAnalytics(
        totalItems:    json['total_items'] as int,
        totalOutfits:  json['total_outfits'] as int,
        mostWorn:      (json['most_worn'] as List<dynamic>)
            .map((e) => WornItem.fromJson(e as Map<String, dynamic>)).toList(),
        underutilised: (json['underutilised'] as List<dynamic>)
            .map((e) => WornItem.fromJson(e as Map<String, dynamic>)).toList(),
        colorDistribution: Map<String, int>.from(json['color_distribution'] as Map),
        styleBreakdown:    Map<String, int>.from(json['style_breakdown'] as Map),
        outfitFrequency:   (json['outfit_frequency'] as List<dynamic>)
            .map((e) => WeeklyFrequency.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
