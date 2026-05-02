import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/models/review_model.dart';
import 'package:swipify/services/api_service.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  late Future<List<ReviewModel>> _futureReviews;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid != null) {
      _futureReviews = ApiService.getUserReviews(uid);
    } else {
      _futureReviews = Future.error('User not logged in');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('My Reviews'),
        backgroundColor: SwipifyTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<ReviewModel>>(
        future: _futureReviews,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final reviews = snapshot.data ?? [];

          if (reviews.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.star_border, size: 80, color: Colors.grey.shade300),
                   const SizedBox(height: 16),
                   const Text('You have no product reviews yet.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index];
              return _ReviewCard(review: review);
            },
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review.productName.isNotEmpty ? review.productName : 'Product Review',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                DateFormat('MMM d, yyyy').format(review.createdAt),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < review.rating ? Icons.star : Icons.star_border,
                color: Colors.orange,
                size: 18,
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(review.comment, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ],
      ),
    );
  }
}
