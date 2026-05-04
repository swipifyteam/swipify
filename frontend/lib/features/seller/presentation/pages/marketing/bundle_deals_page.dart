// lib/features/seller/presentation/pages/marketing/bundle_deals_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/seller/service/seller_products_provider.dart';
import 'package:swipify/features/seller/service/seller_provider.dart';

class BundleDealsPage extends StatefulWidget {
  const BundleDealsPage({super.key});

  @override
  State<BundleDealsPage> createState() => _BundleDealsPageState();
}

class _BundleDealsPageState extends State<BundleDealsPage> {
  bool _isLoading = true;
  List<dynamic> _bundles = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final sp = context.read<SellerProvider>();
    if (auth.user == null) return;
    
    setState(() => _isLoading = true);
    final bundles = await sp.getBundleDeals(auth.user!.uid);
    if (mounted) {
      setState(() {
        _bundles = bundles;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('Bundle Deals'),
        backgroundColor: SwipifyTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bundles.isEmpty
              ? _buildEmptyState()
              : _buildBundleList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateForm(context),
        backgroundColor: const Color(0xFF8B5CF6),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Bundle Deal'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_offer_rounded, size: 80, color: Color(0xFF8B5CF6)),
          const SizedBox(height: 16),
          Text('No bundle deals yet',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Incentivize bulk purchases (e.g., Buy 2 get 10% off)',
              style: GoogleFonts.inter(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildBundleList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bundles.length,
      itemBuilder: (context, index) {
        final bundle = _bundles[index];
        final productCount = (bundle['product_ids'] as List).length;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF8B5CF6)),
            ),
            title: Text(
              bundle['name'] ?? 'Bundle Deal',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Buy ${bundle['min_quantity']}+ items, Get ${bundle['discount_percentage']}% Off'),
                Text('$productCount products included', style: const TextStyle(fontSize: 12)),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: () async {
                final sp = context.read<SellerProvider>();
                await sp.deleteBundleDeal(bundle['id']);
                _loadData();
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
      builder: (context) => _CreateBundleSheet(onCreated: _loadData),
    );
  }
}

class _CreateBundleSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateBundleSheet({required this.onCreated});

  @override
  State<_CreateBundleSheet> createState() => _CreateBundleSheetState();
}

class _CreateBundleSheetState extends State<_CreateBundleSheet> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  int _minQty = 2;
  double _discount = 5;
  final List<String> _selectedProductIds = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-load products
    final auth = context.read<AuthProvider>();
    final spp = context.read<SellerProductsProvider>();
    if (auth.user != null) {
      spp.fetchSellerProducts(auth.user!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<SellerProductsProvider>().products;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Create Bundle Deal', 
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Bundle Name', border: OutlineInputBorder(), hintText: 'e.g. Summer Mix & Match'),
              onChanged: (v) => _name = v,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Min Quantity', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    initialValue: '2',
                    onChanged: (v) => _minQty = int.tryParse(v) ?? 2,
                    validator: (v) => (int.tryParse(v ?? '') ?? 0) < 2 ? 'Min 2' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Discount (%)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    initialValue: '5',
                    onChanged: (v) => _discount = double.tryParse(v) ?? 5,
                    validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Select Products', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: products.isEmpty 
                ? const Center(child: Text('No products found. Add products first.'))
                : ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final p = products[index];
                      final isSelected = _selectedProductIds.contains(p.id);
                      return CheckboxListTile(
                        title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('₱${p.price}'),
                        value: isSelected,
                        activeColor: const Color(0xFF8B5CF6),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedProductIds.add(p.id);
                            } else {
                              _selectedProductIds.remove(p.id);
                            }
                          });
                        },
                      );
                    },
                  ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SwipifyTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : Text('Create Bundle (${_selectedProductIds.length} Selected)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one product')));
      return;
    }
    
    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();
    final sp = context.read<SellerProvider>();
    
    final success = await sp.createBundleDeal({
      'seller_id': auth.user!.uid,
      'name': _name,
      'product_ids': _selectedProductIds,
      'min_quantity': _minQty,
      'discount_percentage': _discount,
      'is_active': true,
    });
    
    if (!mounted) return;
    
    if (success) {
      widget.onCreated();
      Navigator.pop(context);
    } else {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${sp.error ?? 'Unknown error'}')),
      );
    }
  }
}
