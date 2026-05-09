import 'package:flutter/material.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/services/admin_marketing_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swipify/core/utils/responsive_helper.dart';

class AdminMarketingPage extends StatefulWidget {
  const AdminMarketingPage({super.key});

  @override
  State<AdminMarketingPage> createState() => _AdminMarketingPageState();
}

class _AdminMarketingPageState extends State<AdminMarketingPage> {
  bool _isLoading = true;
  List<dynamic> _vouchers = [];
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final vouchers = await AdminMarketingService.getPlatformVouchers();
        final stats = await AdminMarketingService.getMarketingStats();
        debugPrint('[MARKETING] Vouchers synchronized successfully. Count: ${vouchers.length}');
        setState(() {
          _vouchers = vouchers;
          _stats = stats;
        });
      }
    } catch (e) {
      debugPrint('[MARKETING] Error loading marketing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading marketing data: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final bool isMobile = ResponsiveHelper.isMobile(context);
    final bool isTablet = ResponsiveHelper.isTablet(context);
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsOverview(context),
          const SizedBox(height: 32),
          if (isMobile || isTablet)
            Column(
              children: [
                VoucherManagementCard(
                  vouchers: _vouchers,
                  onRefresh: _loadData,
                ),
                const SizedBox(height: 24),
                const CampaignList(),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: VoucherManagementCard(
                  vouchers: _vouchers,
                  onRefresh: _loadData,
                )),
                const SizedBox(width: 24),
                const Expanded(flex: 1, child: CampaignList()),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview(BuildContext context) {
    final bool isMobile = ResponsiveHelper.isMobile(context);
    
    final children = [
      _buildStatCard(context, 'Total Vouchers', _stats['total_vouchers']?.toString() ?? '0', Icons.confirmation_number, Colors.blue),
      _buildStatCard(context, 'Total Redemptions', _stats['total_redemptions']?.toString() ?? '0', Icons.redeem, Colors.green),
      _buildStatCard(context, 'Active Campaigns', _stats['active_campaigns']?.toString() ?? '0', Icons.campaign, Colors.orange),
    ];

    if (isMobile) {
      return Column(
        children: children.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SizedBox(width: double.infinity, child: c),
        )).toList(),
      );
    }

    return Row(
      children: children.map((c) => Expanded(child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: c,
      ))).toList(),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    final bool isMobile = ResponsiveHelper.isMobile(context);
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: isMobile ? 20 : 24),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title, 
                  style: TextStyle(color: Colors.grey.shade600, fontSize: isMobile ? 12 : 14),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value, 
                  style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VoucherManagementCard extends StatelessWidget {
  final List<dynamic> vouchers;
  final VoidCallback onRefresh;

  const VoucherManagementCard({
    super.key,
    required this.vouchers,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Text('Voucher Management', style: SwipifyTheme.heading2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: onRefresh,
                    tooltip: 'Refresh',
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateVoucherDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('New Platform Voucher'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (vouchers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.loyalty_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('No vouchers found.', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: vouchers.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final voucher = vouchers[index];
                return _buildVoucherRow(context, voucher);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildVoucherRow(BuildContext context, dynamic voucher) {
    final bool isMobile = ResponsiveHelper.isMobile(context);
    final code = voucher['code'] ?? 'N/A';
    final discountType = voucher['discount_type'] ?? 'percentage';
    final value = voucher['value'] ?? 0;
    final usageCount = voucher['usage_count'] ?? 0;
    final usageLimit = voucher['usage_limit'];
    final isExpired = voucher['is_expired'] == true;
    final endDate = voucher['end_date'] ?? '';
    final minSpend = voucher['min_spend'] ?? 0;
    final type = voucher['type'] ?? 'platform';
    final sellerName = voucher['seller_name'] ?? 'Swipify';

    final discountDisplay = discountType == 'percentage'
        ? '$value% off'
        : '₱${_formatPrice(value)} off';

    final usageDisplay = usageLimit != null
        ? '$usageCount / $usageLimit used'
        : '$usageCount used';

    if (isMobile) {
      // Mobile-optimized layout (Column-based)
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isExpired ? Colors.red.shade50 : Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(code, style: TextStyle(fontWeight: FontWeight.bold, color: isExpired ? Colors.red.shade700 : Colors.teal.shade700)),
                  ),
                  Row(
                    children: [
                      if (type == 'platform')
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _showEditVoucherDialog(context, voucher),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () => _deleteVoucher(context, voucher['id']),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(discountDisplay, style: SwipifyTheme.productTitle),
              Text('Min spend: ₱${_formatPrice(minSpend)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              if (type == 'seller')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('By $sellerName', style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(usageDisplay, style: const TextStyle(fontSize: 12)),
                  Text(isExpired ? 'Expired' : 'Ends: ${_formatDate(endDate)}', 
                    style: TextStyle(fontSize: 12, color: isExpired ? Colors.red : Colors.grey.shade600)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Desktop/Wide layout
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Code badge
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExpired ? Colors.red.shade50 : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isExpired ? Colors.red.shade200 : Colors.teal.shade200),
                  ),
                  child: Text(
                    code,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isExpired ? Colors.red.shade700 : Colors.teal.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Text(type.toUpperCase(), style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(discountDisplay, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis),
                Text(
                  'Min: ₱${_formatPrice(minSpend)}${type == 'seller' ? ' • By $sellerName' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Usage
          SizedBox(
            width: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(usageDisplay, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                if (usageLimit != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: LinearProgressIndicator(
                      value: usageLimit > 0 ? (usageCount / usageLimit).clamp(0.0, 1.0) : 0.0,
                      minHeight: 4,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(usageCount >= usageLimit ? Colors.red : Colors.teal),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Status & Date
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isExpired ? 'EXPIRED' : 'ACTIVE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isExpired ? Colors.red : Colors.green),
                ),
                if (endDate.isNotEmpty)
                  Text(_formatDate(endDate), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Actions
          if (type == 'platform')
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _showEditVoucherDialog(context, voucher),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
            onPressed: () => _deleteVoucher(context, voucher['id']),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
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

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  void _showCreateVoucherDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateVoucherDialog(),
    ).then((value) {
      if (value == true) onRefresh();
    });
  }

  void _showEditVoucherDialog(BuildContext context, dynamic voucher) {
    showDialog(
      context: context,
      builder: (context) => EditVoucherDialog(voucher: voucher),
    ).then((value) {
      if (value == true) onRefresh();
    });
  }

  Future<void> _deleteVoucher(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Voucher'),
        content: const Text('Are you sure you want to delete this voucher? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AdminMarketingService.deletePlatformVoucher(id);
      onRefresh();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting voucher: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

class CreateVoucherDialog extends StatefulWidget {
  const CreateVoucherDialog({super.key});

  @override
  State<CreateVoucherDialog> createState() => _CreateVoucherDialogState();
}

class _CreateVoucherDialogState extends State<CreateVoucherDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _valueController = TextEditingController();
  final _minSpendController = TextEditingController();
  final _usageLimitController = TextEditingController();
  String _discountType = 'percentage';
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = ResponsiveHelper.isMobile(context);
    
    return AlertDialog(
      title: const Text('Create Platform Voucher'),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Voucher Code (e.g. WELCOME50)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _discountType,
                  items: const [
                    DropdownMenuItem(value: 'percentage', child: Text('Percentage (%)')),
                    DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount (₱)')),
                  ],
                  onChanged: (v) => setState(() => _discountType = v!),
                  decoration: const InputDecoration(
                    labelText: 'Discount Type',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _valueController,
                  decoration: InputDecoration(
                    labelText: _discountType == 'percentage' ? 'Percentage (e.g. 20)' : 'Amount (e.g. 100)',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _minSpendController,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Spend (₱)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usageLimitController,
                  decoration: const InputDecoration(
                    labelText: 'Usage Limit (leave blank for unlimited)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('End Date'),
                  subtitle: Text(_endDate.toString().split(' ')[0]),
                  trailing: const Icon(Icons.calendar_today),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _endDate = picked);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final voucherData = <String, dynamic>{
            'code': _codeController.text,
            'discount_type': _discountType,
            'value': double.parse(_valueController.text),
            'min_spend': double.tryParse(_minSpendController.text) ?? 0.0,
            'end_date': _endDate.toIso8601String(),
          };
          
          final usageLimit = int.tryParse(_usageLimitController.text);
          if (usageLimit != null) {
            voucherData['max_usage'] = usageLimit;
          }
          
          await AdminMarketingService.createPlatformVoucher(voucherData);
          debugPrint('[MARKETING] Created voucher: ${_codeController.text}');
          if (!mounted) return;
          Navigator.pop(context, true);
        }
      } catch (e) {
        debugPrint('[MARKETING] Error creating voucher: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }
}

class EditVoucherDialog extends StatefulWidget {
  final dynamic voucher;
  const EditVoucherDialog({super.key, required this.voucher});

  @override
  State<EditVoucherDialog> createState() => _EditVoucherDialogState();
}

class _EditVoucherDialogState extends State<EditVoucherDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeController;
  late TextEditingController _valueController;
  late TextEditingController _minSpendController;
  late TextEditingController _usageLimitController;
  late String _discountType;
  late DateTime _endDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final v = widget.voucher;
    _codeController = TextEditingController(text: v['code'] ?? '');
    _valueController = TextEditingController(text: (v['value'] ?? 0).toString());
    _minSpendController = TextEditingController(text: (v['min_spend'] ?? 0).toString());
    _usageLimitController = TextEditingController(
      text: v['usage_limit'] != null && v['usage_limit'] != 999999 ? v['usage_limit'].toString() : '',
    );
    _discountType = v['discount_type'] ?? 'percentage';
    try {
      _endDate = DateTime.parse(v['end_date'] ?? '');
    } catch (_) {
      _endDate = DateTime.now().add(const Duration(days: 30));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = ResponsiveHelper.isMobile(context);
    
    return AlertDialog(
      title: const Text('Edit Platform Voucher'),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(labelText: 'Voucher Code', border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _discountType,
                  items: const [
                    DropdownMenuItem(value: 'percentage', child: Text('Percentage (%)')),
                    DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount (₱)')),
                  ],
                  onChanged: (v) => setState(() => _discountType = v!),
                  decoration: const InputDecoration(labelText: 'Discount Type', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _valueController,
                  decoration: InputDecoration(
                    labelText: _discountType == 'percentage' ? 'Percentage' : 'Amount (₱)',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _minSpendController,
                  decoration: const InputDecoration(labelText: 'Minimum Spend (₱)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usageLimitController,
                  decoration: const InputDecoration(labelText: 'Usage Limit (blank = unlimited)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('End Date'),
                  subtitle: Text(_endDate.toString().split(' ')[0]),
                  trailing: const Icon(Icons.calendar_today),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _endDate = picked);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save Changes'),
        ),
      ],
    );
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      try {
        final data = <String, dynamic>{
          'code': _codeController.text,
          'discount_type': _discountType,
          'value': double.parse(_valueController.text),
          'min_spend': double.tryParse(_minSpendController.text) ?? 0.0,
          'end_date': _endDate.toIso8601String(),
        };
        final usageLimit = int.tryParse(_usageLimitController.text);
        if (usageLimit != null) data['max_usage'] = usageLimit;

        await AdminMarketingService.updatePlatformVoucher(widget.voucher['id'], data);
        debugPrint('[MARKETING] Updated voucher: ${widget.voucher['id']}');
        if (!mounted) return;
        Navigator.pop(context, true);
      } catch (e) {
        debugPrint('[MARKETING] Error updating voucher: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }
}

class CampaignList extends StatelessWidget {
  const CampaignList({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Marketing Campaigns', style: SwipifyTheme.heading2),
          const SizedBox(height: 24),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32.0),
              child: Column(
                children: [
                  Icon(Icons.auto_awesome, size: 48, color: Colors.amber),
                  SizedBox(height: 16),
                  Text('Campaign Management', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Coming soon in Phase 3', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
