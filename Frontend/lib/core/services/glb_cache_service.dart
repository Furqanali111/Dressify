import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// A service to download and cache GLB meshes locally.
/// This prevents massive redownloads of 3D models every time the user tries on an outfit.
class GlbCacheService {
  static final GlbCacheService _instance = GlbCacheService._internal();
  factory GlbCacheService() => _instance;
  GlbCacheService._internal();

  final Dio _dio = Dio();
  
  /// In-flight downloads to prevent duplicate concurrent network requests.
  final Map<String, Future<String?>> _activeDownloads = <String, Future<String?>>{};

  /// The local directory where meshes are stored.
  Directory? _cacheDir;

  Future<void> _initCacheDir() async {
    if (_cacheDir != null) return;
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDocDir.path}/meshes');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
  }

  /// Checks if the mesh is cached. If not, downloads it.
  /// Returns the local absolute file path.
  Future<String?> getMeshPath(String itemId, String remoteUrl) async {
    if (remoteUrl.isEmpty) return null;
    
    await _initCacheDir();
    final String localPath = '${_cacheDir!.path}/$itemId.glb';
    final File localFile = File(localPath);

    if (await localFile.exists()) {
      // Mesh is already cached!
      return localPath;
    }

    // If a download is already in progress, wait for it instead of starting a new one
    if (_activeDownloads.containsKey(itemId)) {
      return _activeDownloads[itemId];
    }

    // Mesh not found locally, start a new download
    final Future<String?> downloadFuture = _downloadMesh(itemId, remoteUrl, localPath, localFile);
    _activeDownloads[itemId] = downloadFuture;
    
    final String? result = await downloadFuture;
    _activeDownloads.remove(itemId);
    return result;
  }

  Future<String?> _downloadMesh(String itemId, String remoteUrl, String localPath, File localFile) async {
    try {
      debugPrint('Downloading GLB mesh for $itemId...');
      await _dio.download(remoteUrl, localPath);
      debugPrint('Downloaded GLB mesh to $localPath');
      return localPath;
    } catch (e) {
      debugPrint('Failed to download GLB mesh for $itemId: $e');
      // Clean up partial file if download failed
      if (await localFile.exists()) {
        await localFile.delete();
      }
      return null;
    }
  }

  /// Deletes a cached mesh for a specific item (e.g., when the item is deleted from the wardrobe).
  Future<void> evict(String itemId) async {
    await _initCacheDir();
    final String localPath = '${_cacheDir!.path}/$itemId.glb';
    final File localFile = File(localPath);
    if (await localFile.exists()) {
      await localFile.delete();
      debugPrint('Evicted GLB mesh for $itemId');
    }
  }

  /// Clears the entire mesh cache (e.g., on sign-out).
  Future<void> clearAll() async {
    await _initCacheDir();
    if (await _cacheDir!.exists()) {
      await _cacheDir!.delete(recursive: true);
      _cacheDir = null;
      debugPrint('Cleared all cached GLB meshes');
    }
  }
}
