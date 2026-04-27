import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/clothing_item.dart';

/// Holds the clothing items currently selected for live camera try-on.
///
/// Set this before navigating to the Camera tab to pre-select items.
/// The Camera tab screen watches this and renders the garment overlay.
final StateProvider<List<ClothingItem>> cameraGarmentsProvider =
    StateProvider<List<ClothingItem>>((_) => const <ClothingItem>[]);
