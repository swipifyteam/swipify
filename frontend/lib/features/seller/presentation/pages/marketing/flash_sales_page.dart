// lib/features/seller/presentation/pages/marketing/flash_sales_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/seller/service/seller_provider.dart';
import 'package:swipify/features/seller/service/seller_products_provider.dart';
import 'package:swipify/models/product_model.dart';

class FlashSalesPage extends StatefulWidget {
  const FlashSalesPage({super.key});

  @override
  State<FlashSalesPage> createState() => _FlashSalesPageState();
}

class _FlashSalesPageState extends State<FlashSalesPage> {
  bool _isLoading = true;
  List<dynamic> _sales = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final sp = context.read<SellerProvider>();
    if (auth.user == null) return;
    
    final sales = await sp.getFlashSales(auth.user!.uid);
    if (mounted) {
      setState(() {
        _sales = sales;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('Flash Sales'),
        backgroundColor: SwipifyTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sales.isEmpty
              ? _buildEmptyState()
              : _buildSalesList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateForm(context),
        backgroundColor: const Color(0xFFE97B4A),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Flash Sale'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bolt_rounded, size: 80, color: Color(0xFFE97B4A)),
          const SizedBox(height: 16),
          Text('No flash sales yet',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Drive urgency with time-limited discounts',
              style: GoogleFonts.inter(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildSalesList() {
    final products = context.watch<SellerProductsProvider>().products;
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sales.length,
      itemBuilder: (context, index) {
        final sale = _sales[index];
        final start = DateTime.tryParse(sale['start_time'] ?? '') ?? DateTime.now();
        final end = DateTime.tryParse(sale['end_time'] ?? '') ?? DateTime.now();
        final isOngoing = DateTime.now().isAfter(start) && DateTime.now().isBefore(end);
        
        // Find product name
        final product = products.firstWhere((p) => p.id == sale['product_id'], 
            orElse: () => const ProductModel(id: '', name: 'Deleted Product', description: '', price: 0, stock: 0, category: '', images: [], sellerId: '', isPublished: false, rating: 0, shopId: '', shopName: ''));
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isOngoing ? Colors.orange : Colors.grey).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.flash_on_rounded, color: isOngoing ? Colors.orange : Colors.grey),
            ),
            title: Text(
              product.name,
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Flash Price: ₱${sale['discount_price']} (Limit: ${sale['stock_limit']})', 
                    style: GoogleFonts.inter(color: SwipifyTheme.primaryColor, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${DateFormat('MMM d, HH:mm').format(start)} - ${DateFormat('MMM d, HH:mm').format(end)}',
                    style: GoogleFonts.inter(fontSize: 12)),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 24),
              onPressed: () async {
                final sp = context.read<SellerProvider>();
                final deleted = await sp.deleteFlashSale(sale['id']);
                if (deleted) _loadData();
              },
            ),
          ),
        );
      },
    );
  }

  void _showCreateForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateFlashSaleSheet(onCreated: _loadData),
    );
  }
}

class _CreateFlashSaleSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateFlashSaleSheet({required this.onCreated});

  @override
  State<_CreateFlashSaleSheet> createState() => _CreateFlashSaleSheetState();
}

class _CreateFlashSaleSheetState extends State<_CreateFlashSaleSheet> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedProductId;
  double _price = 0;
  int _limit = 10;
  DateTime _start = DateTime.now().add(const Duration(minutes: 5));
  DateTime _end = DateTime.now().add(const Duration(hours: 4));
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final spp = context.read<SellerProductsProvider>();
    if (auth.user != null) {
      spp.fetchSellerProducts(auth.user!.uid);
    }
  }

  Future<void> _pickDateTime(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _start : _end),
    );
    if (time == null) return;

    setState(() {
      final newDt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isStart) {
        _start = newDt;
        if (_end.isBefore(_start)) {
          _end = _start.add(const Duration(hours: 4));
        }
      } else {
        _end = newDt;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<SellerProductsProvider>().products;
    final selectedProduct = _selectedProductId != null 
        ? products.firstWhere((p) => p.id == _selectedProductId) 
        : null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Schedule Flash Sale', 
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Product to Discount', border: OutlineInputBorder()),
              initialValue: _selectedProductId,
              items: products.map((p) => DropdownMenuItem(
                value: p.id,
                child: Text(p.name, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (v) => setState(() => _selectedProductId = v),
              validator: (v) => v == null ? 'Required' : null,
              hint: const Text('Choose a product'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Flash Price (₱)', 
                      border: const OutlineInputBorder(),
                      helperText: selectedProduct != null ? 'Regular: ₱${selectedProduct.price}' : null,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _price = double.tryParse(v) ?? 0,
                    validator: (v) {
                      final p = double.tryParse(v ?? '') ?? 0;
                      if (p <= 0) return 'Invalid price';
                      if (selectedProduct != null && p >= selectedProduct.price) {
                        return 'Must be < ₱${selectedProduct.price}';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Stock Limit', border: OutlineInputBorder(), helperText: 'Qty for flash sale'),
                    keyboardType: TextInputType.number,
                    initialValue: '10',
                    onChanged: (v) => _limit = int.tryParse(v) ?? 10,
                    validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Duration', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDateTime(true),
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(DateFormat('MMM d, HH:mm').format(_start)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('to')),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDateTime(false),
                    icon: const Icon(Icons.access_time_rounded, size: 16),
                    label: Text(DateFormat('MMM d, HH:mm').format(_end)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
              ],
            ),
            if (_end.isBefore(_start))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('End time must be after start time', style: TextStyle(color: Colors.red[700], fontSize: 12)),
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE97B4A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isSaving 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : Text('Activate Flash Sale', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_end.isBefore(_start)) return;
    
    setState(() => _isSaving = true);
    
    final auth = context.read<AuthProvider>();
    final sp = context.read<SellerProvider>();
    
    final success = await sp.createFlashSale({
      'seller_id': auth.user!.uid,
      'product_id': _selectedProductId,
      'discount_price': _price,
      'original_price': context.read<SellerProductsProvider>().products.firstWhere((p) => p.id == _selectedProductId).price,
      'stock_limit': _limit,
      'start_time': _start.toIso8601String(),
      'end_time': _end.toIso8601String(),
      'is_active': true,
    });
    
    if (success) {
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${sp.error ?? 'Unknown error'}'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}
