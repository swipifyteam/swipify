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

  XFile? _imageFile;
  bool _isUploading = false;
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
    super.dispose();
  }

  // ── Image Picker ────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      debugPrint('[PRODUCT] Image selected: ${pickedFile.name}');
      setState(() => _imageFile = pickedFile);
    }
  }

  // ── Submit Form ─────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      debugPrint('[PRODUCT] Validation failed — aborting submit');
      return;
    }

    if (_imageFile == null) {
      _showError('Please select at least one product image.');
      return;
    }

    // ── Get user and seller from providers (NOT from Firebase directly) ──────
    final authProvider = context.read<AuthProvider>();
    final sellerProvider = context.read<SellerProvider>();

    final userId = authProvider.user?.uid;
    if (userId == null) {
      debugPrint('[PRODUCT] Submit aborted — no authenticated user');
      _showError('Please log in to add a product.');
      return;
    }

    final seller = sellerProvider.seller;
    if (seller == null) {
      debugPrint('[PRODUCT] Submit aborted — seller profile not found');
      _showError(
          'Seller profile not found. Please ensure your application is approved.');
      return;
    }

    setState(() => _isUploading = true);
    debugPrint('[PRODUCT] Creating product: ${_nameController.text}');

    try {
      // ── Step 1: Upload image via API (MCP/FastAPI layer) ──────────────────
      debugPrint('[API] Uploading product image');
      final bytes = await _imageFile!.readAsBytes();
      final imageUrl = await ApiService.uploadSellerDocument(
        userId,
        'product_image',
        bytes,
        _imageFile!.name,
        'image/jpeg',
      );
      debugPrint('[API] Image uploaded: $imageUrl');

      // ── Step 2: Build product data ────────────────────────────────────────
      final data = {
        'sellerId': userId,
        'name': _nameController.text.trim(),
        'category': _selectedCategory, // product category for browsing
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'stock': int.tryParse(_stockController.text) ?? 0,
        'description': _descController.text.trim(),
        'images': [imageUrl],
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

      debugPrint('[PRODUCT] Payload ready — sending to API');

      // ── Step 3: Save via SellerProvider (MCP layer) ──────────────
      // Provider also calls ProductsCache.add() → HomeScreen updates instantly
      if (!mounted) return;
      final provider = context.read<SellerProvider>();
      final success = await provider.addProduct(data, userId);

      if (success && mounted) {
        debugPrint('[PRODUCT] Product saved successfully — returning to dashboard');
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
      debugPrint('[PRODUCT] addProduct caught error: $e');
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
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Publishing product…'),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  // ── Image Picker ─────────────────────────────────────────
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[400]!),
                      ),
                      child: _imageFile == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo,
                                    size: 40, color: Colors.grey[600]),
                                const SizedBox(height: 8),
                                Text('Tap to add product image',
                                    style: TextStyle(color: Colors.grey[600])),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: kIsWeb
                                  ? Image.network(_imageFile!.path,
                                      fit: BoxFit.cover)
                                  : Image.file(File(_imageFile!.path),
                                      fit: BoxFit.cover),
                            ),
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
}
