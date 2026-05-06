import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/cart/service/cart_provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/orders/model/order_model.dart';
import 'package:swipify/features/orders/tracking_screen.dart';

class OrderDetailsScreen extends StatelessWidget {
  final OrderModel order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwipifyTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: SwipifyTheme.backgroundColor,
        iconTheme: const IconThemeData(color: SwipifyTheme.textPrimary),
        title: Text(
          'Order Details',
          style: SwipifyTheme.heading2.copyWith(fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(),
            const SizedBox(height: 32),
            _buildSection(
              title: 'Shipping Address',
              child: _buildAddressInfo(),
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Order Items',
              child: _buildItemsList(),
            ),
            const SizedBox(height: 24),
            if (order.trackingNumber != null) ...[
              _buildSection(
                title: 'Logistics Info',
                child: _buildLogisticsInfo(context),
              ),
              const SizedBox(height: 24),
            ],
            _buildSection(
              title: 'Payment Details',
              child: _buildPaymentSummary(),
            ),
            const SizedBox(height: 40),
            _buildActionButtons(context),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFD4AF37), // Gold
            Color(0xFFB8860B), // Dark Goldenrod
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STATUS',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.formattedStatus.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.verified_rounded, color: Colors.white, size: 40),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '#${order.id.toUpperCase()}',
              style: GoogleFonts.jetBrainsMono(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800, 
            fontSize: 12, 
            color: SwipifyTheme.textPrimary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: SwipifyTheme.glassShadow,
            border: Border.all(color: SwipifyTheme.borderColor),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildAddressInfo() {
    final addr = order.shippingAddress;
    if (addr == null) return Text('No address info', style: GoogleFonts.inter(color: SwipifyTheme.textSecondary));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          addr['receiver_name'] ?? 'Recipient', 
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: SwipifyTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.phone_rounded, size: 14, color: SwipifyTheme.textSecondary),
            const SizedBox(width: 8),
            Text(
              addr['phone_number'] ?? 'No phone',
              style: GoogleFonts.inter(color: SwipifyTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on_rounded, size: 14, color: SwipifyTheme.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${addr['address_line1']}, ${addr['city']}, ${addr['postal_code']}',
                style: GoogleFonts.inter(color: SwipifyTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500, height: 1.4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildItemsList() {
    return Column(
      children: order.items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: item.imageUrl ?? '',
                  width: 60, height: 60,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: SwipifyTheme.backgroundColor),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name, 
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: SwipifyTheme.textPrimary), 
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₱${item.price.toStringAsFixed(2)} × ${item.quantity}', 
                      style: GoogleFonts.inter(color: SwipifyTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Text(
                '₱${(item.price * item.quantity).toStringAsFixed(2)}', 
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: SwipifyTheme.textPrimary),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLogisticsInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_shipping_rounded, size: 16, color: SwipifyTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              order.logisticProvider ?? 'TBA', 
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: SwipifyTheme.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (order.trackingNumber != null && (order.status.toLowerCase() == 'shipped' || order.status.toLowerCase() == 'in_transit' || order.status.toLowerCase() == 'out_for_delivery'))
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TrackingScreen(
                      orderId: order.id,
                      trackingNumber: order.trackingNumber!,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: SwipifyTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.map_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'TRACK ORDER',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: SwipifyTheme.backgroundColor, 
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    order.trackingNumber ?? '-', 
                    style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, color: SwipifyTheme.textPrimary, fontSize: 13),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: order.trackingNumber ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
                  },
                  child: Text(
                    'COPY',
                    style: GoogleFonts.inter(color: SwipifyTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentSummary() {
    final subtotal = order.items.fold(0.0, (sum, i) => sum + i.price * i.quantity);
    final shippingFee = order.shippingFee ?? 0.0;
    final discount = order.discountAmount ?? 0.0;

    return Column(
      children: [
        _summaryRow('Subtotal', subtotal),
        _summaryRow('Shipping Fee', shippingFee),
        _summaryRow('Discount', -discount, isDiscount: true),
        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: SwipifyTheme.borderColor)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('TOTAL', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: SwipifyTheme.textPrimary, letterSpacing: 1)),
            Text(
              '₱${order.totalPrice.toStringAsFixed(2)}',
              style: GoogleFonts.inter(color: SwipifyTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.5),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Paid via Credit Card',
            style: GoogleFonts.inter(fontSize: 11, color: SwipifyTheme.textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, double value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: SwipifyTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          Text(
            '${isDiscount ? "-" : ""}₱${value.abs().toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              color: isDiscount ? Colors.red : SwipifyTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final date = order.createdAt != null ? DateTime.parse(order.createdAt!) : DateTime.now();
    
    return Column(
      children: [
        Text(
          'Purchased on ${DateFormat('MMMM dd, yyyy • HH:mm').format(date)}',
          style: GoogleFonts.inter(color: SwipifyTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: () async {
            final userId = context.read<AuthProvider>().user?.uid;
            if (userId != null) {
              final items = order.items.map((i) => {
                'productId': i.productId,
                'quantity': i.quantity,
              }).toList();
              await context.read<CartProvider>().reorderItems(userId, items);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart!')));
              }
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: SwipifyTheme.primaryColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: SwipifyTheme.primaryColor.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Center(
              child: Text(
                'RE-ORDER ITEMS',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 60),
            side: const BorderSide(color: SwipifyTheme.borderColor, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Text(
            'CONTACT SUPPORT',
            style: GoogleFonts.inter(color: SwipifyTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

