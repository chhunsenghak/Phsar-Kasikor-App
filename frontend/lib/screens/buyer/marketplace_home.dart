import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/trust_badge.dart';
import 'product_detail.dart';
import '../common/error_screens.dart';

class MarketplaceHomeScreen extends StatefulWidget {
  const MarketplaceHomeScreen({super.key});

  @override
  State<MarketplaceHomeScreen> createState() => _MarketplaceHomeScreenState();
}

class _MarketplaceHomeScreenState extends State<MarketplaceHomeScreen> {
  bool _isGridView = true;
  String _selectedLocation = 'All';
  String _sortBy = 'none'; // 'none', 'price_asc', 'price_desc'

  static const List<String> _allProvinces = [
    'All',
    'Banteay Meanchey',
    'Battambang',
    'Kampong Cham',
    'Kampong Chhnang',
    'Kampong Speu',
    'Kampong Thom',
    'Kampot',
    'Kandal',
    'Kep',
    'Koh Kong',
    'Kratie',
    'Mondulkiri',
    'Oddar Meanchey',
    'Pailin',
    'Phnom Penh',
    'Preah Sihanouk',
    'Preah Vihear',
    'Prey Veng',
    'Pursat',
    'Ratanakiri',
    'Siem Reap',
    'Stung Treng',
    'Svay Rieng',
    'Takeo',
    'Tboung Khmum',
  ];

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    // 1. Dynamic province collection & crop count mapping
    final Map<String, int> provinceCropCounts = {'All': state.products.length};
    for (var prov in _allProvinces) {
      if (prov != 'All') {
        final count = state.products.where((p) => p.location.toLowerCase().contains(prov.toLowerCase())).length;
        provinceCropCounts[prov] = count;
      }
    }

    final locationsList = List<String>.from(_allProvinces);

    // 2. Filter products by category, search query, location, and price sort
    var filtered = state.filteredProducts.where((p) {
      if (_selectedLocation == 'All') return true;
      return p.location.toLowerCase().contains(_selectedLocation.toLowerCase());
    }).toList();

    if (_sortBy == 'price_asc') {
      filtered.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortBy == 'price_desc') {
      filtered.sort((a, b) => b.price.compareTo(a.price));
    }

