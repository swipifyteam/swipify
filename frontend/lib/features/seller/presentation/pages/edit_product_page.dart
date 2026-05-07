// lib/features/seller/presentation/pages/edit_product_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/seller/service/seller_provider.dart';
import 'package:swipify/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:swipify/models/product_model.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';
import 'package:file_picker/file_picker.dart';

class EditProductPage extends StatefulWidget {
  final ProductModel product;
  const EditProductPage({super.key, required this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _descController;
  late TextEditingController _sizesController;
  late TextEditingController _colorsController;

  // Media State
  List<ProductMedia> _existingMedia = [];
  final List<XFile> _newImageFiles = [];
  XFile? _newVideoFile;
  VideoPlayerController? _videoController;
  
  bool _isUpdating = false;
  final ImagePicker _picker = ImagePicker();

  static const _categories = [
    'Electronics', 'Clothing', 'Footwear', 'Accessories',
    'Home & Living', 'Beauty', 'Sports',
  ];
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _priceController = TextEditingController(text: widget.product.price.toString());
    _stockController = TextEditingController(text: widget.product.stock.toString());
    _descController = TextEditingController(text: widget.product.description);
    _sizesController = TextEditingController(text: widget.product.sizes.join(', '));
    _colorsController = TextEditingController(text: widget.product.colors.join(', '));
    _selectedCategory = _categories.contains(widget.product.category) 
        ? widget.product.category 
        : _categories.first;
    
    // Copy existing media
    _existingMedia = List.from(widget.product.media);
  }

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

  // ── Media Methods ─────────────────────────────────────────────────────────

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() => _newImageFiles.addAll(picked));
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
      final pickedFile = XFile(file.path ?? '');
      setState(() {
        _newVideoFile = pickedFile;
        _videoController?.dispose();
        if (kIsWeb) {
          _videoController = VideoPlayerController.networkUrl(Uri.parse(file.path ?? ''))
            ..initialize().then((_) => setState(() {}));
        } else {
          _videoController = VideoPlayerController.file(File(file.path!))
            ..initialize().then((_) => setState(() {}));
        }
      });
    }
  }

  void _removeNewVideo() {
    setState(() {
      _newVideoFile = null;
      _videoController?.dispose();
      _videoController = null;
    });
  }

  // ── Submit Logic ──────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_existingMedia.isEmpty && _newImageFiles.isEmpty && _newVideoFile == null) {
      _showError('Please add at least one image or video.');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final sellerProvider = context.read<SellerProvider>();
    final userId = authProvider.user?.uid;
    if (userId == null) return;

    setState(() => _isUpdating = true);

    try {
      List<Map<String, dynamic>> finalMedia = _existingMedia.map((m) => m.toJson()).toList();

      // 1. Upload New Video if any
      if (_newVideoFile != null) {
        List<int> videoBytes;
        
        if (kIsWeb) {
          videoBytes = await _newVideoFile!.readAsBytes();
        } else {
          MediaInfo? info = await VideoCompress.compressVideo(
            _newVideoFile!.path,
            quality: VideoQuality.MediumQuality,
            deleteOrigin: false,
          );
          
          File videoToUpload = info?.file ?? File(_newVideoFile!.path);
          videoBytes = await videoToUpload.readAsBytes();
        }

        final videoData = await ApiService.uploadProductVideo(videoBytes, _newVideoFile!.name, userId);
        
        finalMedia.add({
          'type': 'video',
          'url': videoData['video_url'],
          'thumbnail_url': videoData['thumbnail_url'],
        });
      }

      // 2. Upload New Images if any
      for (var file in _newImageFiles) {
        final bytes = await file.readAsBytes();
        final url = await ApiService.uploadSellerDocument(
          userId, 'product_image', bytes, file.name, 'image/jpeg'
        );
        finalMedia.add({'type': 'image', 'url': url});
      }

      final data = {
        'name': _nameController.text.trim(),
        'category': _selectedCategory,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'stock': int.tryParse(_stockController.text) ?? 0,
        'description': _descController.text.trim(),
        'media': finalMedia,
        'sizes': _sizesController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        'colors': _colorsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      };

      final success = await sellerProvider.updateProduct(widget.product.id, data, userId);

      if (success && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Product updated successfully!')));
      }
    } catch (e) {
      if (mounted) _showError('Update failed: $e');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  // ── Build UI ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Product'), backgroundColor: SwipifyTheme.primaryColor, foregroundColor: Colors.white),
      body: _isUpdating
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Updating product...')],
            ))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  const Text('Product Media', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // Add buttons
                        _buildAddMediaButton(icon: Icons.add_a_photo, label: 'Add Images', onTap: _pickImages),
                        if (_newVideoFile == null && !_existingMedia.any((m) => m.type == 'video'))
                          _buildAddMediaButton(icon: Icons.video_call, label: 'Add Video', onTap: _pickVideo),

                        // Existing Media
                        ..._existingMedia.map((m) => _buildExistingMediaPreview(m)),
                        
                        // New Video
                        if (_newVideoFile != null) _buildNewVideoPreview(),

                        // New Images
                        ..._newImageFiles.map((f) => _buildNewImagePreview(f)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Standard Fields
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v!),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Price (₱)', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: TextFormField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Stock', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), alignLabelWithHint: true),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SwipifyTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Preview Widgets ───────────────────────────────────────────────────────

  Widget _buildAddMediaButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100, margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!, width: 2)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: SwipifyTheme.primaryColor), const SizedBox(height: 4), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))]),
      ),
    );
  }

  Widget _buildExistingMediaPreview(ProductMedia media) {
    return Container(
      width: 100, margin: const EdgeInsets.only(right: 12),
      child: Stack(children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(media.thumbnailUrl ?? media.url, width: 100, height: 120, fit: BoxFit.cover)),
        if (media.type == 'video') const Center(child: Icon(Icons.play_circle, color: Colors.white70, size: 30)),
        Positioned(top: 4, right: 4, child: GestureDetector(
          onTap: () => setState(() => _existingMedia.remove(media)),
          child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 16, color: Colors.white)),
        )),
      ]),
    );
  }

  Widget _buildNewImagePreview(XFile file) {
    return Container(
      width: 100, margin: const EdgeInsets.only(right: 12),
      child: Stack(children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: kIsWeb ? Image.network(file.path, width: 100, height: 120, fit: BoxFit.cover) : Image.file(File(file.path), width: 100, height: 120, fit: BoxFit.cover)),
        Positioned(top: 4, right: 4, child: GestureDetector(
          onTap: () => setState(() => _newImageFiles.remove(file)),
          child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 16, color: Colors.white)),
        )),
      ]),
    );
  }

  Widget _buildNewVideoPreview() {
    return Container(
      width: 100, margin: const EdgeInsets.only(right: 12),
      child: Stack(children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: Container(color: Colors.black12, child: _videoController?.value.isInitialized ?? false ? AspectRatio(aspectRatio: 100/120, child: VideoPlayer(_videoController!)) : null)),
        const Center(child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 30)),
        Positioned(top: 4, right: 4, child: GestureDetector(
          onTap: _removeNewVideo,
          child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 16, color: Colors.white)),
        )),
      ]),
    );
  }
}
