import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/app_snackbar.dart';
import '../../services/api/bookmark_api.dart';
import '../../utils/api_error.dart';

class SavedCropsScreen extends StatefulWidget {
  const SavedCropsScreen({super.key});

  @override
  State<SavedCropsScreen> createState() => _SavedCropsScreenState();
}

class _SavedCropsScreenState extends State<SavedCropsScreen> {
  bool _isLoading = true;
  List<dynamic> _bookmarks = [];

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    try {
      final res = await BookmarkApi.fetchBookmarks(state.token!);
      setState(() {
        _bookmarks = res;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeBookmark(String productId) async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) return;
    try {
      await BookmarkApi.removeBookmark(state.token!, productId);
      setState(() {
        _bookmarks.removeWhere((b) => b['product_id'] == productId || b['product']?['id'] == productId);
      });
      if (mounted) {
        AppSnackBar.success(context, state.translate('removed_from_saved'));
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, friendlyApiError(state, e));
      }
    }
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
          state.translate('saved_listings'),
          style: GoogleFonts.inter(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookmarks.isEmpty
              ? Center(
                  child: Text(
                    state.translate('no_saved_crops'),
                    style: GoogleFonts.inter(color: AppColors.outline),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _bookmarks.length,
                  itemBuilder: (context, index) {
                    final item = _bookmarks[index];
                    final prodData = item['product'] ?? {};
                    final productId = prodData['id'] ?? item['product_id'] ?? '';
                    final prodName = prodData['product_name'] ?? state.translate('crop_listing');
                    final price = (prodData['price_per_unit'] as num?)?.toDouble() ?? 0.0;
                    final unit = prodData['unit_type'] ?? 'kg';

                    final currency = prodData['currency'] ?? 'USD';
                    final String formattedDisplayPrice = currency == 'KHR'
                        ? '${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} ៛ / $unit'
                        : '\$${price.toStringAsFixed(2)} / $unit';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: CustomCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.outlineVariant.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.eco_rounded, color: AppColors.primary, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    prodName,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    formattedDisplayPrice,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.bookmark_remove_rounded, color: AppColors.primary),
                              onPressed: () => _removeBookmark(productId),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