    final List<String> categories = [
      'All',
      ...state.backendCategories.map((c) => c['name']?.toString() ?? '').where((n) => n.isNotEmpty)
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildSearchAndFilterBar(state, categories, locationsList),
          const SizedBox(height: 12),
          _buildCategoryChips(state, categories),
          const SizedBox(height: 10),
          _buildLocationChips(state, locationsList, provinceCropCounts),
          const SizedBox(height: 16),
          if (state.searchQuery.isEmpty) ...[
            _buildPromoBanner(state),
            const SizedBox(height: 16),
          ],
          _buildViewToggleHeaders(state),
          const SizedBox(height: 8),
          _isGridView
              ? _buildProductGrid(context, state, filtered)
              : _buildProductList(context, state, filtered),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar(AppState state, List<String> categories, List<String> provinces) {
    final bool hasActiveFilter = state.selectedCategory != 'All' || _selectedLocation != 'All' || _sortBy != 'none';

    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (val) => state.setSearchQuery(val),
            decoration: InputDecoration(
              hintText: state.translate('search_hint'),
              hintStyle: GoogleFonts.inter(color: AppColors.outline, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
              filled: true,
              fillColor: AppColors.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDesign.borderRadiusDefault),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: hasActiveFilter ? AppColors.primaryContainer : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.tune_rounded,
                  color: hasActiveFilter ? Colors.white : AppColors.onSurfaceVariant,
                ),
                onPressed: () => _showFilterBottomSheet(context, state, categories, provinces),
              ),
            ),
            if (hasActiveFilter)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryChips(AppState state, List<String> categories) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = state.selectedCategory == category;
          return ChoiceChip(
            label: Text(
              state.translate(category.toLowerCase()),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant,
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.secondaryContainer,
            backgroundColor: AppColors.surfaceContainerLow,
            onSelected: (selected) {
              if (selected) state.setCategory(category);
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesign.borderRadiusDefault),
              side: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 1,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocationChips(AppState state, List<String> locations, Map<String, int> cropCounts) {
    // Show active locations first plus 'All'
    final activeLocations = locations.where((l) => l == 'All' || (cropCounts[l] ?? 0) > 0).toList();

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: activeLocations.length + 1, // +1 for "All 25 Provinces..."
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == activeLocations.length) {
            return ActionChip(
              avatar: const Icon(Icons.unfold_more_rounded, size: 16, color: AppColors.primary),
              label: Text(
                state.translate('all_provinces_chip'),
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.15),
              onPressed: () => _showFilterBottomSheet(context, state, state.backendCategories.map((c) => c['name']?.toString() ?? '').toList(), locations),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
            );
          }

          final loc = activeLocations[index];
          final isSelected = _selectedLocation == loc;
          final count = cropCounts[loc] ?? 0;

          final labelText = loc == 'All'
              ? state.translate('all_locations', arguments: {'count': count.toString()})
              : '${state.translate(loc)} ($count)';

          return FilterChip(
            avatar: Icon(
              Icons.location_on_rounded,
              size: 14,
              color: isSelected ? Colors.white : AppColors.primary,
            ),
            label: Text(
              labelText,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.onSurface,
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surfaceContainerLow,
            onSelected: (selected) {
              setState(() {
                _selectedLocation = loc;
              });
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                width: 1,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context, AppState state, List<String> categories, List<String> provinces) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final tempLocation = _selectedLocation;
            final tempCategory = state.selectedCategory;

            // Compute dynamic count preview
            final previewCount = state.products.where((p) {
              final matchCat = tempCategory == 'All' || p.category == tempCategory;
              final matchLoc = tempLocation == 'All' || p.location.toLowerCase().contains(tempLocation.toLowerCase());
              final matchSearch = state.searchQuery.isEmpty || p.name.toLowerCase().contains(state.searchQuery.toLowerCase());
              return matchCat && matchLoc && matchSearch;
            }).length;

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        state.translate('filter_sort_crops'),
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedLocation = 'All';
                            _sortBy = 'none';
                            state.setCategory('All');
                          });
                          setModalState(() {});
                        },
                        child: Text(
                          state.translate('reset_all'),
                          style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // 1. Province Dropdown Select
                  Text(
                    state.translate('province_location'),
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: provinces.contains(_selectedLocation) ? _selectedLocation : 'All',
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.map_rounded, color: AppColors.primary),
                    ),
                    items: provinces.map((prov) {
                      final count = prov == 'All'
                          ? state.products.length
                          : state.products.where((p) => p.location.toLowerCase().contains(prov.toLowerCase())).length;
                      final itemText = prov == 'All'
                          ? state.translate('all_provinces_count', arguments: {'count': count.toString()})
                          : state.translate('province_crops_count', arguments: {
                              'province': state.translate(prov),
                              'count': count.toString(),
                            });
                      return DropdownMenuItem(
                        value: prov,
                        child: Text(
                          itemText,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: prov == 'All' ? FontWeight.bold : FontWeight.normal),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedLocation = val;
                        });
                        setModalState(() {});
                      }
                    },
                  ),

                  const SizedBox(height: 20),

                  // 2. Sort By Price Options
                  Text(
                    state.translate('sort_price'),
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text(state.translate('sort_default')),
                          selected: _sortBy == 'none',
                          onSelected: (_) {
                            setState(() => _sortBy = 'none');
                            setModalState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(state.translate('sort_low_to_high')),
                          selected: _sortBy == 'price_asc',
                          onSelected: (_) {
                            setState(() => _sortBy = 'price_asc');
                            setModalState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(state.translate('sort_high_to_low')),
                          selected: _sortBy == 'price_desc',
                          onSelected: (_) {
                            setState(() => _sortBy = 'price_desc');
                            setModalState(() {});
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        state.translate('apply_filters_count', arguments: {'count': previewCount.toString()}),
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildViewToggleHeaders(AppState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          state.translate('available_crops'),
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
              onPressed: () {
                setState(() {
                  _isGridView = true;
                });
              },
            ),
            IconButton(
              icon: Icon(
                Icons.view_list_rounded,
                color: !_isGridView ? AppColors.primary : AppColors.outline,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _isGridView = false;
                });
              },
            ),
          ],
        )
      ],
    );
  }



  Widget _buildPromoBanner(AppState state) {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      backgroundColor: AppColors.primaryContainer,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.translate('direct_from_farms'),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  state.translate('direct_from_farms_desc'),
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.agriculture_rounded,
            size: 48,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(BuildContext context, AppState state, List<dynamic> products) {
    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          children: [
            const NoResultsScreen(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedLocation = 'All';
                  _sortBy = 'none';
                  state.setCategory('All');
                  state.setSearchQuery('');
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Reset All Filters',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(context, state, product);
      },
    );
  }

  Widget _buildProductList(BuildContext context, AppState state, List<dynamic> products) {
    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          children: [
            const NoResultsScreen(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedLocation = 'All';
                  _sortBy = 'none';
                  state.setCategory('All');
                  state.setSearchQuery('');
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Reset All Filters',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductTile(context, state, product);
      },
    );
  }

  Widget _buildProductCard(BuildContext context, AppState state, dynamic product) {
    final formattedPrice = '${product.formattedPrice} / ${product.unit}';

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
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppDesign.borderRadiusDefault),
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.agriculture_rounded,
                      size: 48,
                      color: AppColors.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  if (product.isVerifiedFarmer)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: const TrustBadge(
                        certType: 'GAP',
                        isMini: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
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
                const SizedBox(height: 2),
                Text(
                  product.farmerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.outline,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        formattedPrice,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Text(
                      '${product.quantity.toInt()} ${product.unit}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurfaceVariant,
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

  Widget _buildProductTile(BuildContext context, AppState state, dynamic product) {
    final formattedPrice = '${product.formattedPrice} / ${product.unit}';

    return CustomCard(
      padding: const EdgeInsets.all(12),
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
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppDesign.borderRadiusDefault),
            ),
            child: Icon(
              Icons.agriculture_rounded,
              size: 32,
              color: AppColors.outline.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    if (product.isVerifiedFarmer)
                      const TrustBadge(
                        certType: 'GAP',
                        isMini: true,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${product.farmerName} • ${product.location}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.outline,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formattedPrice,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '${product.quantity.toInt()} ${product.unit} in stock',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
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
}
