import 'package:flutter/material.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/services/admin_support_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swipify/core/utils/responsive_helper.dart';

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
    if (!mounted) return;
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

      if (!mounted) return;
      setState(() {
        _tickets = results[0];
        _disputes = results[1];
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = ResponsiveHelper.isMobile(context);
    final double horizontalPadding = isMobile ? 16.0 : 24.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, isMobile),
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
                _buildTicketsList(isMobile),
                _buildDisputesList(isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        Text(
          'Support & Disputes', 
          style: isMobile ? SwipifyTheme.heading2 : SwipifyTheme.heading1,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_tickets.length} Active Tickets',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: 'Refresh Data',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTicketsList(bool isMobile) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    if (_tickets.isEmpty) return _buildEmptyState('No support tickets found', Icons.confirmation_number_outlined);

    return ListView.builder(
      itemCount: _tickets.length,
      padding: const EdgeInsets.only(bottom: 24),
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        return _buildTicketCard(ticket, isMobile);
      },
    );
  }

  Widget _buildTicketCard(dynamic ticket, bool isMobile) {
    final String subject = ticket['subject'] ?? 'No Subject';
    final String userName = ticket['user_name'] ?? ticket['user_email'] ?? 'Unknown User';
    final String status = ticket['status'] ?? 'open';
    final String priority = ticket['priority'] ?? 'low';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => _showTicketDetails(ticket),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      subject,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildPriorityChip(priority),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      userName,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                  Text(
                    'Ticket #${ticket['id']?.toString().substring(0, 6) ?? 'N/A'}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisputesList(bool isMobile) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    if (_disputes.isEmpty) return _buildEmptyState('No active disputes', Icons.gavel_outlined);

    return ListView.builder(
      itemCount: _disputes.length,
      padding: const EdgeInsets.only(bottom: 24),
      itemBuilder: (context, index) {
        final dispute = _disputes[index];
        return _buildDisputeCard(dispute, isMobile);
      },
    );
  }

  Widget _buildDisputeCard(dynamic dispute, bool isMobile) {
    final amount = dispute['amount'] ?? 0.0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => _showDisputeDetails(dispute),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Order #${dispute['order_id']?.toString().substring(0, 8) ?? 'N/A'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '₱${amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildUserIndicator('Buyer', dispute['buyer_name']),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.compare_arrows, size: 14, color: Colors.grey),
                  ),
                  _buildUserIndicator('Seller', dispute['seller_name']),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                dispute['reason'] ?? 'No reason provided',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserIndicator(String label, String? name) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
          Text(name ?? 'Unknown', style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open': return Colors.blue;
      case 'in_progress': return Colors.orange;
      case 'resolved': return Colors.green;
      case 'closed': return Colors.grey;
      default: return Colors.blue;
    }
  }

  Widget _buildPriorityChip(String? priority) {
    Color color;
    switch (priority?.toLowerCase()) {
      case 'urgent': color = Colors.red; break;
      case 'high': color = Colors.orange; break;
      case 'medium': color = Colors.blue; break;
      default: color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        (priority ?? 'low').toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showTicketDetails(dynamic ticket) {
    final bool isMobile = ResponsiveHelper.isMobile(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ticket['subject'] ?? 'Ticket Details'),
        content: SizedBox(
          width: isMobile ? double.maxFinite : 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('User', '${ticket['user_name'] ?? 'Unknown'} (${ticket['user_email']})'),
                if (ticket['assignee_name'] != null)
                  _buildDetailRow('Assigned To', ticket['assignee_name']),
                _buildDetailRow('Category', ticket['category'] ?? 'General'),
                const SizedBox(height: 16),
                const Text('Message:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(ticket['message'] ?? 'No message content.'),
                ),
                if (ticket['images'] != null && (ticket['images'] as List).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Attachments:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: (ticket['images'] as List).length,
                      itemBuilder: (context, i) {
                        return GestureDetector(
                          onTap: () => _viewFullImage(ticket['images'][i]),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                              image: DecorationImage(
                                image: NetworkImage(ticket['images'][i]),
                                fit: BoxFit.cover,
                              ),
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (ticket['status'] != 'resolved')
            ElevatedButton(
              onPressed: () => _resolveTicket(ticket),
              child: const Text('Resolve Ticket'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  void _viewFullImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          children: [
            Image.network(url),
            Positioned(
              right: 8,
              top: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resolveTicket(dynamic ticket) async {
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
      try {
        await AdminSupportService.updateTicket(ticket['id'], {
          'status': 'resolved',
          'admin_notes': notesController.text,
          'resolved_at': DateTime.now().toIso8601String(),
        });
        if (!mounted) return;
        Navigator.pop(context); // Close details dialog
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket resolved successfully')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDisputeDetails(dynamic dispute) {
    final bool isMobile = ResponsiveHelper.isMobile(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dispute Resolution'),
        content: SizedBox(
          width: isMobile ? double.maxFinite : 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Order ID', dispute['order_id'] ?? 'N/A'),
              _buildDetailRow('Buyer', dispute['buyer_name'] ?? 'Unknown'),
              _buildDetailRow('Seller', dispute['seller_name'] ?? 'Unknown'),
              _buildDetailRow('Amount', '₱${(dispute['amount'] ?? 0.0).toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              const Text('Dispute Reason:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Text(dispute['reason'] ?? 'No reason specified.'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _handleDisputeResolution(dispute, 'rejected', 'Dispute rejected by admin'),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => _handleDisputeResolution(dispute, 'refunded', 'Dispute approved, refund initiated'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Approve & Refund'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDisputeResolution(dynamic dispute, String status, String message) async {
    try {
      await AdminSupportService.resolveDispute(dispute['id'], status, message);
      if (!mounted) return;
      Navigator.pop(context);
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dispute $status successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
