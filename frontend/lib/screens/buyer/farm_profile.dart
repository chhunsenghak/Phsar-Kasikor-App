import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../services/api/review_api.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/trust_badge.dart';
import 'product_detail.dart';

class FarmProfileScreen extends StatefulWidget {
  final String farmerName;
  final bool isVerifiedFarmer;
  final String location;
  // Real backend user id for this farmer — only known at call sites that
  // have a MarketProduct on hand (product.sellerId). Null when this screen
  // is reached some other way; the reviews section just stays empty then.
  final String? sellerId;

  const FarmProfileScreen({
    super.key,
    required this.farmerName,
    this.isVerifiedFarmer = false,
    required this.location,
    this.sellerId,
  });

  @override
  State<FarmProfileScreen> createState() => _FarmProfileScreenState();
}

class _FarmProfileScreenState extends State<FarmProfileScreen> {
  bool _isGridView = true;
  bool _isLoadingReviews = true;
  List<dynamic> _reviews = [];
  double _averageRating = 0.0;
  int _reviewCount = 0;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null || widget.sellerId == null) {
      setState(() => _isLoadingReviews = false);
      return;
    }
    try {
      final results = await Future.wait([
        ReviewApi.fetchSellerReviews(state.token!, widget.sellerId!),
        ReviewApi.fetchSellerReviewSummary(state.token!, widget.sellerId!),
      ]);
      if (!mounted) return;
      setState(() {
        _reviews = results[0] as List<dynamic>;
        final summary = results[1] as Map<String, dynamic>;
        _averageRating = (summary['average_rating'] as num?)?.toDouble() ?? 0.0;
        _reviewCount = (summary['review_count'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {
      // Reviews are a supplementary section — a failed fetch shouldn't
      // block the rest of the farm profile from rendering.
    } finally {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final farmProducts = state.products
        .where((p) => p.farmerName.toLowerCase() == widget.farmerName.toLowerCase())
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: _buildFarmDetailsHeader(farmProducts.length),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildLayoutSectionHeader(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            sliver: farmProducts.isEmpty
                ? SliverToBoxAdapter(child: _buildEmptyState())
                : (_isGridView
                    ? _buildSliverGrid(context, farmProducts)
                    : _buildSliverList(context, farmProducts)),
          ),
          if (widget.sellerId != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildReviewsSection(state),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildReviewsSection(AppState state) {
    if (_isLoadingReviews) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              state.translate('reviews_label'),
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
            const SizedBox(width: 10),
            if (_reviewCount > 0) ...[
              const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 2),
              Text(
                _averageRating.toStringAsFixed(1),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(width: 4),
              Text(
                '(${state.translate('reviews_count_label', arguments: {'count': _reviewCount.toString()})})',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (_reviews.isEmpty)
          Text(
            state.translate('no_reviews_yet'),
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.outline),
          )
        else
          ..._reviews.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: CustomCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            r['reviewer_name']?.toString() ?? '',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Row(
                            children: List.generate(5, (i) {
                              final rating = (r['rating'] as num?)?.toInt() ?? 0;
                              return Icon(
                                i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 14,
                                color: Colors.amber.shade700,
                              );
                            }),
                          ),
                        ],
                      ),
                      if ((r['comment']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          r['comment'].toString(),
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180.0,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const CircleAvatar(
          backgroundColor: Colors.black26,
          child: Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background Gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Abstract Farm Pattern Overlay
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                Icons.agriculture_rounded,
                size: 200,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmDetailsHeader(int productCount) {
    final state = Provider.of<AppState>(context);
    final certType = state.getFarmerCertType(widget.farmerName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.secondaryContainer,
              child: Text(
                widget.farmerName.isNotEmpty ? widget.farmerName[0].toUpperCase() : 'F',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.farmerName,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TrustBadge(certType: certType, isMini: true),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        state.translateLocation(widget.location),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: certType != 'none' ? AppColors.primaryContainer : AppColors.outlineVariant.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      certType != 'none'
                          ? state.translate('certified_farm_badge', arguments: {'certType': certType.toUpperCase()})
                          : state.translate('community_producer_badge'),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: certType != 'none' ? AppColors.onPrimaryContainer : AppColors.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Farm Description
        Text(
          state.translate('about_the_farm'),
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          state.translate('about_farm_desc', arguments: {'location': widget.location}),
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.4,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        // Stats Cards Row
        Row(
          children: [
            Expanded(
              child: CustomCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(
                      '$productCount',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.translate('listed_crops_stat'),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(
                      widget.isVerifiedFarmer ? '100%' : '95%',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.translate('fulfillment_rate'),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLayoutSectionHeader() {
    final state = Provider.of<AppState>(context, listen: false);
    return Column(
      children: [
        const Divider(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              state.translate('farm_products'),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.grid_view_rounded,
                    color: _isGridView ? AppColors.primary : AppColors.outline,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _isGridView = true),
                ),
                IconButton(
                  icon: Icon(
                    Icons.view_list_rounded,
                    color: !_isGridView ? AppColors.primary : AppColors.outline,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _isGridView = false),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final state = Provider.of<AppState>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.grass_rounded, size: 64, color: AppColors.outlineVariant),
            const SizedBox(height: 12),
            Text(
              state.translate('no_listed_products'),
              style: GoogleFonts.inter(color: AppColors.outline, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverGrid(BuildContext context, List<MarketProduct> products) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.76,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final product = products[index];
          return _buildGridCard(context, product);
        },
        childCount: products.length,
      ),
    );
  }

  Widget _buildGridCard(BuildContext context, MarketProduct product) {
    final state = Provider.of<AppState>(context, listen: false);
    return CustomCard(
      padding: EdgeInsets.zero,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLow,
              ),
              child: Center(
                child: product.imageUrl.isNotEmpty
                    ? Image.network(
                        product.resolvedImageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            product.category == 'Grains'
                                ? Icons.grass_rounded
                                : (product.category == 'Fruits'
                                    ? Icons.apple_rounded
                                    : Icons.egg_rounded),
                            size: 40,
                            color: AppColors.primary.withValues(alpha: 0.3),
                          );
                        },
                      )
                    : Icon(
                        product.category == 'Grains'
                            ? Icons.grass_rounded
                            : (product.category == 'Fruits'
                                ? Icons.apple_rounded
                                : Icons.egg_rounded),
                        size: 40,
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${product.formattedPrice}/${product.unit}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      state.translate('stock_prefix', arguments: {'qty': product.quantity.toInt().toString()}),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverList(BuildContext context, List<MarketProduct> products) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final product = products[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildListCard(context, product),
          );
        },
        childCount: products.length,
      ),
    );
  }

  Widget _buildListCard(BuildContext context, MarketProduct product) {
    final state = Provider.of<AppState>(context, listen: false);
    return CustomCard(
      padding: EdgeInsets.zero,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLow,
            ),
            child: Center(
              child: product.imageUrl.isNotEmpty
                  ? Image.network(
                      product.resolvedImageUrl,
                      fit: BoxFit.cover,
                      width: 80,
                      height: 80,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          product.category == 'Grains'
                              ? Icons.grass_rounded
                              : (product.category == 'Fruits'
                                  ? Icons.apple_rounded
                                  : Icons.egg_rounded),
                          size: 32,
                          color: AppColors.primary.withValues(alpha: 0.3),
                        );
                      },
                    )
                  : Icon(
                      product.category == 'Grains'
                          ? Icons.grass_rounded
                          : (product.category == 'Fruits'
                              ? Icons.apple_rounded
                              : Icons.egg_rounded),
                      size: 32,
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.translate('category_prefix', arguments: {'category': product.category}),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${product.formattedPrice}/${product.unit}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        state.translate('stock_prefix_unit', arguments: {
                          'qty': product.quantity.toInt().toString(),
                          'unit': product.unit,
                        }),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.outline,
                        ),
                      ),
                    ],
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
