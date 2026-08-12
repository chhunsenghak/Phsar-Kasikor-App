import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../services/api/review_api.dart';
import '../../utils/geo_utils.dart';
import '../../widgets/custom_card.dart';
import 'farm_profile.dart';

class FarmMapDirectoryScreen extends StatefulWidget {
  const FarmMapDirectoryScreen({super.key});

  @override
  State<FarmMapDirectoryScreen> createState() => _FarmMapDirectoryScreenState();
}

class _FarmMapDirectoryScreenState extends State<FarmMapDirectoryScreen> {
  String _selectedProvince = 'All';
  String _searchQuery = '';
  bool _sortByNearest = false;

  // sellerId -> {'average_rating': double, 'review_count': int}. Loaded once
  // per unique seller in the current product list — real data from
  // ReviewApi, never a fabricated star rating.
  final Map<String, Map<String, dynamic>> _reviewSummaries = {};
  bool _isLoadingSummaries = false;
  String? _summariesLoadedForToken;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadReviewSummariesIfNeeded();
  }

  Future<void> _loadReviewSummariesIfNeeded() async {
    final state = Provider.of<AppState>(context, listen: false);
    final token = state.token;
    if (token == null || token == _summariesLoadedForToken || _isLoadingSummaries) return;

    final sellerIds = state.products.map((p) => p.sellerId).whereType<String>().toSet();
    if (sellerIds.isEmpty) return;

    _isLoadingSummaries = true;
    try {
      final results = await Future.wait(sellerIds.map((id) async {
        try {
          final summary = await ReviewApi.fetchSellerReviewSummary(token, id);
          return MapEntry(id, summary);
        } catch (_) {
          return null;
        }
      }));
      if (!mounted) return;
      setState(() {
        for (final entry in results) {
          if (entry != null) _reviewSummaries[entry.key] = entry.value;
        }
        _summariesLoadedForToken = token;
      });
    } finally {
      _isLoadingSummaries = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final allProducts = state.products;

    final double? myLat = (state.userProfile?['latitude'] as num?)?.toDouble();
    final double? myLng = (state.userProfile?['longitude'] as num?)?.toDouble();
    final bool myLocationKnown = myLat != null && myLng != null;

    // 1. Group products by farmerName
    final Map<String, List<MarketProduct>> farmerGroups = {};
    for (var p in allProducts) {
      final key = p.farmerName.isNotEmpty ? p.farmerName : state.translate('local_farmer_fallback');
      farmerGroups.putIfAbsent(key, () => []).add(p);
    }

    // 2. Extract unique provinces/locations dynamically
    final Set<String> extractedProvinces = {'All'};
    for (var p in allProducts) {
      if (p.location.isNotEmpty) {
        final parts = p.location.split(',');
        final prov = parts.last.trim();
        if (prov.isNotEmpty) {
          extractedProvinces.add(prov);
        }
      }
    }
    // Add standard provinces if list is small
    extractedProvinces.addAll(['Battambang', 'Phnom Penh', 'Siem Reap', 'Kampot', 'Pursat']);
    final provincesList = extractedProvinces.toList();

    // 3. Build dynamic producer models — distance and rating are real now:
    // distance from the buyer's and seller's actual saved coordinates
    // (haversineKm, same formula the backend uses for delivery pricing),
    // rating from ReviewApi's real aggregate. Either can be genuinely
    // unavailable (no saved address, no reviews yet) — shown honestly as
    // such instead of ever falling back to a made-up number.
    final List<Map<String, dynamic>> producers = [];
    farmerGroups.forEach((farmerName, crops) {
      final firstCrop = crops.first;
      final loc = firstCrop.location.isNotEmpty
          ? firstCrop.location
          : '${state.translate('Battambang')}, ${state.translate('cambodia_fallback')}';

      // Determine province tag
      final provTag = loc.split(',').last.trim();

      double? distanceKm;
      if (myLocationKnown && firstCrop.sellerLatitude != null && firstCrop.sellerLongitude != null) {
        distanceKm = haversineKm(myLat, myLng, firstCrop.sellerLatitude!, firstCrop.sellerLongitude!);
      }

      final summary = firstCrop.sellerId != null ? _reviewSummaries[firstCrop.sellerId] : null;
      final double? avgRating = (summary?['average_rating'] as num?)?.toDouble();
      final int reviewCount = (summary?['review_count'] as num?)?.toInt() ?? 0;

      producers.add({
        'farmerName': farmerName,
        'location': loc,
        'province': provTag,
        'crops': crops,
        'cropCount': crops.length,
        'isVerified': firstCrop.isVerifiedFarmer,
        'distanceKm': distanceKm,
        'averageRating': avgRating,
        'reviewCount': reviewCount,
      });
    });

    // 4. Filter by selected province & search query
    final filteredProducers = producers.where((prod) {
      final matchProvince = _selectedProvince == 'All' ||
                            prod['province'].toString().toLowerCase().contains(_selectedProvince.toLowerCase()) ||
                            prod['location'].toString().toLowerCase().contains(_selectedProvince.toLowerCase());

      final matchSearch = _searchQuery.isEmpty ||
                          prod['farmerName'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          prod['location'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          (prod['crops'] as List<MarketProduct>).any((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()));

      return matchProvince && matchSearch;
    }).toList();

    if (_sortByNearest && myLocationKnown) {
      filteredProducers.sort((a, b) {
        final da = a['distanceKm'] as double?;
        final db = b['distanceKm'] as double?;
        if (da == null && db == null) return 0;
        if (da == null) return 1; // unknown distance sorts last
        if (db == null) return -1;
        return da.compareTo(db);
      });
    }

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
          state.translate('farm_directory'),
          style: GoogleFonts.inter(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map header banner
            CustomCard(
              padding: EdgeInsets.zero,
              child: Stack(
                children: [
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.map_rounded, color: AppColors.primary, size: 44),
                          const SizedBox(height: 8),
                          Text(
                            state.translate('agri_map_title'),
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            state.translate('verified_farms_nearby', arguments: {'count': filteredProducers.length.toString()}),
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6)],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.gps_fixed_rounded, color: AppColors.primary, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            state.translate('gps_active'),
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Search bar
            TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: state.translate('search_farm_hint'),
                hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.outline),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Dynamic Province Chips
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: provincesList.length,
                itemBuilder: (context, idx) {
                  final p = provincesList[idx];
                  final isSel = p.toLowerCase() == _selectedProvince.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(
                        p == 'All' ? state.translate('all') : state.translate(p),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel ? Colors.white : AppColors.onSurfaceVariant,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      onSelected: (_) {
                        setState(() {
                          _selectedProvince = p;
                        });
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Nearest-first sort toggle — only meaningful once we actually
            // know where the buyer is; disabled (not hidden, so it's clear
            // why) otherwise rather than silently doing nothing.
            Row(
              children: [
                Switch(
                  value: _sortByNearest,
                  onChanged: myLocationKnown ? (val) => setState(() => _sortByNearest = val) : null,
                  activeTrackColor: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    myLocationKnown ? state.translate('sort_nearest_first') : state.translate('sort_nearest_unavailable'),
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Producers Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedProvince == 'All'
                      ? state.translate('producers_across_cambodia')
                      : state.translate('producers_in_province', arguments: {'province': state.translate(_selectedProvince)}),
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  state.translate('farms_count', arguments: {'count': filteredProducers.length.toString()}),
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.outline),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (filteredProducers.isEmpty)
              CustomCard(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.location_off_rounded, size: 40, color: AppColors.outline),
                      const SizedBox(height: 8),
                      Text(
                        state.translate('no_farms_found'),
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.outline),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...filteredProducers.map((prod) => _buildFarmListItem(context, state, prod)),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmListItem(BuildContext context, AppState state, Map<String, dynamic> prod) {
    final List<MarketProduct> crops = prod['crops'];
    final double? distanceKm = prod['distanceKm'] as double?;
    final double? avgRating = prod['averageRating'] as double?;
    final int reviewCount = prod['reviewCount'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: CustomCard(
        padding: const EdgeInsets.all(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FarmProfileScreen(
                farmerName: prod['farmerName'],
                isVerifiedFarmer: prod['isVerified'],
                location: prod['location'],
                sellerId: (prod['crops'] as List<MarketProduct>).isNotEmpty
                    ? (prod['crops'] as List<MarketProduct>).first.sellerId
                    : null,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.agriculture_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              prod['farmerName'],
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (prod['isVerified']) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, color: AppColors.primary, size: 16),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(prod['location'], style: GoogleFonts.inter(fontSize: 11, color: AppColors.outline)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (reviewCount > 0 && avgRating != null) ...[
                            const Icon(Icons.star_rounded, color: Colors.orange, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${avgRating.toStringAsFixed(1)} ($reviewCount)',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ] else ...[
                            Icon(Icons.star_border_rounded, color: AppColors.outline, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              state.translate('new_seller_label'),
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.outline),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      distanceKm != null
                          ? state.translate('distance_km_value', arguments: {'km': distanceKm.toStringAsFixed(1)})
                          : state.translate('distance_unavailable'),
                      textAlign: TextAlign.end,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: distanceKm != null ? 13 : 10,
                        color: distanceKm != null ? AppColors.primary : AppColors.outline,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(state.translate('crops_count', arguments: {'count': prod['cropCount'].toString()}), style: GoogleFonts.inter(fontSize: 10, color: AppColors.outline)),
                  ],
                ),
              ],
            ),
            if (crops.isNotEmpty) ...[
              const Divider(height: 20),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: crops.take(3).map((c) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${c.name} (${c.formattedPrice}/${c.unit})',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  );
                }).toList(),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
