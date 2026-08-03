import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';

class CooperativeDashboardScreen extends StatefulWidget {
  const CooperativeDashboardScreen({super.key});

  @override
  State<CooperativeDashboardScreen> createState() => _CooperativeDashboardScreenState();
}

class _CooperativeDashboardScreenState extends State<CooperativeDashboardScreen> {
  final List<Map<String, dynamic>> _members = [
    {
      'name': 'Sok Farmer',
      'location': 'Sangkae, Battambang',
      'productsCount': 3,
      'status': 'Active',
      'certPending': 'COrAA Organic Standard',
    },
    {
      'name': 'Sopheap Organic Farm',
      'location': 'Banonom, Battambang',
      'productsCount': 4,
      'status': 'Active',
      'certPending': 'CamGAP Certificate',
    },
    {
      'name': 'Banteay Meanchey Cooperative',
      'location': 'Mongkol Borey, Banteay Meanchey',
      'productsCount': 2,
      'status': 'Pending Approval',
      'certPending': null,
    }
  ];

  void _endorseMember(BuildContext context, AppState state, String memberName, String cert) {
    state.addNotification(
      'Certification Endorsed',
      'Cooperative officially endorsed $memberName for certificate: $cert.',
    );
    _showPremiumStatusDialog(context, state, true, 'Endorsement Successful', 'Successfully endorsed $memberName for MAFF review.');
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final count = _members.where((m) => m['status'] == 'Active').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.translate('coop_dashboard'),
                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.translate('coop_member_count').replaceAll('{count}', count.toString()),
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
                  child: const Icon(Icons.group_work_rounded, color: AppColors.onPrimaryContainer, size: 24),
                )
              ],
            ),
            const SizedBox(height: 24),

            // Production Aggregator Section
            Text(
              state.translate('total_coop_stock'),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
            const SizedBox(height: 12),
            _buildAggregatedStockCard(state),

            const SizedBox(height: 24),

            // Member Directory
            Text(
              state.translate('member_directory'),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
            const SizedBox(height: 12),
            ..._members.map((member) => _buildMemberCard(context, state, member)),

            const SizedBox(height: 24),

            // Endorsements
            Text(
              'Pending Endorsements',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
            const SizedBox(height: 12),
            _buildEndorsementsQueue(context, state),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAggregatedStockCard(AppState state) {
    final stocks = [
      {'crop': 'Jasmine Rice', 'qty': '3,500 kg', 'farms': '3 Farms'},
      {'crop': 'Ginger Roots', 'qty': '1,200 kg', 'farms': '2 Farms'},
      {'crop': 'Battambang Oranges', 'qty': '800 kg', 'farms': '1 Farm'},
    ];

    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: stocks.map((s) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      s['crop']!,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      s['qty']!,
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${s['farms']!})',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.outline),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMemberCard(BuildContext context, AppState state, Map<String, dynamic> member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: CustomCard(
        padding: const EdgeInsets.all(16),
        onTap: () => _showMemberDetailsSheet(context, state, member),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.secondaryContainer, shape: BoxShape.circle),
              child: const Icon(Icons.person_outline_rounded, color: AppColors.onSecondaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member['name']!, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(member['location']!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.outline)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: member['status'] == 'Active' ? AppColors.primary.withValues(alpha: 0.1) : AppColors.outlineVariant.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    member['status']!,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: member['status'] == 'Active' ? AppColors.primary : AppColors.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${member['productsCount']} Crops',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndorsementsQueue(BuildContext context, AppState state) {
    final list = _members.where((m) => m['certPending'] != null).toList();
    if (list.isEmpty) {
      return CustomCard(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('All certificates endorsed.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.outline)),
        ),
      );
    }

    return Column(
      children: list.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: CustomCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name']!, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(item['certPending']!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                CustomButton(
                  text: state.translate('coop_endorse'),
                  backgroundColor: AppColors.primary,
                  onPressed: () => _endorseMember(context, state, item['name']!, item['certPending']!),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showMemberDetailsSheet(BuildContext context, AppState state, Map<String, dynamic> member) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member['name']!,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Location: ${member['location']!}',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.outline),
              ),
              const Divider(height: 32),
              Text(
                'Active Cooperative Listings',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.eco_rounded, color: AppColors.primary),
                title: Text('Phka Rumduol Jasmine Rice', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                trailing: Text('1,500 kg', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.eco_rounded, color: AppColors.primary),
                title: Text('Organic Battambang Oranges', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                trailing: Text('800 kg', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: state.translate('cancel'),
                backgroundColor: AppColors.outlineVariant,
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
        );
      },
    );
  }

  void _showPremiumStatusDialog(BuildContext context, AppState state, bool isSuccess, String title, String body) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Status Dialog',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curve,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isSuccess ? AppColors.primary.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                        color: isSuccess ? AppColors.primary : AppColors.error,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      body,
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        text: state.translate('ok'),
                        backgroundColor: isSuccess ? AppColors.primary : AppColors.error,
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _members.removeWhere((m) => m['name'] == 'Sok Farmer');
                          });
                        },
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
