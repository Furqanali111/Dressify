import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../models/clothing_item.dart';
import '../services/glb_cache_service.dart';

/// Renders a 3D Garment Mesh using `model_viewer_plus`.
/// It manages the local caching of the GLB file.
class GarmentMeshRenderer extends StatefulWidget {
  const GarmentMeshRenderer({
    super.key,
    required this.item,
  });

  final ClothingItem item;

  @override
  State<GarmentMeshRenderer> createState() => _GarmentMeshRendererState();
}

class _GarmentMeshRendererState extends State<GarmentMeshRenderer> {
  String? _localMeshPath;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadMesh();
  }

  @override
  void didUpdateWidget(GarmentMeshRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.glbMeshUrl != widget.item.glbMeshUrl) {
      _loadMesh();
    }
  }

  Future<void> _loadMesh() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final String? remoteUrl = widget.item.glbMeshUrl;
    if (remoteUrl == null || remoteUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    final String? path = await GlbCacheService().getMeshPath(widget.item.id, remoteUrl);
    
    if (mounted) {
      setState(() {
        _localMeshPath = path;
        _isLoading = false;
        _hasError = path == null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_hasError || _localMeshPath == null) {
      // Fallback if mesh fails to load
      return const Center(
        child: Icon(Icons.error_outline, color: Colors.white, size: 32),
      );
    }

    // model_viewer_plus requires a file:// URI for local files on mobile
    final String src = 'file://$_localMeshPath';

    // Wrap in IgnorePointer so the WebView doesn't swallow pinch-to-zoom gestures 
    // that are meant for the Try-On screen's interactive overlay.
    return IgnorePointer(
      child: ModelViewer(
        src: src,
        backgroundColor: Colors.transparent,
        cameraControls: false, // Disable touch manipulation so it stays locked to body
        autoRotate: false,
        interactionPrompt: InteractionPrompt.none,
        disableZoom: true,
        disablePan: true,
        disableTap: true,
        shadowIntensity: 0, // Shadows might clash with camera background
        // To get the best transparency and blending:
        environmentImage: '', 
      ),
    );
  }
}
