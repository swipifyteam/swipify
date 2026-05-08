import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/models/voucher_model.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/profile/service/user_provider.dart';

class VoucherCard extends StatefulWidget {
  final VoucherModel voucher;

  final double? width;
  final EdgeInsetsGeometry? margin;

  const VoucherCard({
    super.key, 
    required this.voucher,
    this.width,
    this.margin,
  });

  @override
  State<VoucherCard> createState() => _VoucherCardState();
}

class _VoucherCardState extends State<VoucherCard> {
  bool _claiming = false;

  Future<void> _handleClaim() async {
    final auth = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    
    if (!auth.isLoggedIn || auth.user?.uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to claim vouchers')),
      );
      return;
    }

    setState(() => _claiming = true);
    try {
      await userProvider.claimVoucher(auth.user!.uid, widget.voucher.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voucher "${widget.voucher.code}" collected!'),
            backgroundColor: SwipifyTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProv, _) {
        // Use either the model's isClaimed or the provider's local state
        final isClaimed = widget.voucher.isClaimed || userProv.isVoucherClaimed(widget.voucher.id);
        final isOutOfStock = widget.voucher.remainingQuantity <= 0;
        
        return Container(
          width: widget.width,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: SwipifyTheme.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SwipifyTheme.borderColor),
            boxShadow: SwipifyTheme.glassShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Left discount part
                  Container(
                    width: 80,
                    color: SwipifyTheme.accentColor.withValues(alpha: 0.1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.confirmation_num_outlined, color: SwipifyTheme.accentColor, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          widget.voucher.discountType == 'fixed' 
                              ? '₱${widget.voucher.discountValue.toStringAsFixed(0)} OFF'
                              : '${widget.voucher.discountValue.toStringAsFixed(0)}% OFF',
                          style: GoogleFonts.inter(
                            color: SwipifyTheme.accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  // Dashed divider line (visual simulation)
                  Container(
                    width: 1,
                    color: SwipifyTheme.borderColor,
                  ),
                  // Right detail part
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.voucher.code,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: SwipifyTheme.textPrimary,
                                  letterSpacing: 1,
                                ),
                              ),
                              if (!isClaimed) Text(
                                '${widget.voucher.remainingQuantity} left',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  color: isOutOfStock ? Colors.red : SwipifyTheme.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.voucher.minimumSpend > 0 
                              ? 'Min. spend ₱${widget.voucher.minimumSpend.toStringAsFixed(0)}'
                              : 'No minimum spend',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: SwipifyTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: _buildClaimButton(isClaimed, isOutOfStock),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildClaimButton(bool isClaimed, bool isOutOfStock) {
    if (_claiming) {
      return const SizedBox(
        width: 14, height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: SwipifyTheme.accentColor),
      );
    }

    final String label = isClaimed ? 'Claimed' : (isOutOfStock ? 'Sold Out' : 'Claim');
    final bool isDisabled = isClaimed || isOutOfStock;

    return GestureDetector(
      onTap: isDisabled ? null : _handleClaim,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isDisabled ? SwipifyTheme.borderColor : SwipifyTheme.primaryColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isDisabled ? SwipifyTheme.textSecondary : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}
