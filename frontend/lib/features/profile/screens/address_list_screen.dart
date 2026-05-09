import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/models/address_model.dart';
import 'package:swipify/features/profile/service/address_provider.dart';
import 'package:swipify/core/utils/phone_utils.dart';

class AddressListScreen extends StatefulWidget {
  const AddressListScreen({super.key});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.user?.uid != null) {
        Provider.of<AddressProvider>(context, listen: false).fetchAddresses(auth.user!.uid);
      }
    });
  }

  Future<void> _deleteAddress(String addressId) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final addressProvider = Provider.of<AddressProvider>(context, listen: false);
      if (auth.user?.uid == null) {
        throw Exception("User not logged in");
      }
      await addressProvider.deleteAddress(addressId, auth.user!.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete address: $e')),
      );
    }
  }

  Future<void> _setAsDefault(AddressModel address) async {
    try {
      final addressProvider = Provider.of<AddressProvider>(context, listen: false);
      await addressProvider.setAsDefault(address);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default address updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set default address: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwipifyTheme.backgroundColor,
      appBar: AppBar(
        title: const Text("My Addresses"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddressFormScreen()),
            ),
          ),
        ],
      ),
      body: Consumer<AddressProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.addresses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (provider.error != null && provider.addresses.isEmpty) {
            return Center(child: Text("Error: ${provider.error}"));
          }
          
          if (provider.addresses.isEmpty) {
            return _buildEmptyState();
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.addresses.length,
            itemBuilder: (context, index) {
              final address = provider.addresses[index];
              return AddressCard(
                address: address,
                onEdit: (editedAddress) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddressFormScreen(address: editedAddress)),
                ),
                onDelete: _deleteAddress,
                onSetDefault: _setAsDefault,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_on_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            "No addresses yet",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            "Add your first shipping address.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddressFormScreen()),
            ),
            icon: const Icon(Icons.add_location_alt),
            label: const Text("Add New Address"),
          ),
        ],
      ),
    );
  }
}


// Address Card Widget
class AddressCard extends StatelessWidget {
  final AddressModel address;
  final Function(AddressModel) onEdit;
  final Function(String) onDelete;
  final Function(AddressModel) onSetDefault;

  const AddressCard({
    super.key,
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  address.fullName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (address.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: SwipifyTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "Default",
                      style: TextStyle(color: SwipifyTheme.primaryColor, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(address.phone, style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 4),
            Text(address.fullAddress, style: TextStyle(color: Colors.grey[700])),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!address.isDefault)
                  TextButton(
                    onPressed: () => onSetDefault(address),
                    child: const Text("Set as Default"),
                  ),
                TextButton(
                  onPressed: () => onEdit(address),
                  child: const Text("Edit"),
                ),
                TextButton(
                  onPressed: () => onDelete(address.id),
                  child: const Text("Delete", style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Address Form Screen
class AddressFormScreen extends StatefulWidget {
  final AddressModel? address;
  const AddressFormScreen({super.key, this.address});

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _regionController;
  late TextEditingController _cityController;
  late TextEditingController _barangayController;
  late TextEditingController _streetController;
  late TextEditingController _postalCodeController;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.address?.fullName ?? '');
    _phoneController = TextEditingController(text: widget.address?.phone ?? '');
    _regionController = TextEditingController(text: widget.address?.region ?? '');
    _cityController = TextEditingController(text: widget.address?.city ?? '');
    _barangayController = TextEditingController(text: widget.address?.barangay ?? '');
    _streetController = TextEditingController(text: widget.address?.street ?? '');
    _postalCodeController = TextEditingController(text: widget.address?.postalCode ?? '');
    _isDefault = widget.address?.isDefault ?? false;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _regionController.dispose();
    _cityController.dispose();
    _barangayController.dispose();
    _streetController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user?.uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    try {
      final addressProvider = Provider.of<AddressProvider>(context, listen: false);
      final address = AddressModel(
        id: widget.address?.id ?? '',
        userId: auth.user!.uid,
        fullName: _fullNameController.text.trim(),
        phone: PhoneUtils.normalizePH(_phoneController.text),
        region: _regionController.text.trim(),
        city: _cityController.text,
        barangay: _barangayController.text,
        street: _streetController.text,
        postalCode: _postalCodeController.text,
        isDefault: _isDefault,
      );

      if (widget.address == null) {
        await addressProvider.addAddress(address);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address added successfully')),
        );
      } else {
        await addressProvider.updateAddress(address);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address updated successfully')),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save address: $e')),
      );
    }
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    final normalized = PhoneUtils.normalizePH(value);
    if (!PhoneUtils.isValidPH(normalized)) {
      return 'Invalid phone number. Use 09XXXXXXXXX format.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.address == null ? "Add New Address" : "Edit Address"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: "Full Name"),
                validator: (value) => value!.isEmpty ? "Full Name is required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: "Phone Number", hintText: "0912 345 6789"),
                keyboardType: TextInputType.phone,
                inputFormatters: [PHPhoneFormatter()],
                validator: _validatePhone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _regionController,
                decoration: const InputDecoration(labelText: "Region"),
                validator: (value) => value!.isEmpty ? "Region is required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: "City"),
                validator: (value) => value!.isEmpty ? "City is required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _barangayController,
                decoration: const InputDecoration(labelText: "Barangay"),
                validator: (value) => value!.isEmpty ? "Barangay is required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _streetController,
                decoration: const InputDecoration(labelText: "Street Address"),
                validator: (value) => value!.isEmpty ? "Street Address is required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _postalCodeController,
                decoration: const InputDecoration(labelText: "Postal Code"),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? "Postal Code is required" : null,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text("Set as Default Address"),
                value: _isDefault,
                onChanged: (bool value) {
                  setState(() {
                    _isDefault = value;
                  });
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveAddress,
                  child: Text(widget.address == null ? "Add Address" : "Update Address"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
