// lib/features/seller/presentation/pages/edit_product_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/seller/service/seller_provider.dart';
import 'package:swipify/models/product_model.dart';
import 'package:swipify/services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:swipify/features/seller/presentation/widgets/media_preview_widget.dart';

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
  final List<PlatformFile> _newMedia = [];
  
  bool _isUpdating = false;

  static const _categories = [
    'Electronics', 'Clothing', 'Footwear', 'Accessories',
    'Home & Living', 'Beauty', 'Sports',
  ];
  late String _selectedCategory;
  
  Null get _videoController => null;
  
  Null get _newVideoFile => null;

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
    // ignore: dead_code
    _videoController?.dispose();
    super.dispose();
  }

  // ── Media Methods ─────────────────────────────────────────────────────────

  Future<void> _pickMedia() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'avi'],
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _newMedia.addAll(result.files);
      });
    }
  }

  void _removeNewMedia(int index) {
    setState(() {
      _newMedia.removeAt(index);
    });
  }

  bool _isVideo(PlatformFile file) {
    final ext = file.extension?.toLowerCase() ?? '';
    return ['mp4', 'mov', 'avi', 'mkv', 'wmv'].contains(ext);
  }

  // ── Submit Logic ──────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_existingMedia.isEmpty && _newMedia.isEmpty && _newVideoFile == null) {
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

      // 1. Upload New Media
      for (var file in _newMedia) {
        final isVid = _isVideo(file);
        final fileName = file.name;
        final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);

        if (bytes == null) continue;

        if (isVid) {
          final videoData = await ApiService.uploadProductVideo(bytes, fileName, userId);
          finalMedia.add({
            'type': 'video',
            'url': videoData['video_url'],
            'thumbnail_url': videoData['thumbnail_url'],
          });
        } else {
          final url = await ApiService.uploadProductImage(bytes, fileName, userId);
          finalMedia.add({'type': 'image', 'url': url});
        }
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
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _existingMedia.length + _newMedia.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildAddMediaButton(
                            icon: Icons.add_to_photos,
                            label: 'Add Media',
                            onTap: _pickMedia,
                          );
                        }
                        
                        int realIndex = index - 1;
                        if (realIndex < _existingMedia.length) {
                          return _buildExistingMediaPreview(_existingMedia[realIndex]);
                        } else {
                          int newMediaIndex = realIndex - _existingMedia.length;
                          return _buildNewMediaPreview(_newMedia[newMediaIndex], newMediaIndex);
                        }
                      },
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
        ClipRRect(
          borderRadius: BorderRadius.circular(12), 
          child: MediaPreviewWidget(url: media.url, isVideo: media.type == 'video'),
        ),
        if (media.type == 'video') const Center(child: Icon(Icons.play_circle, color: Colors.white70, size: 30)),
        Positioned(top: 4, right: 4, child: GestureDetector(
          onTap: () => setState(() => _existingMedia.remove(media)),
          child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 16, color: Colors.white)),
        )),
      ]),
    );
  }

  Widget _buildNewMediaPreview(PlatformFile file, int index) {
    final isVid = _isVideo(file);
    return Container(
      width: 100, margin: const EdgeInsets.only(right: 12),
      child: Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12), 
          child: Container(
            color: Colors.black12,
            child: MediaPreviewWidget(
              path: file.path,
              bytes: file.bytes,
              isVideo: isVid,
            ),
          ),
        ),
        if (isVid) const Center(child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 30)),
        Positioned(top: 4, right: 4, child: GestureDetector(
          onTap: () => _removeNewMedia(index),
          child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 16, color: Colors.white)),
        )),
      ]),
    );
  }
}
