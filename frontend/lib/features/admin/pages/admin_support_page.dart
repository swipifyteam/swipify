import 'package:flutter/material.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/services/admin_support_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminSupportPage extends StatefulWidget {
  const AdminSupportPage({super.key});

  @override
  State<AdminSupportPage> createState() => _AdminSupportPageState();
}

class _AdminSupportPageState extends State<AdminSupportPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _tickets = [];
  List<dynamic> _disputes = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final results = await Future.wait([
        AdminSupportService.getTickets(),
        AdminSupportService.getDisputes(),
      ]);

      setState(() {
        _tickets = results[0];
        _disputes = results[1];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Support & Disputes', 
                  style: SwipifyTheme.heading1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
              ),
            ],
          ),
          const SizedBox(height: 24),
          TabBar(
            controller: _tabController,
            labelColor: SwipifyTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: SwipifyTheme.primaryColor,
            tabs: const [
              Tab(text: 'Tickets'),
              Tab(text: 'Disputes'),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTicketsList(),
                _buildDisputesList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketsList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    if (_tickets.isEmpty) return const Center(child: Text('No support tickets found.'));

    return ListView.builder(
      itemCount: _tickets.length,
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
              ticket['subject'] ?? 'No Subject',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('From: ${ticket['user_name'] ?? ticket['user_email']} | Status: ${ticket['status']}'),
            trailing: _buildPriorityChip(ticket['priority']),
            onTap: () => _showTicketDetails(ticket),
          ),
        );
      },
    );
  }

  Widget _buildDisputesList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    if (_disputes.isEmpty) return const Center(child: Text('No disputes found.'));

    return ListView.builder(
      itemCount: _disputes.length,
      itemBuilder: (context, index) {
        final dispute = _disputes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
              'Order: ${dispute['order_id']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('Buyer: ${dispute['buyer_name'] ?? 'Unknown'} | Seller: ${dispute['seller_name'] ?? 'Unknown'}'),
            trailing: Text('₱${dispute['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            onTap: () => _showDisputeDetails(dispute),
          ),
        );
      },
    );
  }

  Widget _buildPriorityChip(String? priority) {
    Color color;
    switch (priority?.toLowerCase()) {
      case 'urgent': color = Colors.red; break;
      case 'high': color = Colors.orange; break;
      case 'medium': color = Colors.blue; break;
      default: color = Colors.grey;
    }

    return Chip(
      label: Text(priority ?? 'Low', style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
    );
  }

  void _showTicketDetails(dynamic ticket) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ticket['subject']),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User: ${ticket['user_name'] ?? 'Unknown'} (${ticket['user_email']})'),
              if (ticket['assignee_name'] != null)
                Text('Assigned To: ${ticket['assignee_name']}'),
              const SizedBox(height: 8),
              Text('Category: ${ticket['category']}'),
              const SizedBox(height: 16),
              const Text('Message:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(ticket['message']),
              if (ticket['images'] != null && (ticket['images'] as List).isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Attachments:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: (ticket['images'] as List).length,
                    itemBuilder: (context, i) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(ticket['images'][i]),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  child: Image.network(ticket['images'][i]),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              final notesController = TextEditingController();
              final result = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Resolve Ticket'),
                  content: TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Response to User',
                      hintText: 'Describe how this was resolved',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
                  ],
                ),
              );

              if (result == true) {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await AdminSupportService.updateTicket(ticket['id'], {
                    'status': 'resolved',
                    'admin_notes': notesController.text,
                    'resolved_at': DateTime.now().toIso8601String(),
                  });
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _loadData();
                }
              }
            },
            child: const Text('Mark as Resolved'),
          ),
        ],
      ),
    );
  }

  void _showDisputeDetails(dynamic dispute) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Dispute: ${dispute['id']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order ID: ${dispute['order_id']}'),
              Text('Buyer: ${dispute['buyer_name'] ?? 'Unknown'}'),
              Text('Seller: ${dispute['seller_name'] ?? 'Unknown'}'),
              Text('Amount: ₱${dispute['amount']}'),
              const SizedBox(height: 8),
              Text('Reason: ${dispute['reason']}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await AdminSupportService.resolveDispute(dispute['id'], 'rejected', 'Dispute rejected by admin');
                if (!context.mounted) return;
                Navigator.pop(context);
                _loadData();
              }
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await AdminSupportService.resolveDispute(dispute['id'], 'refunded', 'Dispute approved, refund initiated');
                if (!context.mounted) return;
                Navigator.pop(context);
                _loadData();
              }
            },
            child: const Text('Approve & Refund'),
          ),
        ],
      ),
    );
  }
}
