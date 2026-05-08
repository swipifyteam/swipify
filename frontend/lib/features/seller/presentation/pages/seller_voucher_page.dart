import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipify/features/seller/service/seller_vouchers_provider.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/models/voucher_model.dart';
import 'package:swipify/core/theme.dart';
import 'package:intl/intl.dart';

class SellerVoucherPage extends StatefulWidget {
  const SellerVoucherPage({super.key});

  @override
  State<SellerVoucherPage> createState() => _SellerVoucherPageState();
}

class _SellerVoucherPageState extends State<SellerVoucherPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isLoggedIn) {
        Provider.of<SellerVouchersProvider>(context, listen: false)
            .fetchVouchers(auth.user!.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final voucherProvider = Provider.of<SellerVouchersProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("My Marketing Vouchers"),
        backgroundColor: SwipifyTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: voucherProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : voucherProvider.vouchers.isEmpty
              ? _buildEmptyState()
              : _buildVoucherList(voucherProvider.vouchers),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showVoucherDialog(context),
        backgroundColor: SwipifyTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Create New", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.confirmation_number_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No Vouchers Yet",
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Start creating promotions to attract more customers",
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherList(List<VoucherModel> vouchers) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: vouchers.length,
      itemBuilder: (context, index) {
        return VoucherCard(voucher: vouchers[index]);
      },
    );
  }

  void _showVoucherDialog(BuildContext context, {VoucherModel? voucher}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VoucherFormDialog(voucher: voucher),
    );
  }
}

class VoucherCard extends StatelessWidget {
  final VoucherModel voucher;

  const VoucherCard({super.key, required this.voucher});

