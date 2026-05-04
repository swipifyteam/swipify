import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipify/features/checkout/service/checkout_provider.dart';

class OrderSummaryWidget extends StatelessWidget {
  const OrderSummaryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // context.select rebuilds only when these specific values change
    final subtotal = context.select<CheckoutProvider, double>((p) => p.subtotal);
    final shippingFee = context.select<CheckoutProvider, double>((p) => p.backendShippingFee);
    final shopDiscounts = context.select<CheckoutProvider, double>((p) => p.shopDiscounts);
    final shippingDiscount = context.select<CheckoutProvider, double>((p) => p.shippingDiscount);
    final total = context.select<CheckoutProvider, double>((p) => p.total);
    final totalDiscount = shopDiscounts + shippingDiscount;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal:'),
              Text('₱${subtotal.toStringAsFixed(2)}'),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Shipping:'),
              Text('₱${shippingFee.toStringAsFixed(2)}'),
            ],
          ),
          if (totalDiscount > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Discount:', style: TextStyle(color: Colors.green)),
                Text(
                  '-₱${totalDiscount.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.green),
                ),
              ],
            ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total:', style: Theme.of(context).textTheme.titleLarge),
              Text('₱${total.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ],
      ),
    );
  }
}
