// lib/features/cart/screen/cart_screen.dart
// Cart Screen for Swipify.
// 🚨 PART 1, 2, 4, 6 FIXES 🚨
// - Real Product Data (Name, Price)
// - Cloudinary Images
// - No fake data (coins, wallet, vouchers)
// - No infinite loading after checkout

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipify/features/cart/service/cart_provider.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/cart/widget/cart_item_tile.dart';
import 'package:swipify/screens/checkout_screen.dart';
import 'package:swipify/core/theme.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCart();
    });
  }

  void _refreshCart() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isLoggedIn) {
      Provider.of<CartProvider>(context, listen: false).fetchCart(auth.user!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    // 🚨 AUTH CHECK 🚨
    if (!auth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text("Shopping Cart")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_cart_outlined, size: 60, color: Colors.grey),
              const SizedBox(height: 16),
              const Text("Please login to see your cart", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SwipifyTheme.backgroundColor,
      appBar: AppBar(
        title: const Text("Shopping Cart"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshCart,
          ),
        ],
      ),
      body: cart.isLoading && cart.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : cart.items.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // SELECT ALL SECTION
                    if (cart.items.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: cart.selectedItemIds.length == cart.items.length && cart.items.isNotEmpty,
                              onChanged: (val) => cart.toggleSelectAll(val ?? false),
                              activeColor: SwipifyTheme.primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            const Text(
                              "Select All",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const Spacer(),
                            Text(
                              "${cart.selectedItemIds.length}/${cart.items.length} items",
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          ],
                        ),
                      ),

                    // CART ITEMS LIST
                    Expanded(
                      child: ListView.builder(
                        itemCount: cart.items.length,
                        itemBuilder: (context, index) {
                          final item = cart.items[index];
                          return CartItemTile(
                            item: item,
                            isSelected: cart.isSelected(item.productId),
                            onToggleSelection: (val) => cart.toggleSelection(item.productId),
                            onIncrement: () => cart.updateQuantity(
                              auth.user!.uid, item.productId, item.quantity + 1),
                            onDecrement: () {
                              if (item.quantity > 1) {
                                cart.updateQuantity(auth.user!.uid, item.productId, item.quantity - 1);
                              }
                            },
                            onRemove: () => cart.removeItem(auth.user!.uid, item.productId),
                          );
                        },
                      ),
                    ),
                    
                    // TOTAL & CHECKOUT SECTION
                    _buildCheckoutSection(context, cart, auth),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
     return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: 0.5,
              child: Icon(Icons.shopping_bag_outlined, size: 100, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            const Text(
              "Your cart is empty",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              "Start swiping to find something you love!",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
  }

  Widget _buildCheckoutSection(BuildContext context, CartProvider cart, AuthProvider auth) {
    final selectedCount = cart.selectedItemIds.length;
    final canCheckout = selectedCount > 0 && !cart.isLoading;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Total",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "₱${cart.selectedTotal.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: SwipifyTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  "$selectedCount items selected",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: !canCheckout
                  ? null 
                  : () async {
                      debugPrint("[CART] Navigating to CheckoutScreen with $selectedCount selected items");
                      
                      // PASS ONLY SELECTED ITEMS
                      final selectedItems = cart.selectedItems;
                      
                      final result = await Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => const CheckoutScreen(),
                          settings: RouteSettings(arguments: selectedItems),
                        )
                      );

                      if (result == true) {
                        _refreshCart();
                      }
                    },
                style: ElevatedButton.styleFrom(
                  backgroundColor: SwipifyTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: cart.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text("Checkout ($selectedCount)"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

