import 'package:flutter/material.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/services/admin_settings_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swipify/core/utils/responsive_helper.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic> _settings = {};
  String? _error;

  final _formKey = GlobalKey<FormState>();
  final _commissionController = TextEditingController();
  final _thresholdController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final settings = await AdminSettingsService.getSettings();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _commissionController.text = (settings['commission_rate'] * 100).toString();
        _thresholdController.text = settings['payout_threshold'].toString();
        _emailController.text = settings['support_email'];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final updatedSettings = {
        'commission_rate': double.parse(_commissionController.text) / 100,
        'payout_threshold': double.parse(_thresholdController.text),
        'support_email': _emailController.text,
        'maintenance_mode': _settings['maintenance_mode'],
      };

      await AdminSettingsService.updateSettings(updatedSettings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));

    final bool isMobile = ResponsiveHelper.isMobile(context);
    final double horizontalPadding = isMobile ? 16.0 : 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform Settings', style: isMobile ? SwipifyTheme.heading2 : SwipifyTheme.heading1),
            const SizedBox(height: 32),
            
            _buildSection(
              'Financial Configuration',
              [
                _buildTextField(
                  'Commission Rate (%)',
                  _commissionController,
                  'Percentage taken from each sale',
                  isNumeric: true,
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  'Payout Threshold (₱)',
                  _thresholdController,
                  'Minimum balance before a seller can request a payout',
                  isNumeric: true,
                ),
              ],
              isMobile,
            ),
            
            const SizedBox(height: 24),
            _buildSection(
              'System Configuration',
              [
                _buildTextField(
                  'Support Email',
                  _emailController,
                  'Primary contact email for platform issues',
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: SwitchListTile(
                    title: const Text('Maintenance Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Prevent users from accessing the storefront while active', style: TextStyle(fontSize: 12)),
                    value: _settings['maintenance_mode'] ?? false,
                    onChanged: (value) {
                      setState(() {
                        _settings['maintenance_mode'] = value;
                      });
                    },
                    activeThumbColor: SwipifyTheme.primaryColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
              isMobile,
            ),
            
            const SizedBox(height: 40),
            Center(
              child: SizedBox(
                width: isMobile ? double.infinity : 250,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SwipifyTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: SwipifyTheme.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(title, style: SwipifyTheme.heading2.copyWith(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, {bool isNumeric = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.emailAddress,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: SwipifyTheme.primaryColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'This field is required';
            if (isNumeric && double.tryParse(value) == null) return 'Please enter a valid number';
            return null;
          },
        ),
        const SizedBox(height: 4),
        Text(hint, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      ],
    );
  }
}
