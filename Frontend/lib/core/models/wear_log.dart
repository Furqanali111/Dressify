import 'package:equatable/equatable.dart';

class WearLog extends Equatable {
  const WearLog({
    required this.id,
    required this.userId,
    this.outfitId,
    this.clothingItemIds,
    required this.loggedAt,
  });

  final String id;
  final String userId;
  final String? outfitId;
  final List<String>? clothingItemIds;
  final DateTime loggedAt;

  factory WearLog.fromJson(Map<String, dynamic> json) => WearLog(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    outfitId: json['outfit_id'] as String?,
    clothingItemIds: (json['clothing_item_ids'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList(),
    loggedAt:
        DateTime.tryParse(json['logged_at'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'outfit_id': outfitId,
    'clothing_item_ids': clothingItemIds,
    'logged_at': loggedAt.toUtc().toIso8601String(),
  };

  @override
  List<Object?> get props => [id, userId, outfitId, clothingItemIds, loggedAt];
}
