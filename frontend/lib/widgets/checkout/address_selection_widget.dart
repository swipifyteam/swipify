import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/models/address_model.dart';
import 'package:swipify/services/address_service.dart';
import 'package:swipify/features/checkout/service/checkout_provider.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';

class AddressSelectionWidget extends StatefulWidget {
  const AddressSelectionWidget({super.key});

  @override
  State<AddressSelectionWidget> createState() => _AddressSelectionWidgetState();
}

class _AddressSelectionWidgetState extends State<AddressSelectionWidget> {
  List<AddressModel> _addresses = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? '';
      _addresses = await AddressService.getAddresses(userId);
      if (_addresses.isNotEmpty) {
        Future.microtask(() {
          if (mounted) {
            Provider.of<CheckoutProvider>(context, listen: false)
                .selectAddress(_addresses.first);
          }
        });
      }
    } catch (e) {
      _errorMessage = 'Failed to load addresses: $e';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddressPicker() {
    if (_addresses.length <= 1) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final selectedId = Provider.of<CheckoutProvider>(context, listen: false)
            .selectedAddress?.id;
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Select Delivery Address',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _addresses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final addr = _addresses[i];
                    final isSelected = addr.id == selectedId;
                    return InkWell(
                      onTap: () {
                        Provider.of<CheckoutProvider>(context, listen: false).selectAddress(addr);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? SwipifyTheme.primaryColor.withValues(alpha: 0.04) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? SwipifyTheme.primaryColor : Colors.grey.withValues(alpha: 0.1),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              color: isSelected ? SwipifyTheme.primaryColor : Colors.grey[400],
                              size: 22,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    addr.fullName,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    addr.phone,
                                    style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    addr.fullAddress,
                                    style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.4),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedAddress = context.select<CheckoutProvider, AddressModel?>(
      (p) => p.selectedAddress,
    );

    if (_isLoading) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: SwipifyTheme.primaryColor),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red[700], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red[800], fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    if (_addresses.isEmpty || selectedAddress == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_location_alt_rounded, color: Colors.orange, size: 24),
            ),
            const SizedBox(height: 12),
            const Text(
              'No delivery address found',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Please add one in your profile.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _addresses.length > 1 ? _showAddressPicker : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SwipifyTheme.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SwipifyTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_on_rounded, color: SwipifyTheme.primaryColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    selectedAddress.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ],
              ),
            ),
            if (_addresses.length > 1)
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
