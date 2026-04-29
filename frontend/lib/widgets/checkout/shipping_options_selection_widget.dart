import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/models/shipping_option_model.dart';
import 'package:swipify/features/checkout/service/checkout_provider.dart';
import 'package:swipify/features/cart/model/cart_item_model.dart';
import 'package:swipify/services/shipping_service.dart';

class ShippingOptionsSelectionWidget extends StatefulWidget {
  final List<CartItemModel> cartItems;

  const ShippingOptionsSelectionWidget({super.key, required this.cartItems});

  @override
  State<ShippingOptionsSelectionWidget> createState() =>
      _ShippingOptionsSelectionWidgetState();
}

class _ShippingOptionsSelectionWidgetState
    extends State<ShippingOptionsSelectionWidget> {
  List<ShippingOptionModel> _shippingOptions = [];
  bool _isLoadingOptions = false;
  String? _optionsErrorMessage;
  String? _lastFetchedAddressId;

  CheckoutProvider? _provider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newProvider = Provider.of<CheckoutProvider>(context, listen: false);
    if (_provider != newProvider) {
      _provider?.removeListener(_onProviderChange);
      _provider = newProvider;
      _provider!.addListener(_onProviderChange);
    }
    _onProviderChange();
  }

  void _onProviderChange() {
    if (!mounted) return;
    final currentAddressId = _provider?.selectedAddress?.id;
    if (currentAddressId != null &&
        currentAddressId != _lastFetchedAddressId &&
        !_isLoadingOptions) {
      _lastFetchedAddressId = currentAddressId;
      Future.microtask(() {
        if (mounted) _fetchShippingOptions();
      });
    }
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderChange);
    super.dispose();
  }

  Future<void> _fetchShippingOptions() async {
    if (_isLoadingOptions || !mounted) return;

    setState(() {
      _isLoadingOptions = true;
      _optionsErrorMessage = null;
      _shippingOptions = [];
    });

    try {
      final options = await ShippingService.getShippingOptions();
      if (!mounted) return;
      setState(() => _shippingOptions = options);
      if (options.isNotEmpty) {
        _provider?.selectShippingOption(options.first);
      }
    } catch (e) {
      if (!mounted) return;
      setState(
          () => _optionsErrorMessage = 'Failed to load shipping options: $e');
    } finally {
      if (mounted) setState(() => _isLoadingOptions = false);
    }
  }

  void _showShippingModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
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
                'Select Shipping Method',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: _buildModalContent(ctx),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalContent(BuildContext ctx) {
    final selectedOptionId = _provider?.selectedShippingOption?.id;
    final hasAddress = _provider?.selectedAddress != null;

    if (!hasAddress) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.grey[400], size: 22),
            const SizedBox(width: 14),
            Text(
              'Select a delivery address first',
              style: TextStyle(fontSize: 14, color: Colors.grey[500], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (_isLoadingOptions) {
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

    if (_optionsErrorMessage != null) {
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
                _optionsErrorMessage!,
                style: TextStyle(color: Colors.red[800], fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    if (_shippingOptions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.local_shipping_outlined, color: Colors.grey[400], size: 22),
            const SizedBox(width: 14),
            Text(
              'No shipping options available',
              style: TextStyle(fontSize: 14, color: Colors.grey[500], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(_shippingOptions.length, (i) {
        final option = _shippingOptions[i];
        final isSelected = selectedOptionId == option.id;

        return Padding(
          padding: EdgeInsets.only(bottom: i < _shippingOptions.length - 1 ? 12 : 0),
          child: InkWell(
            onTap: () {
              _provider?.selectShippingOption(option);
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
                boxShadow: isSelected ? [] : [
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
                      color: isSelected ? SwipifyTheme.primaryColor.withValues(alpha: 0.1) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.local_shipping_rounded,
                      color: isSelected ? SwipifyTheme.primaryColor : Colors.grey[500],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: isSelected ? SwipifyTheme.primaryColor : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          option.estimatedDelivery,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₱${option.fee.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: isSelected ? SwipifyTheme.primaryColor : Colors.black87,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.check_circle_rounded, color: SwipifyTheme.primaryColor, size: 24),
                  ],
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedOption = context.select<CheckoutProvider, ShippingOptionModel?>(
      (p) => p.selectedShippingOption,
    );

    return InkWell(
      onTap: _showShippingModal,
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
              child: const Icon(Icons.local_shipping_rounded, color: SwipifyTheme.primaryColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Shipping Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    selectedOption?.name ?? 'Select Shipping Method',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ],
              ),
            ),
            if (selectedOption != null)
              Text(
                '₱${selectedOption.fee.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: SwipifyTheme.primaryColor),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
