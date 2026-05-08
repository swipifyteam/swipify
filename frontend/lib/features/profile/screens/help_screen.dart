import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/services/support_service.dart';
import 'package:swipify/features/profile/screens/ai_chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  String _selectedCategory = 'Account & Verification';
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final List<PlatformFile> _images = [];
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Account & Verification',
    'Ordering & Payment',
    'Shipping & Delivery',
    'Refunds & Returns',
    'Swipify Wallet & Coins',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_images.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 images allowed')),
      );
      return;
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        final remaining = 3 - _images.length;
        _images.addAll(result.files.take(remaining));
      });
    }
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await SupportService.createTicket(
        userId: user.uid,
        userName: user.displayName ?? 'User ${user.uid.substring(0, 4)}',
        userEmail: user.email ?? 'no-email',
        category: _selectedCategory,
        subject: _subjectController.text,
        message: _messageController.text,
        images: _images,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket submitted successfully!'), backgroundColor: Colors.green),
      );
      
      // Reset form
      _subjectController.clear();
      _messageController.clear();
      setState(() {
        _images.clear();
        _isSubmitting = false;
      });
      
      // Switch to "My Tickets" tab
      _tabController.animateTo(2);
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Help'),
        backgroundColor: SwipifyTheme.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.smart_toy_rounded, size: 18), text: 'AI Assistant'),
            Tab(icon: Icon(Icons.add_circle_outline, size: 18), text: 'New Ticket'),
            Tab(icon: Icon(Icons.list_alt, size: 18), text: 'My Tickets'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAiAssistantTab(),
          _buildNewTicketForm(),
          _buildMyTicketsList(),
        ],
      ),
    );
  }

  Widget _buildAiAssistantTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFE97B4A), Color(0xFFFF9A6C)]),
              borderRadius: BorderRadius.circular(40),
              boxShadow: [BoxShadow(color: const Color(0xFFE97B4A).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 20),
          Text('Swipify Assistant', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: SwipifyTheme.textPrimary)),
          const SizedBox(height: 8),
          Text('Get instant help with your orders, payments,\nshipping, and more.', textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: SwipifyTheme.textSecondary, height: 1.5)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen())),
              icon: const Icon(Icons.chat_bubble_outline, size: 20),
              label: Text('Start Chat', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: SwipifyTheme.primaryColor, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildFeatureRow(Icons.bolt, 'Instant Answers', 'Get help 24/7 without waiting'),
          _buildFeatureRow(Icons.verified_user, 'Context-Aware', 'Knows your orders and account'),
          _buildFeatureRow(Icons.confirmation_number, 'Auto Tickets', 'Create support tickets via chat'),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: SwipifyTheme.accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: SwipifyTheme.accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: SwipifyTheme.textPrimary)),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: SwipifyTheme.textSecondary)),
          ])),
        ],
      ),
    );
  }

  Widget _buildNewTicketForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('What can we help you with?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
                hintText: 'Briefly describe your concern',
              ),
              validator: (val) => (val == null || val.isEmpty) ? 'Please enter a subject' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _messageController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Details',
                border: OutlineInputBorder(),
                hintText: 'Provide as much detail as possible',
              ),
              validator: (val) => (val == null || val.length < 10) ? 'Please provide more details' : null,
            ),
            const SizedBox(height: 24),
            const Text('Attachments (Max 3)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                ..._images.asMap().entries.map((entry) {
                  return Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: (kIsWeb || entry.value.bytes != null)
                                ? MemoryImage(entry.value.bytes!) as ImageProvider
                                : FileImage(io.File(entry.value.path!)), 
                              fit: BoxFit.cover
                            ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () => setState(() => _images.removeAt(entry.key)),
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                if (_images.length < 3)
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add_a_photo, color: Colors.grey),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SwipifyTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SUBMIT TICKET', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyTicketsList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Please login to see your tickets'));

    return FutureBuilder<List<dynamic>>(
      future: SupportService.getMyTickets(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final tickets = snapshot.data ?? [];
        if (tickets.isEmpty) {
          return const Center(child: Text('You haven\'t submitted any tickets yet.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            final ticket = tickets[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                title: Text(ticket['subject'] ?? 'No Subject', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${ticket['category']} • ${ticket['status'].toUpperCase()}', 
                  style: TextStyle(color: _getStatusColor(ticket['status']))),
                trailing: Text(DateFormat('MMM dd').format(DateTime.parse(ticket['created_at']))),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Message:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(ticket['message']),
                        if (ticket['images'] != null && (ticket['images'] as List).isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text('Attachments:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: (ticket['images'] as List).length,
                              itemBuilder: (context, i) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 100,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: NetworkImage(ticket['images'][i]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        if (ticket['admin_notes'] != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Admin Response:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                const SizedBox(height: 4),
                                Text(ticket['admin_notes']),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'in_progress': return Colors.blue;
      case 'resolved': return Colors.green;
      case 'closed': return Colors.grey;
      default: return Colors.black;
    }
  }
}
