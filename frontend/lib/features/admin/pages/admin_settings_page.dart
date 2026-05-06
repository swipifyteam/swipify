import 'package:flutter/material.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/services/admin_settings_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final settings = await AdminSettingsService.getSettings();
      setState(() {
        _settings = settings;
        _commissionController.text = (settings['commission_rate'] * 100).toString();
        _thresholdController.text = settings['payout_threshold'].toString();
        _emailController.text = settings['support_email'];
        _isLoading = false;
      });
    } catch (e) {
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
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform Settings', style: SwipifyTheme.heading1),
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
                const SizedBox(height: 16),
                _buildTextField(
                  'Payout Threshold (₱)',
                  _thresholdController,
                  'Minimum balance before a seller can request a payout',
                  isNumeric: true,
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            _buildSection(
              'System Configuration',
              [
                _buildTextField(
                  'Support Email',
                  _emailController,
                  'Primary contact email for platform issues',
                ),
                const SizedBox(height: 24),
                SwitchListTile(
                  title: const Text('Maintenance Mode'),
                  subtitle: const Text('Prevent users from accessing the storefront while active'),
                  value: _settings['maintenance_mode'] ?? false,
                  onChanged: (value) {
                    setState(() {
                      _settings['maintenance_mode'] = value;
                    });
                  },
                  activeThumbColor: SwipifyTheme.primaryColor,
                ),
              ],
            ),
            
            const SizedBox(height: 48),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SwipifyTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: SwipifyTheme.heading2),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, {bool isNumeric = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: label,
        helperText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter a value';
        if (isNumeric && double.tryParse(value) == null) return 'Please enter a valid number';
        return null;
      },
    );
  }
}
