// lib/features/seller/presentation/pages/add_product_page.dart
// Add Product page — fully delegates to SellerProductsProvider (MCP/API layer).
// Gets seller UID from AuthProvider — no direct FirebaseAuth calls in UI.
// Debug logs follow [PRODUCT] and [API] conventions.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/seller/service/seller_provider.dart';
import 'package:swipify/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';
import 'package:file_picker/file_picker.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _descController = TextEditingController();
  final _sizesController = TextEditingController();
  final _colorsController = TextEditingController();

  List<XFile> _imageFiles = [];
  XFile? _videoFile;
  VideoPlayerController? _videoController;
  
  bool _isUploading = false;
  String _uploadStatus = 'Publishing product…';
  final ImagePicker _picker = ImagePicker();

  static const _categories = [
    'Electronics', 'Clothing', 'Footwear', 'Accessories',
    'Home & Living', 'Beauty', 'Sports',
  ];
  String _selectedCategory = 'Electronics';

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descController.dispose();
    _sizesController.dispose();
    _colorsController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // ── Media Pickers ───────────────────────────────────────────────────────────

  Future<void> _pickImages() async {
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      debugPrint('[PRODUCT] Images selected: ${pickedFiles.length}');
      setState(() {
        _imageFiles = pickedFiles;
      });
    }
  }

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mov', 'avi', 'mkv', 'wmv'],
      allowMultiple: false,
    );
    
    if (result != null) {
      final file = result.files.single;
      final pickedFile = XFile(file.path ?? ''); // path is null on web
      debugPrint('[PRODUCT] Video selected: ${file.name}');
      
      // Dispose old controller
      await _videoController?.dispose();
      
      if (kIsWeb) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(file.path ?? ''))
          ..initialize().then((_) => setState(() {}));
      } else {
        _videoController = VideoPlayerController.file(File(file.path!))
          ..initialize().then((_) => setState(() {}));
      }
      
      setState(() {
        _videoFile = pickedFile;
        // Store bytes for web if path is not usable
      });
    }
  }

  Future<void> _removeVideo() async {
    await _videoController?.dispose();
    setState(() {
      _videoFile = null;
      _videoController = null;
    });
  }

  // ── Submit Form ─────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      debugPrint('[PRODUCT] Validation failed — aborting submit');
      return;
    }

    if (_imageFiles.isEmpty && _videoFile == null) {
      _showError('Please select at least one image or video.');
      return;
    }

    final authProvider = context.read<AuthProvider>();

    final userId = authProvider.user?.uid;
    if (userId == null) {
      _showError('Please log in to add a product.');
      return;
    }

    setState(() => _isUploading = true);
    
    try {
      List<Map<String, dynamic>> mediaList = [];
      String? globalThumbnailUrl;

      // ── Step 1: Upload Video if exists ────────────────────────────────────
      if (_videoFile != null) {
        List<int> videoBytes;
        
        if (kIsWeb) {
          setState(() => _uploadStatus = 'Reading video data…');
          videoBytes = await _videoFile!.readAsBytes();
        } else {
          setState(() => _uploadStatus = 'Compressing video…');
          debugPrint('[VIDEO] Compressing: ${_videoFile!.name}');
          
          MediaInfo? info = await VideoCompress.compressVideo(
            _videoFile!.path,
            quality: VideoQuality.MediumQuality,
            deleteOrigin: false,
            includeAudio: true,
          );

          if (info == null || info.file == null) {
            throw Exception('Video compression failed');
          }
          
          debugPrint('[VIDEO] Compressed size: ${info.file!.lengthSync()}');
          videoBytes = await info.file!.readAsBytes();
        }

        setState(() => _uploadStatus = 'Uploading video…');
        final uploadResult = await ApiService.uploadProductVideo(
          videoBytes,
          'vid_${_videoFile!.name}',
          userId,
        );

        mediaList.add({
          'type': 'video',
          'url': uploadResult['video_url'],
          'thumbnail_url': uploadResult['thumbnail_url'],
        });
        
        globalThumbnailUrl = uploadResult['thumbnail_url'];
        debugPrint('[VIDEO] Uploaded: ${uploadResult['video_url']}');
      }

      // ── Step 2: Upload Images ─────────────────────────────────────────────
      int currentImg = 1;
      for (var file in _imageFiles) {
        setState(() => _uploadStatus = 'Uploading image $currentImg/${_imageFiles.length}…');
        final bytes = await file.readAsBytes();
        final imageUrl = await ApiService.uploadProductImage(
          bytes,
          file.name,
          userId,
        );
        mediaList.add({
          'type': 'image',
          'url': imageUrl,
        });
        
        // Use first image as thumbnail if no video thumbnail
        globalThumbnailUrl ??= imageUrl;
        currentImg++;
      }

      // ── Step 3: Create Product ────────────────────────────────────────────
      setState(() => _uploadStatus = 'Saving product details…');
      
      final data = {
        'name': _nameController.text.trim(),
        'category': _selectedCategory,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'stock': int.tryParse(_stockController.text) ?? 0,
        'description': _descController.text.trim(),
        'media': mediaList,
        'thumbnail_url': globalThumbnailUrl,
        'image_count': _imageFiles.length,
        'video_count': _videoFile != null ? 1 : 0,
        'sizes': _sizesController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'colors': _colorsController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      };

      final provider = context.read<SellerProvider>();
      final success = await provider.addProduct(data, userId);

      if (success && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Product published successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted) {
        throw Exception(provider.error ?? 'Failed to add product');
      }
    } catch (e) {
      debugPrint('[PRODUCT] Error during submission: $e');
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Product'),
        backgroundColor: SwipifyTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isUploading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: SwipifyTheme.primaryColor),
                  const SizedBox(height: 16),
                  Text(_uploadStatus, style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  // ── Media Picker ─────────────────────────────────────────
                  const Text('Product Media', 
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  // Mixed Gallery Preview
                  SizedBox(
                    height: 120,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // Add Image Button
                        _buildAddMediaButton(
                          icon: Icons.add_a_photo,
                          label: 'Add Images',
                          onTap: _pickImages,
                        ),
                        const SizedBox(width: 12),
                        
                        // Add Video Button
                        if (_videoFile == null)
                          _buildAddMediaButton(
                            icon: Icons.video_call,
                            label: 'Add Video',
                            onTap: _pickVideo,
                          ),
                        
                        // Video Preview
                        if (_videoFile != null)
                          _buildVideoPreview(),
                          
                        // Image Previews
                        ..._imageFiles.map((file) => _buildImagePreview(file)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Product Name ─────────────────────────────────────────
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Product Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Please enter a product name' : null,
                  ),

                  const SizedBox(height: 16),

                  // ── Category ─────────────────────────────────────────────
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v!),
                  ),

                  const SizedBox(height: 16),

                  // ── Sizes ────────────────────────────────────────────────
                  TextFormField(
                    controller: _sizesController,
                    decoration: const InputDecoration(
                      labelText: 'Sizes (comma separated, e.g. S,M,L)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Colors ───────────────────────────────────────────────
                  TextFormField(
                    controller: _colorsController,
                    decoration: const InputDecoration(
                      labelText: 'Colors (comma separated, e.g. Red,Blue)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Price + Stock ────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Price',
                            prefixText: '₱ ',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Enter price' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Stock Quantity',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Enter stock' : null,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Description ──────────────────────────────────────────
                  TextFormField(
                    controller: _descController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Product Description',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Please enter a description' : null,
                  ),

                  const SizedBox(height: 32),

                  // ── Submit ───────────────────────────────────────────────
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SwipifyTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Publish Product',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  Widget _buildAddMediaButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: SwipifyTheme.primaryColor),
            const SizedBox(height: 4),
            Text(label, 
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(XFile file) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: kIsWeb
                ? Image.network(file.path, width: 100, height: 120, fit: BoxFit.cover)
                : Image.file(File(file.path), width: 100, height: 120, fit: BoxFit.cover),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => setState(() => _imageFiles.remove(file)),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 100/120,
              child: _videoController?.value.isInitialized ?? false
                  ? VideoPlayer(_videoController!)
                  : Container(color: Colors.black12),
            ),
          ),
          const Center(child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 30)),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: _removeVideo,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
              child: const Text('VIDEO', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
