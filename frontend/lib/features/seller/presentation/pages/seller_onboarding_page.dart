// lib/features/seller/presentation/pages/seller_onboarding_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipify/features/seller/service/seller_provider.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/core/utils/phone_utils.dart';
import 'package:flutter/services.dart';

import 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:image_picker/image_picker.dart';

class SellerOnboardingPage extends StatefulWidget {
  const SellerOnboardingPage({super.key});

  @override
  State<SellerOnboardingPage> createState() => _SellerOnboardingPageState();
}

class _SellerOnboardingPageState extends State<SellerOnboardingPage> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  
  // Form fields
  final _storeNameController = TextEditingController();
  String _sellerType = 'Individual';
  
  // Business Info fields
  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();

  // Payout Info fields
  String _payoutMethod = 'Bank account';
  String? _selectedBank;
  final List<String> _banks = ['BDO', 'BPI', 'Metrobank', 'Security Bank', 'UnionBank', 'GCash', 'Maya'];
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  bool _agreeToTerms = false;
  
  // Document tracking
  bool _idUploaded = false;
  bool _selfieUploaded = false;
  XFile? _idImage;
  XFile? _selfieImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _storeNameController.dispose();
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 1) {
      // Validate documents
      if (!_idUploaded || !_selfieUploaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload both ID and Selfie to continue')),
        );
        return;
      }
    }
    
    if (_currentStep < 4) {
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  Future<void> _pickImage(String type) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          if (type == 'id') {
            _idImage = pickedFile;
            _idUploaded = true;
          } else {
            _selfieImage = pickedFile;
            _selfieUploaded = true;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the terms and conditions')),
      );
      return;
    }

    try {
      final sellerProvider = context.read<SellerProvider>();
      final authProvider = context.read<AuthProvider>();
      
      // ── AUTH RECOVERY ──────────────────────────────────────────────────────
      // [SELLER] Use auth_state first, then getCurrentUser recovery.
      var user = authProvider.user;
      if (user == null) {
        debugPrint('[SELLER] State user is null — attempting recovery session fetch');
        await authProvider.getCurrentUser();
        user = authProvider.user;
      }
      
      if (user == null) {
        throw Exception('User session lost — please log in again.');
      }
      
      debugPrint('[SELLER] Submitting application for: ${user.uid}');
      
      // ── STEP 1: UPLOAD DOCUMENTS (CLOUDINARY) ──────────────────────────────
      // [UPLOAD] Identity uploaded and URL saved to seller application.
      String idUrl = '';
      String selfieUrl = '';
      
      if (_idImage != null) {
        final bytes = await _idImage!.readAsBytes();
        idUrl = await sellerProvider.uploadIdentityImage(
          bytes, 
          'id_verification.jpg', 
          'image/jpeg'
        );
        debugPrint('[UPLOAD] Identity document uploaded: $idUrl');
      }
      
      if (_selfieImage != null) {
        final bytes = await _selfieImage!.readAsBytes();
        selfieUrl = await sellerProvider.uploadIdentityImage(
          bytes, 
          'selfie_verification.jpg', 
          'image/jpeg'
        );
        debugPrint('[UPLOAD] Selfie document uploaded: $selfieUrl');
      }

      // ── STEP 2: BUILD APPLICATION RECORD ──────────────────────────────────
      final applicationData = {
        'user_id': user.uid,
        'store_name': _storeNameController.text,
        'seller_type': _sellerType,
        'full_name': _fullNameController.text,
        'phone_number': PhoneUtils.normalizePH(_phoneNumberController.text),
        'address': _addressController.text,
        'email': _emailController.text,
        'payout_method': _payoutMethod,
        'bank_name': _selectedBank ?? '',
        'account_name': _accountNameController.text,
        'account_number': _accountNumberController.text,
        'identity_image_url': idUrl,
        'selfie_image_url': selfieUrl,
        'status': 'PENDING',
        'agree_to_terms': _agreeToTerms,
      };

      // ── STEP 3: SUBMIT TO FIRESTORE ───────────────────────────────────────
      await sellerProvider.submitApplication(applicationData, userId: user.uid);
      
      // [SELLER] Profile sync — reflects PENDING status globally
      await authProvider.refreshUserData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application submitted. Please wait for approval.')),
        );
        Navigator.pop(context); // Back to previous screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Become a Seller')),
      body: Form(
        key: _formKey,
        child: Stepper(
          type: StepperType.vertical,
          currentStep: _currentStep,
          onStepContinue: _nextStep,
          onStepCancel: _prevStep,
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    child: Text(_currentStep == 4 ? 'Submit Application' : 'Continue'),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Back'),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Basic Information'),
              subtitle: const Text('Tell us about your store'),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: Column(
                children: [
                  TextFormField(
                    controller: _storeNameController,
                    decoration: const InputDecoration(labelText: 'Store Name'),
                    validator: (value) => value?.isEmpty ?? true ? 'Enter store name' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _sellerType,
                    decoration: const InputDecoration(labelText: 'Seller Type'),
                    items: ['Individual', 'Registered Business']
                        .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (val) => setState(() => _sellerType = val!),
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Identity Verification'),
              subtitle: const Text('Upload ID & Selfie'),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('For security, we need to verify your identity. Please upload clear images.'),
                  const SizedBox(height: 16),
                  const Text('Government ID', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _pickImage('id'),
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _idUploaded ? Colors.green.withValues(alpha: 0.1) : Colors.grey[100],
                        border: Border.all(color: _idUploaded ? Colors.green : Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _idImage != null
                          ? kIsWeb
                              ? Image.network(_idImage!.path, fit: BoxFit.contain)
                              : Image.file(File(_idImage!.path), fit: BoxFit.contain)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.badge_outlined, size: 40, color: Colors.grey[600]),
                                const SizedBox(height: 8),
                                Text('Tap to upload Government ID', style: TextStyle(color: Colors.grey[700])),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Take a Selfie', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _pickImage('selfie'),
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _selfieUploaded ? Colors.green.withValues(alpha: 0.1) : Colors.grey[100],
                        border: Border.all(color: _selfieUploaded ? Colors.green : Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _selfieImage != null
                          ? kIsWeb
                              ? Image.network(_selfieImage!.path, fit: BoxFit.contain)
                              : Image.file(File(_selfieImage!.path), fit: BoxFit.contain)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_outlined, size: 40, color: Colors.grey[600]),
                                const SizedBox(height: 8),
                                Text('Tap to upload Selfie', style: TextStyle(color: Colors.grey[700])),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Business Info'),
              subtitle: const Text('Additional details'),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
              content: Column(
                children: [
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(labelText: 'Full Name / Registered Name'),
                    validator: (val) => val?.isEmpty ?? true ? 'Enter full name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneNumberController,
                    decoration: const InputDecoration(labelText: 'Business Phone Number', hintText: '0912 345 6789'),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [PHPhoneFormatter()],
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Enter phone number';
                      final normalized = PhoneUtils.normalizePH(val);
                      if (!PhoneUtils.isValidPH(normalized)) return 'Invalid format. Use 09XXXXXXXXX';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email Address'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) => val?.isEmpty ?? true ? 'Enter email address' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Registered Address'),
                    maxLines: 2,
                    validator: (val) => val?.isEmpty ?? true ? 'Enter registered address' : null,
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Payout Info'),
              subtitle: const Text('Where we send your earnings'),
              isActive: _currentStep >= 3,
              state: _currentStep > 3 ? StepState.complete : StepState.indexed,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _payoutMethod,
                    decoration: const InputDecoration(labelText: 'Payout Method'),
                    items: ['Bank account', 'E-Wallet']
                        .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (val) => setState(() {
                      _payoutMethod = val!;
                      // Reset selected bank if switching categories
                      if (_payoutMethod == 'E-Wallet' && _selectedBank != 'GCash' && _selectedBank != 'Maya') {
                        _selectedBank = null;
                      } else if (_payoutMethod == 'Bank account' && (_selectedBank == 'GCash' || _selectedBank == 'Maya')) {
                        _selectedBank = null;
                      }
                    }),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBank,
                    decoration: InputDecoration(labelText: _payoutMethod == 'E-Wallet' ? 'E-Wallet Provider' : 'Bank Name'),
                    items: _banks
                        .where((b) => _payoutMethod == 'E-Wallet' ? (b == 'GCash' || b == 'Maya') : (b != 'GCash' && b != 'Maya'))
                        .map((bank) => DropdownMenuItem(value: bank, child: Text(bank)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedBank = val),
                    validator: (val) => val == null ? 'Select a provider/bank' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _accountNameController,
                    decoration: const InputDecoration(labelText: 'Account Name'),
                    validator: (value) => value?.isEmpty ?? true ? 'Enter account name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _accountNumberController,
                    decoration: const InputDecoration(labelText: 'Account Number'),
                    keyboardType: TextInputType.number,
                    validator: (value) => value?.isEmpty ?? true ? 'Enter account number' : null,
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Terms & Agreement'),
              subtitle: const Text('Finalize your application'),
              isActive: _currentStep >= 4,
              state: _currentStep == 4 ? StepState.editing : StepState.indexed,
              content: CheckboxListTile(
                title: const Text('I agree to Swipify\'s Seller Terms and Conditions and Privacy Policy.'),
                value: _agreeToTerms,
                onChanged: (val) => setState(() => _agreeToTerms = val!),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
