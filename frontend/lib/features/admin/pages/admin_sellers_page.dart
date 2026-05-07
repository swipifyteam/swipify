import 'package:flutter/material.dart';
import 'package:swipify/services/admin_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swipify/core/utils/responsive_helper.dart';

class AdminSellersPage extends StatefulWidget {
  const AdminSellersPage({super.key});

  @override
  State<AdminSellersPage> createState() => _AdminSellersPageState();
}

class _AdminSellersPageState extends State<AdminSellersPage> {
  bool _isLoading = false;
  List<dynamic> _applications = [];
  int _offset = 0;
  final int _limit = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  String _statusFilter = 'pending';

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _offset = 0;
        _hasMore = true;
        _applications.clear();
      });
    } else {
      setState(() => _isLoadingMore = true);
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        debugPrint('[SELLER MGMT] Loading applications with status=$_statusFilter');
        final result = await AdminService.getSellerApplications(
          limit: _limit,
          offset: _offset,
          status: _statusFilter,
        );
        final newItems = result['applications'] ?? [];
        debugPrint('[SELLER MGMT] Fetched ${newItems.length} $_statusFilter applications.');
        setState(() {
          if (loadMore) {
            _applications.addAll(newItems);
          } else {
            _applications = List.from(newItems);
          }
          _offset += newItems.length as int;
          _hasMore = newItems.length == _limit;
        });
      }
    } catch (e) {
      debugPrint('[SELLER MGMT] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading applications: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _approveSeller(String appId, String storeName) async {
    // Optimistic removal
    final removedIndex = _applications.indexWhere((a) => a['id'] == appId);
    final removedItem = removedIndex >= 0 ? _applications[removedIndex] : null;
    if (removedIndex >= 0) {
      setState(() => _applications.removeAt(removedIndex));
    }

    try {
      await AdminService.sellerApplicationDecision(appId, 'approve', storeName: storeName);
      debugPrint('[SELLER MGMT] ✅ Approved application: $appId');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seller approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[SELLER MGMT] ❌ Error approving: $e');
      // Rollback
      if (removedItem != null && removedIndex >= 0 && mounted) {
        setState(() => _applications.insert(removedIndex, removedItem));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving seller: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectSeller(String appId, String reason) async {
    // Optimistic removal
    final removedIndex = _applications.indexWhere((a) => a['id'] == appId);
    final removedItem = removedIndex >= 0 ? _applications[removedIndex] : null;
    if (removedIndex >= 0) {
      setState(() => _applications.removeAt(removedIndex));
    }

    try {
      await AdminService.sellerApplicationDecision(appId, 'reject', reason: reason);
      debugPrint('[SELLER MGMT] ❌ Rejected application: $appId — Reason: $reason');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seller rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      // Rollback
      if (removedItem != null && removedIndex >= 0 && mounted) {
        setState(() => _applications.insert(removedIndex, removedItem));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting seller: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = ResponsiveHelper.isMobile(context);
    final bool isTablet = ResponsiveHelper.isTablet(context);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront, size: 28, color: Colors.deepPurple),
                  const SizedBox(width: 12),
                  Text(
                    'Seller Applications',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        items: const [
                          DropdownMenuItem(value: 'pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'approved', child: Text('Approved')),
                          DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _statusFilter = value);
                            _loadApplications();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadApplications,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? _buildShimmerList()
              : _applications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No $_statusFilter seller applications',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _applications.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _applications.length) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: _isLoadingMore
                                  ? const CircularProgressIndicator()
                                  : ElevatedButton(
                                      onPressed: () => _loadApplications(loadMore: true),
                                      child: const Text('Load More'),
                                    ),
                            ),
                          );
                        }
                        final app = _applications[index];
                        return _buildApplicationCard(app);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (_, __) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 150, height: 14, color: Colors.grey.shade200),
                    const SizedBox(height: 8),
                    Container(width: 200, height: 12, color: Colors.grey.shade100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplicationCard(dynamic app) {
    final statusString = (app['status'] ?? 'pending').toString().toLowerCase();
    final isPending = statusString == 'pending';
    final storeName = app['storeName'] ?? app['store_name'] ?? app['shop_name'] ?? 'Unknown Store';
    final sellerType = app['sellerType'] ?? app['seller_type'] ?? 'N/A';
    final createdAt = app['created_at'] ?? '';

    final bool isMobile = ResponsiveHelper.isMobile(context);

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24, 
        vertical: 6
      ),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDeepDiveModal(app),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPending ? Colors.amber.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.store,
                  color: isPending ? Colors.amber.shade700 : Colors.blue.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName, 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Type: $sellerType', 
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (createdAt.isNotEmpty)
                      Text(
                        'Applied: ${_formatDate(createdAt)}', 
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStatusTag(app['status']),
                    if (isPending)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: _buildQuickActions(app, iconSize: 18),
                      ),
                  ],
                )
              else
                Row(
                  children: [
                    _buildStatusTag(app['status']),
                    const SizedBox(width: 16),
                    if (isPending)
                      _buildQuickActions(app, iconSize: 20)
                    else
                      const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTag(String? status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        (status ?? 'pending').toUpperCase(),
        style: TextStyle(
          color: _getStatusColor(status),
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildQuickActions(dynamic app, {double iconSize = 20}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _showQuickRejectDialog(app),
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.close, color: Colors.red, size: iconSize),
          ),
          tooltip: 'Quick Reject',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: () => _showQuickApproveDialog(app),
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, color: Colors.green, size: iconSize),
          ),
          tooltip: 'Quick Approve',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  void _showQuickApproveDialog(dynamic app) {
    final appId = app['id']?.toString() ?? '';
    final storeName = app['storeName'] ?? app['store_name'] ?? '';
    final controller = TextEditingController(text: storeName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick Approve Seller'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Confirm store name for this application:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Store Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                await _approveSeller(appId, name);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Approve Now'),
          ),
        ],
      ),
    );
  }

  void _showQuickRejectDialog(dynamic app) {
    final appId = app['id']?.toString() ?? '';
    final controller = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Quick Reject Seller'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Reason for rejection',
                  hintText: 'Minimum 10 characters',
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                ),
                maxLines: 3,
                onChanged: (val) {
                  if (errorText != null) setDialogState(() => errorText = null);
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${controller.text.length} / 10 characters min',
                  style: TextStyle(
                    fontSize: 11, 
                    color: controller.text.length < 10 ? Colors.red : Colors.green
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final reason = controller.text.trim();
                if (reason.isEmpty) {
                  setDialogState(() => errorText = 'Reason is required');
                } else if (reason.length < 10) {
                  setDialogState(() => errorText = 'Reason must be at least 10 characters');
                } else {
                  Navigator.pop(context);
                  await _rejectSeller(appId, reason);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Reject Now'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeepDiveModal(dynamic app) async {
    final appId = app['id'];
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DeepDiveModal(
        appId: appId,
        initialData: app,
        onApprove: (id, storeName) async {
          await _approveSeller(id, storeName);
        },
        onReject: (id, reason) async {
          await _rejectSeller(id, reason);
        },
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending': return Colors.amber.shade700;
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }
}

/// Deep Dive Modal — fetches full application data and renders documents
class _DeepDiveModal extends StatefulWidget {
  final String appId;
  final dynamic initialData;
  final Future<void> Function(String, String) onApprove;
  final Future<void> Function(String, String) onReject;

  const _DeepDiveModal({
    required this.appId,
    required this.initialData,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_DeepDiveModal> createState() => _DeepDiveModalState();
}

class _DeepDiveModalState extends State<_DeepDiveModal> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _detail;
  String? _error;
  final TextEditingController _storeNameController = TextEditingController();
  String? _storeNameError;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetail() async {
    try {
      final data = await AdminService.getSellerApplicationDetail(widget.appId);
      debugPrint('[SELLER MGMT] Deep Dive loaded for: ${widget.appId}');
      if (mounted) setState(() { 
        _detail = data; 
        _isLoading = false; 
        
        final initialStoreName = _detail?['storeName'] ?? _detail?['store_name'] ?? widget.initialData['storeName'] ?? '';
        _storeNameController.text = initialStoreName.toString();
      });
    } catch (e) {
      debugPrint('[SELLER MGMT] Error loading detail: $e');
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = ResponsiveHelper.isMobile(context);
    final currentStatus = _detail?['status'] ?? widget.initialData['status'] ?? '';
    final isPending = currentStatus == 'pending';
    final storeName = _detail?['storeName'] ?? _detail?['store_name'] ?? widget.initialData['storeName'] ?? 'Unknown Store';

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600, 
          maxHeight: MediaQuery.of(context).size.height * 0.85
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.storefront, color: Colors.deepPurple.shade700, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName, 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text('Application ID: ${widget.appId}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: _isLoading
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ))
                  : _error != null
                      ? Center(child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                        ))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoSection(),
                              const SizedBox(height: 20),
                              _buildDocumentsSection(),
                              const SizedBox(height: 20),
                              _buildAddressSection(),
                            ],
                          ),
                        ),
            ),
            // Actions
            if (isPending)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, -2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : () => _showRejectReasonDialog(),
                        icon: const Icon(Icons.close, color: Colors.red),
                        label: const Text('REJECT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : () => _handleApprove(),
                        icon: _isSubmitting 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check),
                        label: Text(_isSubmitting ? 'APPROVING...' : 'APPROVE', style: const TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleApprove() async {
    final storeName = _storeNameController.text.trim();
    if (storeName.isEmpty) {
      setState(() {
        _storeNameError = 'Store name is required';
      });
      return;
    }
    setState(() {
      _storeNameError = null;
      _isSubmitting = true;
    });

    try {
      await widget.onApprove(widget.appId, storeName);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildInfoSection() {
    final d = _detail!;
    final isPending = (widget.initialData['status'] ?? '') == 'pending';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Applicant Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        _infoRow('Applicant Name', d['applicant_name'] ?? 'N/A'),
        _infoRow('Email', d['applicant_email'] ?? 'N/A'),
        _infoRow('Phone', d['applicant_phone'] ?? d['phone'] ?? 'N/A'),
        _infoRow('Seller Type', d['sellerType'] ?? d['seller_type'] ?? 'N/A'),
        _infoRow('User ID', d['user_id'] ?? 'N/A'),
        _infoRow('Status', (d['status'] ?? 'N/A').toString().toUpperCase()),
        if (d['created_at'] != null)
          _infoRow('Created Date', _formatDateLocal(d['created_at'])),
        
        const SizedBox(height: 16),
        const Text('Proposed Store Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        if (isPending)
          TextField(
            controller: _storeNameController,
            decoration: InputDecoration(
              hintText: 'Enter Store Name',
              errorText: _storeNameError,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          )
        else
          Text(d['storeName'] ?? d['store_name'] ?? 'N/A', style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  String _formatDateLocal(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  Widget _buildDocumentsSection() {
    final d = _detail!;
    final idPhoto = d['id_photo'] ?? d['idPhoto'] ?? d['id_document'];
    final businessPermit = d['business_permit'] ?? d['businessPermit'];
    final selfiePhoto = d['selfie'] ?? d['selfie_photo'];

    final docs = <MapEntry<String, String?>>[];
    if (idPhoto != null) docs.add(MapEntry('Government ID', idPhoto.toString()));
    if (businessPermit != null) docs.add(MapEntry('Business Permit', businessPermit.toString()));
    if (selfiePhoto != null) docs.add(MapEntry('Selfie Verification', selfiePhoto.toString()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Submitted Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        if (docs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('No documents submitted', style: TextStyle(color: Colors.grey)),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: docs.map((entry) => _buildDocumentTile(entry.key, entry.value!)).toList(),
          ),
      ],
    );
  }

  Widget _buildDocumentTile(String label, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 180,
            height: 120,
            color: Colors.grey.shade100,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              },
              errorBuilder: (_, __, ___) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.grey.shade400, size: 32),
                  const SizedBox(height: 4),
                  Text('Failed to load', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressSection() {
    final d = _detail!;
    final address = d['address'] ?? d['business_address'] ?? d['store_address'];
    if (address == null) return const SizedBox.shrink();

    String addressText;
    if (address is Map) {
      addressText = [
        address['street'],
        address['barangay'],
        address['city'],
        address['province'],
        address['zip'],
      ].where((e) => e != null && e.toString().isNotEmpty).join(', ');
    } else {
      addressText = address.toString();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Business Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Text(addressText, style: TextStyle(color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text('$label:', style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  void _showRejectReasonDialog() {
    final controller = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Rejection Reason'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Explain why this application is being rejected...',
              border: const OutlineInputBorder(),
              errorText: errorText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.pop(ctx), 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              onPressed: _isSubmitting ? null : () async {
                final reason = controller.text.trim();
                if (reason.isEmpty) {
                  setDialogState(() => errorText = 'Reason is required');
                } else if (reason.length < 10) {
                  setDialogState(() => errorText = 'Reason must be at least 10 characters');
                } else {
                  setDialogState(() {
                    _isSubmitting = true;
                  });
                  try {
                    await widget.onReject(widget.appId, reason);
                    if (mounted) {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    }
                  } finally {
                    setDialogState(() {
                      _isSubmitting = false;
                    });
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: _isSubmitting 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Confirm Reject'),
            ),
          ],
        ),
      ),
    );
  }
}
