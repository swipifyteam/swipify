// lib/features/seller/presentation/pages/marketing/loyalty_points_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/seller/service/seller_provider.dart';

class LoyaltyPointsPage extends StatefulWidget {
  const LoyaltyPointsPage({super.key});

  @override
  State<LoyaltyPointsPage> createState() => _LoyaltyPointsPageState();
}

class _LoyaltyPointsPageState extends State<LoyaltyPointsPage> {
  bool _isLoading = true;
  bool _isEnabled = false;
  final _pointsCtrl = TextEditingController(text: '0.01');
  final _minRedeemCtrl = TextEditingController(text: '10');

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final auth = context.read<AuthProvider>();
    final sp = context.read<SellerProvider>();
    if (auth.user == null) return;

    final config = await sp.getLoyaltyConfig(auth.user!.uid);
    if (mounted && config != null) {
      setState(() {
        _isEnabled = config['is_enabled'] ?? false;
        _pointsCtrl.text = (config['points_per_peso'] ?? 0.01).toString();
        _minRedeemCtrl.text = (config['min_redeem_points'] ?? 10).toString();
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pointsCtrl.dispose();
    _minRedeemCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('Loyalty Points'),
        backgroundColor: SwipifyTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildConfigCard(),
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rate_rounded, color: Color(0xFF27AE60), size: 32),
            const SizedBox(width: 12),
            Text('Reward Your Customers',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Encourage repeat purchases by rewarding customers with points for every peso spent.',
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6B7A8D)),
        ),
      ],
    );
  }

  Widget _buildConfigCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E4E9)),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: Text('Enable Loyalty Program',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            subtitle: const Text('Customers will start earning points'),
            value: _isEnabled,
            onChanged: (v) => setState(() => _isEnabled = v),
            activeThumbColor: const Color(0xFF27AE60),
          ),
          const Divider(height: 32),
          _buildInputRow(
            label: 'Points per Peso',
            sub: 'Example: 0.01 means 1 point for every ₱100 spend',
            controller: _pointsCtrl,
            icon: Icons.monetization_on_outlined,
          ),
          const SizedBox(height: 20),
          _buildInputRow(
            label: 'Min Points to Redeem',
            sub: 'Example: 10 points minimum to use in checkout',
            controller: _minRedeemCtrl,
            icon: Icons.redeem_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow({required String label, required String sub, required TextEditingController controller, required IconData icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(sub, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: const Color(0xFFF4F6F8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: SwipifyTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text('Save Configuration',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Future<void> _saveChanges() async {
    final auth = context.read<AuthProvider>();
    final sp = context.read<SellerProvider>();
    
    final success = await sp.saveLoyaltyConfig({
      'seller_id': auth.user!.uid,
      'is_enabled': _isEnabled,
      'points_per_peso': double.tryParse(_pointsCtrl.text) ?? 0.01,
      'min_redeem_points': int.tryParse(_minRedeemCtrl.text) ?? 10,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ Loyalty config saved' : '❌ Failed to save config'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
