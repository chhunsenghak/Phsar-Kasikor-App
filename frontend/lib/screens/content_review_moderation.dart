import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_button.dart';

class ContentReviewModerationScreen extends StatefulWidget {
  const ContentReviewModerationScreen({super.key});

  @override
  State<ContentReviewModerationScreen> createState() => _ContentReviewModerationScreenState();
}

class _ContentReviewModerationScreenState extends State<ContentReviewModerationScreen> {
  // Mock flagged item list
  final List<Map<String, dynamic>> _flaggedItems = [
    {
      'id': 'f1',
      'title': 'Chemical Pest Killer Grade-D',
      'category': 'Chemicals',
      'reason': 'Prohibited substance. Platform rules only allow organic bio-pest control products.',
      'reportedBy': 'User Sophy Ly',
      'reporterNote': 'This contains banned chemicals that violate organic tech guidelines.',
    }
  ];

  void _dismissFlag(String id, String action) {
    setState(() {
      _flaggedItems.removeWhere((item) => item['id'] == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Item action completed: $action')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Content Moderation',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Audit reported products, comment logs and community guidelines flags',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: _flaggedItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.done_all_rounded,
                            size: 64,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Moderation Queue Empty',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'All listings meet platform criteria.',
                          style: GoogleFonts.inter(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _flaggedItems.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final item = _flaggedItems[index];

                      return CustomCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item['title'] as String,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'FLAGGED',
                                    style: GoogleFonts.inter(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Violation Reason:',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['reason'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.outline),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Reported by: ${item['reportedBy']} (${item['reporterNote']})',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.outline,
                                    ),
                                  ),
                                )
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: CustomButton(
                                    text: 'Remove Product',
                                    height: 44,
                                    backgroundColor: AppColors.error,
                                    onPressed: () {
                                      _dismissFlag(item['id'] as String, 'Removed Listing');
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: CustomButton.secondary(
                                    text: 'Dismiss Report',
                                    height: 44,
                                    onPressed: () {
                                      _dismissFlag(item['id'] as String, 'Dismissed Report');
                                    },
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
