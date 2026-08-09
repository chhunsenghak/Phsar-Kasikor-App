import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/app_snackbar.dart';

/// Result of [DeliveryLocationPicker]: where the buyer wants this order
/// delivered, plus an optional human-readable label for the seller.
class DeliveryLocation {
  final double lat;
  final double lng;
  final String? addressText;

  const DeliveryLocation({required this.lat, required this.lng, this.addressText});
}

/// A "pin stays centered, drag the map underneath" location picker — the
/// same interaction Grab/Google Maps use for address pickers, and simpler
/// to get right than a draggable marker with its own hit-testing.
class DeliveryLocationPicker extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialAddressText;

  const DeliveryLocationPicker({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialAddressText,
  });

  @override
  State<DeliveryLocationPicker> createState() => _DeliveryLocationPickerState();
}

class _DeliveryLocationPickerState extends State<DeliveryLocationPicker> {
  // Phnom Penh — a reasonable default center when nothing else is known yet.
  static const LatLng _fallbackCenter = LatLng(11.5564, 104.9282);

  final MapController _mapController = MapController();
  final TextEditingController _addressController = TextEditingController();
  late LatLng _center;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _center = (widget.initialLat != null && widget.initialLng != null)
        ? LatLng(widget.initialLat!, widget.initialLng!)
        : _fallbackCenter;
    _addressController.text = widget.initialAddressText ?? '';
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    final state = Provider.of<AppState>(context, listen: false);
    setState(() => _isLocating = true);
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw Exception('SERVICE_DISABLED');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          AppSnackBar.warning(context, state.translate('location_permission_denied'));
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final target = LatLng(position.latitude, position.longitude);
      setState(() => _center = target);
      _mapController.move(target, 16.0);
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context, state.translate('location_fetch_failed'));
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _confirm() {
    Navigator.pop(
      context,
      DeliveryLocation(
        lat: _center.latitude,
        lng: _center.longitude,
        addressText: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          state.translate('delivery_location'),
          style: GoogleFonts.inter(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.secondaryContainer.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.onSecondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.translate('drop_pin_instructions'),
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSecondaryContainer),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 15.0,
                    onPositionChanged: (camera, hasGesture) {
                      if (hasGesture) {
                        _center = camera.center;
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.phsar_kasikor_app',
                    ),
                  ],
                ),
                IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Icon(Icons.location_pin, size: 44, color: AppColors.error),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    heroTag: 'use_current_location_fab',
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.primary,
                    onPressed: _isLocating ? null : _useCurrentLocation,
                    child: _isLocating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : const Icon(Icons.my_location_rounded),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(20),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _addressController,
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: state.translate('delivery_address_label'),
                      hintText: state.translate('delivery_address_hint'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesign.borderRadiusSm)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: state.translate('confirm_location'),
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: _confirm,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
