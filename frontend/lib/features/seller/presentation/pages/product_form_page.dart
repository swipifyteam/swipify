import 'package:swipify/core/utils/media_validation_service.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:swipify/models/product_model.dart';
import 'package:swipify/services/api_service.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/seller/service/seller_products_provider.dart';
import 'package:swipify/core/utils/responsive_helper.dart';
import 'package:swipify/features/seller/presentation/widgets/media_preview_widget.dart';

// --- Theme Constants (Synced with SellerDashboard) ---
const _kPrimary = Color(0xFF36454F);
const _kAccent = Color(0xFFE97B4A);
const _kSurface = Color(0xFFF4F6F8);
const _kCard = Colors.white;
const _kBorder = Color(0xFFE0E4E9);
const _kTextPrimary = Color(0xFF1A2332);
const _kTextSecondary = Color(0xFF6B7A8D);
const _kGreen = Color(0xFF27AE60);
const _kRed = Color(0xFFE74C3C);

class ProductFormPage extends StatefulWidget {
  final ProductModel? product;
  const ProductFormPage({super.key, this.product});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _descCtrl;

  List<String> _images = []; // Existing URLs (for edit mode)
  final List<PlatformFile> _newMedia = []; // Newly picked files
  String _category = '';
  bool _isPublished = true;
  bool _isSaving = false;
  List<String> _categories = [];

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl  = TextEditingController(text: p?.name ?? '');
    _priceCtrl = TextEditingController(text: p?.price.toString() ?? '');
    _stockCtrl = TextEditingController(text: p?.stock.toString() ?? '');
    _descCtrl  = TextEditingController(text: p?.description ?? '');
    _images    = List<String>.from(p?.images ?? []);
    _category  = p?.category ?? '';
    _isPublished = p?.isPublished ?? true;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ApiService.getCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Media Picking ────────────────────────────────────────────────────────────
  Future<void> _pickMedia(bool isVideo) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: isVideo 
          ? MediaValidationService.allowedVideoExtensions 
          : MediaValidationService.allowedImageExtensions,
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        // Validation using MediaValidationService
        final List<PlatformFile> validFiles = [];
        final List<String> errorMessages = [];

        for (final file in result.files) {
          final error = MediaValidationService.validateFile(file);
          if (error == null) {
            validFiles.add(file);
          } else {
            errorMessages.add('${file.name}: $error');
          }
        }