  @override
  Widget build(BuildContext context) {
    final expiryDate = voucher.endDate;
    final isExpired = expiryDate.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: voucher.isActive && !isExpired ? SwipifyTheme.primaryColor.withValues(alpha: 0.05) : Colors.grey[100],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: SwipifyTheme.primaryColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    voucher.code,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
                StatusBadge(isActive: voucher.isActive, isExpired: isExpired),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voucher.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            voucher.discountLabel,
                            style: TextStyle(
                              fontSize: 20, 
                              fontWeight: FontWeight.w900, 
                              color: SwipifyTheme.primaryColor,
                              letterSpacing: -0.5
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              voucher.discountTarget,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Min. Spend: ₱${voucher.minimumSpend}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            'Ends: ${DateFormat('MMM dd, yyyy').format(expiryDate)}',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                    Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                value: voucher.usageLimit > 0 ? voucher.claimedCount / voucher.usageLimit : 0,
                                strokeWidth: 4,
                                backgroundColor: Colors.grey[200],
                                color: SwipifyTheme.primaryColor,
                              ),
                            ),
                            Text(
                              voucher.usageLimit > 0 ? '${((voucher.claimedCount / voucher.usageLimit) * 100).toInt()}%' : '0%',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'CLAIMED',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        Text(
                          '${voucher.claimedCount}/${voucher.usageLimit}',
                          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _editVoucher(context),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text("Edit"),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  label: const Text("Delete", style: TextStyle(color: Colors.red)),
                ),
                Switch(
                  value: voucher.isActive,
                  onChanged: (val) => _toggleStatus(context, val),
                  activeThumbColor: SwipifyTheme.primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _editVoucher(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VoucherFormDialog(voucher: voucher),
    );
  }

  void _toggleStatus(BuildContext context, bool val) {
    Provider.of<SellerVouchersProvider>(context, listen: false)
        .updateVoucher(voucher.id, {'is_active': val});
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Voucher?"),
        content: const Text("This action cannot be undone. Customers will no longer be able to use this code."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              Provider.of<SellerVouchersProvider>(context, listen: false).deleteVoucher(voucher.id);
              Navigator.pop(context);
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final bool isActive;
  final bool isExpired;

  const StatusBadge({super.key, required this.isActive, required this.isExpired});

  @override
  Widget build(BuildContext context) {
    String text = "ACTIVE";
    Color color = Colors.green;
    
    if (isExpired) {
      text = "EXPIRED";
      color = Colors.red;
    } else if (!isActive) {
      text = "INACTIVE";
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class VoucherFormDialog extends StatefulWidget {
  final VoucherModel? voucher;

  const VoucherFormDialog({super.key, this.voucher});

  @override
  State<VoucherFormDialog> createState() => _VoucherFormDialogState();
}

class _VoucherFormDialogState extends State<VoucherFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeController;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _valueController;
  late TextEditingController _minOrderController;
  late TextEditingController _limitController;
  late String _discountType;
  late String _discountTarget;
  late DateTime _expiryDate;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final v = widget.voucher;
    _codeController = TextEditingController(text: v?.code ?? '');
    _titleController = TextEditingController(text: v?.title ?? '');
    _descriptionController = TextEditingController(text: v?.description ?? '');
    _valueController = TextEditingController(text: v?.discountValue.toString() ?? '');
    _minOrderController = TextEditingController(text: v?.minimumSpend.toString() ?? '0');
    _limitController = TextEditingController(text: v?.usageLimit.toString() ?? '100');
    _discountType = v?.discountType ?? 'percentage';
    _discountTarget = v?.discountTarget ?? 'SUBTOTAL';
    _expiryDate = v != null ? v.endDate : DateTime.now().add(const Duration(days: 30));
    _isActive = v?.isActive ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.voucher == null ? "Create New Voucher" : "Edit Voucher",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: "Voucher Code", hintText: "e.g. SUMMER2024"),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => v == null || v.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Title", hintText: "e.g. 10% Off Summer Sale"),
                validator: (v) => v == null || v.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: "Description", hintText: "e.g. Valid for all summer collection"),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _discountType,
                decoration: const InputDecoration(labelText: "Discount Type"),
                items: const [
                  DropdownMenuItem(value: "percentage", child: Text("Percentage (%)")),
                  DropdownMenuItem(value: "fixed", child: Text("Fixed Amount (₱)")),
                ],
                onChanged: (val) => setState(() => _discountType = val!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _discountTarget,
                decoration: const InputDecoration(labelText: "Discount Target"),
                items: const [
                  DropdownMenuItem(value: "SUBTOTAL", child: Text("Subtotal (Shop)")),
                  DropdownMenuItem(value: "SHIPPING", child: Text("Shipping Fee")),
                ],
                onChanged: (val) => setState(() => _discountTarget = val!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _valueController,
                decoration: InputDecoration(labelText: _discountType == "percentage" ? "Discount Percentage" : "Discount Amount"),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _minOrderController,
                decoration: const InputDecoration(labelText: "Minimum Order Amount"),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _limitController,
                decoration: const InputDecoration(labelText: "Usage Limit"),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Expiration Date"),
                subtitle: Text(DateFormat('MMMM dd, yyyy').format(_expiryDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _expiryDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) setState(() => _expiryDate = date);
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(backgroundColor: SwipifyTheme.primaryColor),
                  child: const Text("SAVE VOUCHER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final sellerId = auth.user!.uid;

    final data = {
      'seller_id': sellerId,
      'code': _codeController.text,
      'title': _titleController.text,
      'description': _descriptionController.text,
      'discount_type': _discountType,
      'discount_target': _discountTarget,
      'discount_value': double.parse(_valueController.text),
      'minimum_spend': double.parse(_minOrderController.text),
      'usage_limit': int.parse(_limitController.text),
      'remaining_quantity': int.parse(_limitController.text), // initially same as limit
      'end_date': _expiryDate.toIso8601String(),
      'is_active': _isActive,
    };

    final provider = Provider.of<SellerVouchersProvider>(context, listen: false);
    if (widget.voucher == null) {
      provider.createVoucher(data);
    } else {
      provider.updateVoucher(widget.voucher!.id, data);
    }

    Navigator.pop(context);
  }
}
