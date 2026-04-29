// lib/screens/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/cart/service/cart_provider.dart';
import 'package:swipify/features/cart/model/cart_item_model.dart';
import 'package:swipify/features/checkout/service/checkout_provider.dart';
import 'package:swipify/widgets/checkout/address_selection_widget.dart';
import 'package:swipify/widgets/checkout/shipping_options_selection_widget.dart';
import 'package:swipify/screens/order_success_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final CheckoutProvider _checkoutProvider;
  bool _initialized = false;
  bool _showAllItems = false;

  @override
  void initState() {
    super.initState();
    _checkoutProvider = CheckoutProvider();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? '';

      // Try to get selected items from navigation arguments
      final args = ModalRoute.of(context)?.settings.arguments;
      final List<CartItemModel> itemsToCheckout = (args is List<CartItemModel>) 
          ? args 
          : cartProvider.items;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkoutProvider.setCartItems(userId, itemsToCheckout);
        }
      });
    }
  }

  @override
  void dispose() {
    _checkoutProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? '';

    return ChangeNotifierProvider.value(
      value: _checkoutProvider,
      child: Scaffold(
        backgroundColor: SwipifyTheme.backgroundColor,
        appBar: AppBar(
          title: const Text(
            'Checkout',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          backgroundColor: SwipifyTheme.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline_rounded, size: 22),
              onPressed: () {},
            ),
          ],
        ),
        body: Consumer<CheckoutProvider>(
          builder: (context, provider, _) {
            if (!provider.isInitialized) {
              return const Center(
                child: CircularProgressIndicator(color: SwipifyTheme.primaryColor),
              );
            }

            return Stack(
              children: [
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AddressSelectionWidget(),
                            const SizedBox(height: 24),

                            _buildSectionHeader('Order Items', Icons.shopping_bag_rounded),
                            _buildItemsList(provider),
                            const SizedBox(height: 24),

                            ShippingOptionsSelectionWidget(cartItems: provider.cartItems),
                            const SizedBox(height: 12),

                            _buildSelectionRow(
                              title: 'Payment Method',
                              subtitle: _getPaymentName(provider.selectedPaymentMethod),
                              icon: Icons.account_balance_wallet_rounded,
                              onTap: () => _showPaymentModal(context, provider),
                            ),
                            const SizedBox(height: 12),

                            _buildSelectionRow(
                              title: 'Vouchers',
                              subtitle: _getVouchersSubtitle(provider),
                              icon: Icons.discount_rounded,
                              onTap: () => _showVouchersModal(context, provider),
                            ),
                            const SizedBox(height: 24),

                            _buildSectionHeader('Order Summary', Icons.receipt_long_rounded),
                            _buildOrderSummary(provider),

                            if (provider.errorMessage != null)
                              _buildErrorBanner(provider.errorMessage!),
                            
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                if (provider.isPlacingOrder)
                  Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: SwipifyTheme.primaryColor),
                            SizedBox(height: 16),
                            Text(
                              'Placing Order...',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildBottomActionBar(provider, userId),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: SwipifyTheme.primaryColor),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: SwipifyTheme.primaryColor,
            ),
          ),
          if (action != null) ...[
            const Spacer(),
            action,
          ],
        ],
      ),
    );
  }

  Widget _buildItemsList(CheckoutProvider provider) {
    final displayItems = _showAllItems 
        ? provider.cartItems 
        : provider.cartItems.take(3).toList();
    
    return Container(
      decoration: BoxDecoration(
        color: SwipifyTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayItems.length,
            separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.withValues(alpha: 0.08)),
            itemBuilder: (_, index) {
              final item = displayItems[index];
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                        image: DecorationImage(
                          image: NetworkImage(item.imageUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 14, 
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Qty: ${item.quantity}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₱${(item.price * item.quantity).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800, 
                        fontSize: 14,
                        color: SwipifyTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (provider.cartItems.length > 3)
            InkWell(
              onTap: () => setState(() => _showAllItems = !_showAllItems),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.transparent),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _showAllItems ? 'Show Less' : 'Show all ${provider.cartItems.length} items',
                      style: const TextStyle(
                        fontSize: 13, 
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    Icon(
                      _showAllItems ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 20,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectionRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
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
              child: Icon(icon, color: SwipifyTheme.primaryColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String _getPaymentName(String? methodId) {
    if (methodId == 'cod') return 'Cash on Delivery';
    if (methodId == 'gcash') return 'GCash';
    if (methodId == 'card') return 'Credit / Debit Card';
    return 'Select Payment Method';
  }

  String _getVouchersSubtitle(CheckoutProvider provider) {
    int appliedCount = (provider.appliedShippingVoucher != null ? 1 : 0) + provider.appliedShopVouchers.length;
    if (appliedCount > 0) return '$appliedCount Applied';
    return provider.availableVouchers.isNotEmpty 
        ? '${provider.availableVouchers.length} Available' 
        : 'No Vouchers Available';
  }

  void _showPaymentModal(BuildContext context, CheckoutProvider provider) {
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
                'Select Payment Method',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 20),
              _buildPaymentOption(
                provider: provider,
                title: 'Cash on Delivery',
                subtitle: 'Pay when you receive your order',
                icon: Icons.payments_rounded,
                color: Colors.green,
                methodId: 'cod',
                ctx: ctx,
              ),
              const SizedBox(height: 12),
              _buildPaymentOption(
                provider: provider,
                title: 'GCash',
                subtitle: 'Pay via GCash E-Wallet',
                icon: Icons.account_balance_wallet_rounded,
                color: Colors.blue,
                methodId: 'gcash',
                ctx: ctx,
              ),
              const SizedBox(height: 12),
              _buildPaymentOption(
                provider: provider,
                title: 'Credit / Debit Card',
                subtitle: 'Pay via Visa or Mastercard',
                icon: Icons.credit_card_rounded,
                color: Colors.orange,
                methodId: 'card',
                ctx: ctx,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentOption({
    required CheckoutProvider provider,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String methodId,
    required BuildContext ctx,
  }) {
    final isSelected = provider.selectedPaymentMethod == methodId;
    return InkWell(
      onTap: () {
        provider.selectPaymentMethod(methodId);
        Navigator.pop(ctx);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? SwipifyTheme.primaryColor.withValues(alpha: 0.04) : SwipifyTheme.white,
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
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, 
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  Text(
                    subtitle, 
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: SwipifyTheme.primaryColor, size: 24),
          ],
        ),
      ),
    );
  }

  void _showVouchersModal(BuildContext context, CheckoutProvider provider) {
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
                'Select Voucher',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: provider.availableVouchers.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: SwipifyTheme.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.1), style: BorderStyle.solid),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.confirmation_number_outlined, size: 32, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              const Text(
                                'No vouchers available for this order',
                                style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: provider.availableVouchers.map((v) {
                            bool isApplied = false;
                            if (v.discountTarget == 'SHIPPING') {
                              isApplied = provider.appliedShippingVoucher?.voucherId == v.id;
                            } else {
                              isApplied = provider.appliedShopVouchers.containsKey(v.sellerId) &&
                                  provider.appliedShopVouchers[v.sellerId]!.voucherId == v.id;
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  isApplied
                                      ? provider.removeVoucher(v.sellerId ?? '')
                                      : provider.applyVoucher(v.sellerId ?? '', v.code);
                                  Navigator.pop(ctx);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isApplied ? SwipifyTheme.primaryColor.withValues(alpha: 0.04) : SwipifyTheme.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isApplied ? SwipifyTheme.primaryColor : Colors.grey.withValues(alpha: 0.1),
                                      width: isApplied ? 1.5 : 1,
                                    ),
                                    boxShadow: isApplied ? [] : [
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
                                        child: Icon(
                                          v.discountTarget == 'SHIPPING'
                                              ? Icons.local_shipping_rounded
                                              : Icons.discount_rounded,
                                          color: SwipifyTheme.primaryColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              v.code, 
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                            ),
                                            Text(
                                              v.discountLabel,
                                              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isApplied)
                                        const Icon(Icons.check_circle_rounded, color: SwipifyTheme.primaryColor, size: 24)
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: SwipifyTheme.primaryColor.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Text(
                                            'APPLY',
                                            style: TextStyle(
                                              color: SwipifyTheme.primaryColor,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderSummary(CheckoutProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SwipifyTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _summaryRow('Merchandise Subtotal', provider.subtotal),
          _summaryRow('Shipping Fee', provider.backendShippingFee + provider.shippingDiscount),
          if (provider.shopDiscounts > 0)
            _summaryRow('Shop Vouchers', -provider.shopDiscounts, isDiscount: true),
          if (provider.shippingDiscount > 0)
            _summaryRow('Shipping Discount', -provider.shippingDiscount, isDiscount: true),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Payment', 
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              Text(
                '₱${provider.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900, 
                  fontSize: 22, 
                  color: SwipifyTheme.primaryColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label, 
            style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500),
          ),
          Text(
            '${isDiscount ? "-" : ""}₱${value.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: isDiscount ? FontWeight.w700 : FontWeight.w600,
              color: isDiscount ? Colors.red[700] : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red[700], size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message, 
              style: TextStyle(
                color: Colors.red[800], 
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(CheckoutProvider provider, String userId) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: SwipifyTheme.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Amount', 
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₱${provider.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.w900, 
                      color: SwipifyTheme.primaryColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              height: 58,
              width: 180,
              child: ElevatedButton(
                onPressed: (provider.isPlacingOrder || provider.cartItems.isEmpty || provider.selectedAddress == null)
                    ? null
                    : () async {
                        final result = await provider.placeOrder(userId);
                        if (!mounted) return;
                        
                        if (result == 'cod') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const OrderSuccessScreen()),
                          );
                        } else if (result != null && result.isNotEmpty) {
                          // It's a checkout URL, launch it
                          final Uri url = Uri.parse(result);
                          final bool launched = await launchUrl(url, mode: LaunchMode.externalApplication);
                          if (!mounted) return;

                          if (!launched) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not launch payment page')),
                            );
                          } else {
                            // After returning from payment, we might want to navigate to a pending orders or success screen
                            // For now we assume they completed it or closed the browser.
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const OrderSuccessScreen()),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: SwipifyTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: SwipifyTheme.primaryColor.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: provider.isPlacingOrder
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'PLACE ORDER',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
