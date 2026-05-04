import 'package:flutter/material.dart';
import 'package:swipify/services/admin_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key});

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  bool _isLoading = true;
  List<dynamic> _products = [];
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        debugPrint('[MODERATION] Loading products with status=$_selectedStatus');
        final result = await AdminService.getProducts(
          status: _selectedStatus,
        );
        setState(() => _products = result['products'] ?? []);
        debugPrint('[MODERATION] Loaded ${_products.length} products');
      }
    } catch (e) {
      debugPrint('[MODERATION] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStatus(String productId, String status, {String? reason}) async {
    try {
      await AdminService.updateProductStatus(productId, status, reason: reason);
      _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product status updated to $status'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[MODERATION] Error updating product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating product: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRejectDialog(String productId) {
    final reasonController = TextEditingController();
    String? errorText;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Reject Product'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    hintText: 'Enter reason for rejection',
                    border: const OutlineInputBorder(),
                    errorText: errorText,
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) {
                    setState(() => errorText = 'Reason is required');
                  } else if (reason.length < 10) {
                    setState(() => errorText = 'Reason must be at least 10 characters');
                  } else {
                    _updateStatus(productId, 'rejected', reason: reason);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('Reject'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              const Icon(Icons.inventory_2, size: 28, color: Colors.indigo),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Product Moderation',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedStatus,
                    hint: const Text('All Statuses'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Statuses')),
                      DropdownMenuItem(value: 'pending', child: Text('Pending Approval')),
                      DropdownMenuItem(value: 'active', child: Text('Active / Approved')),
                      DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                      DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value;
                      });
                      _loadProducts();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadProducts,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? _buildShimmerList()
              : _products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No products found',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        return _buildProductCard(product);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (_, __) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 180, height: 14, color: Colors.grey.shade200),
                    const SizedBox(height: 8),
                    Container(width: 120, height: 12, color: Colors.grey.shade100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(dynamic product) {
    final status = product['status'] ?? 'pending';
    final sellerName = product['seller_name'] ?? 'Unknown Seller';
    final price = product['price'] ?? 0;
    final images = product['images'] as List?;
    final hasImage = images != null && images.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product image
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: hasImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        images[0].toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: Colors.grey.shade400),
                      ),
                    )
                  : Icon(Icons.image_outlined, color: Colors.grey.shade400),
            ),
            const SizedBox(width: 12),
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? 'Unknown Product',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.store_outlined, size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          sellerName,
                          style: TextStyle(color: Colors.blue.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₱${_formatPrice(price)}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status.toString().toUpperCase(),
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Actions
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'approve') {
                  _updateStatus(product['id'], 'active');
                } else if (action == 'reject') {
                  _showRejectDialog(product['id']);
                } else if (action == 'suspend') {
                  _updateStatus(product['id'], 'suspended', reason: 'Admin suspended');
                }
              },
              itemBuilder: (context) => [
                if (status == 'pending' || status == 'rejected' || status == 'suspended')
                  const PopupMenuItem(value: 'approve', child: Text('Approve (Set Active)')),
                if (status == 'pending' || status == 'active')
                  const PopupMenuItem(value: 'reject', child: Text('Reject')),
                if (status == 'active')
                  const PopupMenuItem(value: 'suspend', child: Text('Suspend Listing')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(dynamic price) {
    try {
      final p = double.parse(price.toString());
      return p.toStringAsFixed(2);
    } catch (_) {
      return '0.00';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active': return Colors.green;
      case 'pending': return Colors.orange;
      case 'rejected': return Colors.red;
      case 'suspended': return Colors.purple;
      default: return Colors.grey;
    }
  }
}
