import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/orders/order_service.dart';
import 'package:swipify/features/orders/model/order_model.dart';

class TrackingScreen extends StatefulWidget {
  final String orderId;
  final String trackingNumber;

  const TrackingScreen({
    super.key, 
    required this.orderId,
    required this.trackingNumber,
  });

  @override
  // ignore: library_private_types_in_public_api
  _TrackingScreenState createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  late Future<TrackingModel> _trackingFuture;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  
  final LatLng _defaultCenter = const LatLng(14.5995, 120.9842);

  @override
  void initState() {
    super.initState();
    _trackingFuture = OrderService.getTracking(widget.orderId);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _updateMap(Map<String, dynamic> locationData) {
    if (locationData['lat'] != null && locationData['lng'] != null) {
      final latLng = LatLng(
        (locationData['lat'] as num).toDouble(),
        (locationData['lng'] as num).toDouble(),
      );

      setState(() {
        _markers.removeWhere((m) => m.markerId.value == 'courier');
        _markers.add(
          Marker(
            markerId: const MarkerId('courier'),
            position: latLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            infoWindow: const InfoWindow(title: 'Courier is here'),
          ),
        );
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 15.0),
      );
    }
  }

  Widget _buildTimeline(TrackingModel tracking) {
    final statusHistory = tracking.statusHistory;
    
    if (statusHistory.isEmpty) {
       return Center(
         child: Padding(
           padding: const EdgeInsets.all(20.0),
           child: Text(
             'Tracking info not yet available',
             style: GoogleFonts.inter(
               color: SwipifyTheme.textSecondary,
               fontWeight: FontWeight.w600,
             ),
           ),
         ),
       );
    }

    // Convert history to list of widgets
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DELIVERY TIMELINE',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: SwipifyTheme.textPrimary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: statusHistory.length,
            itemBuilder: (context, index) {
              // Show in reverse chronological order
              final entry = statusHistory[statusHistory.length - 1 - index];
              final isLatest = index == 0;
              
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isLatest ? SwipifyTheme.primaryColor : SwipifyTheme.borderColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (index < statusHistory.length - 1)
                        Container(
                          width: 2,
                          height: 40,
                          color: SwipifyTheme.borderColor,
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.newStatus.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: isLatest ? FontWeight.w800 : FontWeight.w600,
                            color: isLatest ? SwipifyTheme.textPrimary : SwipifyTheme.textSecondary,
                          ),
                        ),
                        Text(
                          entry.timestamp.split('T')[0], // Simple date display
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: SwipifyTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwipifyTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: SwipifyTheme.textPrimary),
        title: Text(
          'Live Tracking',
          style: SwipifyTheme.heading2.copyWith(fontSize: 18),
        ),
      ),
      body: FutureBuilder<TrackingModel>(
        future: _trackingFuture,
        builder: (context, trackingSnapshot) {
          if (trackingSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: SwipifyTheme.primaryColor));
          }
          
          if (trackingSnapshot.hasError || !trackingSnapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 64, color: SwipifyTheme.borderColor),
                  const SizedBox(height: 16),
                  Text('Tracking not available yet', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: SwipifyTheme.textSecondary)),
                ],
              ),
            );
          }

          final tracking = trackingSnapshot.data!;

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('shipments')
                .doc(widget.trackingNumber)
                .snapshots(),
            builder: (context, shipmentSnapshot) {
              Map<String, dynamic>? shipmentData;
              if (shipmentSnapshot.hasData && shipmentSnapshot.data!.exists) {
                shipmentData = shipmentSnapshot.data!.data() as Map<String, dynamic>;
                final location = shipmentData['location'] as Map<String, dynamic>?;
                if (location != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _updateMap(location);
                  });
                }
              }

              return Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: Stack(
                      children: [
                        GoogleMap(
                          onMapCreated: _onMapCreated,
                          initialCameraPosition: CameraPosition(
                            target: _defaultCenter,
                            zoom: 12.0,
                          ),
                          markers: _markers,
                          polylines: _polylines,
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                        ),
                        // Tracking Info Card
                        Positioned(
                          top: 20,
                          left: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: SwipifyTheme.glassShadow,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: SwipifyTheme.primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.local_shipping_rounded, color: SwipifyTheme.primaryColor),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(tracking.courier ?? 'Standard Delivery', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
                                      Text('Tracking: ${tracking.trackingNumber ?? widget.trackingNumber}', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: SwipifyTheme.textSecondary)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: SwipifyTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    tracking.status.toUpperCase(),
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Bottom Sheet Content (Scrollable)
                  Expanded(
                    flex: 2,
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5)),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            Container(width: 40, height: 4, decoration: BoxDecoration(color: SwipifyTheme.borderColor, borderRadius: BorderRadius.circular(2))),
                            _buildTimeline(tracking),
                            const Divider(height: 1, color: SwipifyTheme.borderColor),
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Status', style: GoogleFonts.inter(color: SwipifyTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                                        Text(tracking.status.replaceAll('_', ' ').toUpperCase(), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: SwipifyTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                      padding: const EdgeInsets.all(15),
                                      elevation: 0,
                                    ),
                                    child: const Icon(Icons.phone_rounded),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
