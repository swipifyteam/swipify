// lib/features/seller/presentation/pages/edit_product_page.dart
// Edit Product page — fully delegates to SellerProvider.
// Gets seller UID from AuthProvider.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/seller/service/seller_provider.dart';
import 'package:swipify/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:swipify/features/products/model/product_model.dart';

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

  XFile? _imageFile;
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
  }

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

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = pickedFile);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final sellerProvider = context.read<SellerProvider>();

    final userId = authProvider.user?.uid;
    if (userId == null) {
      _showError('Please log in to update product.');
      return;
    }

    setState(() => _isUpdating = true);

    try {
      String? imageUrl = widget.product.firstImage;

      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        imageUrl = await ApiService.uploadSellerDocument(
          userId,
          'product_image',
          bytes,
          _imageFile!.name,
          'image/jpeg',
        );
      }

      final data = {
        'name': _nameController.text.trim(),
        'category': _selectedCategory,
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

      final success = await sellerProvider.updateProduct(widget.product.id, data, userId);

      if (success && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Product updated successfully!')),
        );
      } else {
        throw Exception('Failed to update product');
      }
    } catch (e) {
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red[700]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Product'),
        backgroundColor: SwipifyTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isUpdating
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[400]!),
                      ),
                      child: _imageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: kIsWeb
                                  ? Image.network(_imageFile!.path, fit: BoxFit.cover)
                                  : Image.file(File(_imageFile!.path), fit: BoxFit.cover),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(widget.product.firstImage, fit: BoxFit.cover),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.isEmpty) ? 'Please enter a product name' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _sizesController,
                    decoration: const InputDecoration(labelText: 'Sizes (comma separated)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _colorsController,
                    decoration: const InputDecoration(labelText: 'Colors (comma separated)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Price', prefixText: '₱ ', border: OutlineInputBorder()),
                          validator: (v) => (v == null || v.isEmpty) ? 'Enter price' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Stock', border: OutlineInputBorder()),
                          validator: (v) => (v == null || v.isEmpty) ? 'Enter stock' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descController,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), alignLabelWithHint: true),
                    validator: (v) => (v == null || v.isEmpty) ? 'Please enter a description' : null,
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
                      child: const Text('Update Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
