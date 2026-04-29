import 'package:flutter/material.dart';
import 'package:swipify/services/admin_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  bool _isLoading = true;
  List<dynamic> _users = [];
  String _searchQuery = '';
  String? _selectedRole;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final result = await AdminService.getUsers(
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
          role: _selectedRole,
        );
        setState(() {
          _users = result['users'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStatus(String uid, String status) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await AdminService.updateUserStatus(uid, status);
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User status updated to $status')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update user status: $e')),
        );
      }
    }
  }

  Future<void> _updateRole(String uid, String role) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await AdminService.updateUserRole(uid, role);
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User role updated to $role')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update user role: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by email or name...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    _searchQuery = value;
                  },
                  onSubmitted: (_) => _loadUsers(),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedRole,
                    hint: const Text('All Roles'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Roles')),
                      DropdownMenuItem(value: 'user', child: Text('User')),
                      DropdownMenuItem(value: 'seller', child: Text('Seller')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'moderator', child: Text('Moderator')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value;
                      });
                      _loadUsers();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: ElevatedButton.icon(
                  onPressed: _loadUsers,
                  icon: const Icon(Icons.search),
                  label: const Text('Search', maxLines: 1, overflow: TextOverflow.ellipsis),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                  ? const Center(child: Text('No users found.'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('UID')),
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Email')),
                            DataColumn(label: Text('Role')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: _users.map((user) {
                            return DataRow(
                              cells: [
                                DataCell(Text(user['uid']?.toString().substring(0, 8) ?? 'N/A')),
                                DataCell(Text(user['name'] ?? 'N/A')),
                                DataCell(Text(user['email'] ?? 'N/A')),
                                DataCell(Text(user['role'] ?? 'user')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (user['status'] == 'active' || user['status'] == null)
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      (user['status'] ?? 'active').toString().toUpperCase(),
                                      style: TextStyle(
                                        color: (user['status'] == 'active' || user['status'] == null)
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.security),
                                        tooltip: 'Change Role',
                                        onSelected: (role) => _updateRole(user['uid'], role),
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(value: 'user', child: Text('Set as User')),
                                          const PopupMenuItem(value: 'seller', child: Text('Set as Seller')),
                                          const PopupMenuItem(value: 'moderator', child: Text('Set as Moderator')),
                                          const PopupMenuItem(value: 'admin', child: Text('Set as Admin')),
                                        ],
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert),
                                        tooltip: 'Change Status',
                                        onSelected: (status) => _updateStatus(user['uid'], status),
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(value: 'active', child: Text('Set Active')),
                                          const PopupMenuItem(value: 'suspended', child: Text('Suspend')),
                                          const PopupMenuItem(value: 'banned', child: Text('Ban')),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}
