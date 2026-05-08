// lib/features/profile/widgets/profile_header.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/profile/service/user_provider.dart';
import 'package:swipify/features/profile/screens/settings_screen.dart';
import 'package:swipify/features/seller/service/seller_provider.dart';
import 'package:swipify/features/seller/domain/entities/seller_entity.dart';
import 'package:swipify/features/seller/presentation/pages/seller_dashboard_page.dart';
import 'package:swipify/features/seller/presentation/pages/seller_onboarding_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileHeader extends StatefulWidget {
  const ProfileHeader({super.key});

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<UserProvider>().loadProfile(user.uid);
        context.read<SellerProvider>().loadSellerStatus(user.uid);
      }
    });
  }

  Future<void> _pickAndUploadImage(BuildContext context) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      if (!context.mounted) return;
      try {
        final bytes = file.bytes ?? await File(file.path!).readAsBytes();
        if (!context.mounted) return;
        await context.read<UserProvider>().updateProfilePicture(user.uid, bytes, file.name);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated successfully!')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AuthProvider, UserProvider, SellerProvider>(
      builder: (context, authProvider, userProv, sellerProvider, _) {
        final profile = userProv.profile;
        final displayName = profile?.name ?? authProvider.user?.displayName ?? 'User';
        final photoUrl = profile?.profileImage ?? authProvider.user?.photoUrl;
        final isSeller = sellerProvider.status == SellerStatus.approved;

        return SliverAppBar(
          expandedHeight: 140.0,
          floating: false,
          pinned: true,
          backgroundColor: SwipifyTheme.primaryColor,
          leadingWidth: 100,
          leading: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 32),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => isSeller
                          ? const SellerDashboardPage()
                          : const SellerOnboardingPage(),
                    ),
                  );
                },
                child: Text(
                  isSeller ? 'My Shop' : 'Sell',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
              onPressed: () {},
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    SwipifyTheme.primaryColor,
                    SwipifyTheme.primaryColor.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 20, top: 40),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 65,
                          height: 65,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: ClipOval(
                            child: photoUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: photoUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(color: Colors.white10),
                                    errorWidget: (context, url, error) => const Icon(Icons.person, size: 35, color: Colors.white),
                                  )
                                : Container(
                                    color: Colors.white24,
                                    child: const Icon(Icons.person, size: 35, color: Colors.white),
                                  ),
                          ),
                        ),
                        if (userProv.isLoading)
                           const Positioned.fill(child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: userProv.isLoading ? null : () => _pickAndUploadImage(context),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 14, color: SwipifyTheme.primaryColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          if (authProvider.user != null)
                            InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Edit Profile',
                                  style: TextStyle(color: Colors.white, fontSize: 11),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