        if (errorMessages.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessages.join('\n')),
                backgroundColor: _kRed,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }

        if (validFiles.isNotEmpty) {
          debugPrint('[ProductForm] Added ${validFiles.length} valid files');
          setState(() {
            _newMedia.addAll(validFiles);
          });
        }
      }
    } catch (e) {
      debugPrint('[ProductForm] Pick error: $e');
    }
  }

  void _removeNewMedia(int index) {
    setState(() => _newMedia.removeAt(index));
  }

  void _removeExistingImage(int index) {
    setState(() => _images.removeAt(index));
  }

  bool _isFileTypeVideo(PlatformFile file) {
    final ext = file.extension?.toLowerCase() ?? '';
    return ['mp4', 'mov', 'avi', 'mkv', 'wmv'].contains(ext);
  }

  // ── Save / Submit ────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // FIX: Validation checks BOTH existing URLs AND newly picked files
    final hasExisting = _images.isNotEmpty;
    final hasNew = _newMedia.isNotEmpty;
    debugPrint('[ProductForm] Validation: existing=$hasExisting (${_images.length}), new=$hasNew (${_newMedia.length})');

    if (!hasExisting && !hasNew) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one photo or video is required'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final auth = context.read<AuthProvider>();
    final uid  = auth.user?.uid ?? '';
    final spp  = context.read<SellerProductsProvider>();

    try {
      // 1. Upload new media files
      List<String> uploadedUrls = List.from(_images);
      for (var file in _newMedia) {
        final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
        if (bytes == null) {
          debugPrint('[ProductForm] Skipping file with null bytes: ${file.name}');
          continue;
        }

        final isVid = _isFileTypeVideo(file);
        String url;
        if (isVid) {
          final result = await ApiService.uploadProductVideo(bytes, file.name, uid);
          url = result['video_url'] ?? '';
        } else {
          url = await ApiService.uploadProductImage(bytes, file.name, uid);
        }
        if (url.isNotEmpty) {
          uploadedUrls.add(url);
          debugPrint('[ProductForm] Uploaded: $url');
        }
      }

      // 2. Build product data map
      final data = {
        'sellerId': uid,
        'seller_id': uid,
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _category.isEmpty ? 'General' : _category,
        'price': double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
        'stock': int.tryParse(_stockCtrl.text.trim()) ?? 0,
        'images': uploadedUrls,
        'is_published': _isPublished,
      };

      // 3. Create or update
      bool success;
      if (_isEdit) {
        success = await spp.updateProduct(widget.product!.id, data);
      } else {
        success = await spp.addProduct(data);
      }

      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEdit ? '✅ Product updated successfully' : '✅ Product added successfully'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: _kGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(spp.error ?? '❌ Failed to save product'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: _kRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: _kRed, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_isEdit ? 'Edit Product' : 'Add New Product',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: isMobile
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _formSection('Basic Information', [
                    _field(controller: _nameCtrl, label: 'Product Name *',
                        validator: (v) => v?.isEmpty == true ? 'Required' : null),
                    const SizedBox(height: 14),
                    _field(controller: _descCtrl, label: 'Description *',
                        maxLines: 4,
                        validator: (v) => v?.isEmpty == true ? 'Required' : null),
                    const SizedBox(height: 14),
                    _dropdownField(),
                  ]),
                  const SizedBox(height: 16),
                  _formSection('Pricing & Inventory', [
                    _field(controller: _priceCtrl, label: 'Price (₱) *',
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    _field(controller: _stockCtrl, label: 'Stock Qty *',
                        keyboardType: TextInputType.number),
                  ]),
                  const SizedBox(height: 16),
                  _formSection('Media Upload', [_imageUploader()]),
                  const SizedBox(height: 24),
                  _saveButton(),
                  const SizedBox(height: 40),
                ],
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _formSection('Basic Information', [
                          _field(controller: _nameCtrl, label: 'Product Name *',
                              validator: (v) => v?.isEmpty == true ? 'Required' : null),
                          const SizedBox(height: 14),
                          _field(controller: _descCtrl, label: 'Description *',
                              maxLines: 4,
                              validator: (v) => v?.isEmpty == true ? 'Required' : null),
                          const SizedBox(height: 14),
                          _dropdownField(),
                        ]),
                        const SizedBox(height: 16),
                        _formSection('Pricing & Inventory', [
                          Row(children: [
                            Expanded(
                              child: _field(controller: _priceCtrl, label: 'Price (₱) *',
                                  keyboardType: TextInputType.number),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(controller: _stockCtrl, label: 'Stock Qty *',
                                  keyboardType: TextInputType.number),
                            ),
                          ]),
                        ]),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, color: _kBorder),
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _imageUploader(),
                        const SizedBox(height: 24),
                        _saveButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  // ── Shared Form Widgets ──────────────────────────────────────────────────────
  Widget _formSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: _kTextPrimary)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 13),
      decoration: _inputDec(label),
      validator: validator,
    );
  }

  InputDecoration _inputDec(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 13, color: _kTextSecondary),
      filled: true,
      fillColor: _kSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _kBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kAccent, width: 1.5)),
    );
  }

  Widget _dropdownField() {
    return DropdownButtonFormField<String>(
      initialValue: (_categories.contains(_category) && _category.isNotEmpty) ? _category : null,
      items: _categories.isEmpty
          ? [const DropdownMenuItem(value: 'General', child: Text('General'))]
          : _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      onChanged: (v) => setState(() => _category = v ?? ''),
      decoration: _inputDec('Category *'),
      validator: (v) => (v == null && _category.isEmpty) ? 'Required' : null,
    );
  }

  // ── Media Uploader Section ───────────────────────────────────────────────────
  Widget _imageUploader() {
    final totalItems = _images.length + _newMedia.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Product Media', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
            Text('$totalItems items',
              style: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildAddMediaBtn(icon: Icons.add_a_photo_rounded, label: 'Add Image', onTap: () => _pickMedia(false)),
              _buildAddMediaBtn(icon: Icons.video_call_rounded, label: 'Add Video', onTap: () => _pickMedia(true)),
              ..._images.asMap().entries.map((entry) => _buildUrlPreview(entry.value, entry.key)),
              ..._newMedia.asMap().entries.map((entry) => _buildFilePreview(entry.value, entry.key)),
            ],
          ),
        ),
        if (_images.isEmpty && _newMedia.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Add at least one image to showcase your product.',
              style: GoogleFonts.inter(fontSize: 11, color: _kTextSecondary, fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }

  Widget _buildAddMediaBtn({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _kAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: _kAccent, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _kTextPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlPreview(String url, int index) {
    final isVid = url.toLowerCase().contains('.mp4') ||
                  url.toLowerCase().contains('.mov') ||
                  url.toLowerCase().contains('.avi');
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MediaPreviewWidget(url: url, isVideo: isVid),
          ),
          if (isVid)
            const Center(child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 30)),
          Positioned(
            top: 4, right: 4,
            child: GestureDetector(
              onTap: () => _removeExistingImage(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePreview(PlatformFile file, int index) {
    final isVid = _isFileTypeVideo(file);
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MediaPreviewWidget(
              path: file.path,
              bytes: file.bytes,
              isVideo: isVid,
            ),
          ),
          if (isVid)
            const Center(child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 30)),
          Positioned(
            top: 4, right: 4,
            child: GestureDetector(
              onTap: () => _removeNewMedia(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            bottom: 4, left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: _kGreen.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(4)),
              child: Text(isVid ? 'NEW VIDEO' : 'NEW',
                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kAccent, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        child: _isSaving
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(_isEdit ? 'Save Changes' : 'Add Product'),
      ),
    );
  }
}
