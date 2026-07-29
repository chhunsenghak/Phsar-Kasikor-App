import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';

class AdminDashboardOverviewScreen extends StatelessWidget {
  const AdminDashboardOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final verifications = state.verifications.where((v) => v.status == 'pending').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hello Header
          Text(
            'System Control Panel',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Security overview, verification audits & moderations',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          // Overview stats
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildAdminStatCard(
                label: 'Total Farmers',
                value: '124',
                icon: Icons.agriculture_rounded,
                color: AppColors.primary,
              ),
              _buildAdminStatCard(
                label: 'Pending Reviews',
                value: '${verifications.length}',
                icon: Icons.hourglass_empty_rounded,
                color: Colors.amber[900]!,
              ),
              _buildAdminStatCard(
                label: 'Flagged Content',
                value: '1',
                icon: Icons.flag_rounded,
                color: AppColors.error,
              ),
              _buildAdminStatCard(
                label: 'Open Disputes',
                value: '0',
                icon: Icons.gavel_rounded,
                color: AppColors.tertiary,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Platform Activities Log
          Text(
            'System Activity Log',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          CustomCard(
            padding: EdgeInsets.zero,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final logs = [
                  {'event': 'Farmer Chan Sopheap published "Organic Jasmine Rice"', 'time': '10 mins ago', 'type': 'listing'},
                  {'event': 'Buyer Kosal Pich registered new profile', 'time': '40 mins ago', 'type': 'user'},
                  {'event': 'Farmer Rithy Seng uploaded verification certificate', 'time': '1 hour ago', 'type': 'verification'},
                  {'event': 'Listing "Fake Chemicals" flagged for removal', 'time': '3 hours ago', 'type': 'moderation'},
                ];

                final log = logs[index];
                IconData logIcon = Icons.info_outline_rounded;
                Color logColor = AppColors.primary;

                if (log['type'] == 'user') {
                  logIcon = Icons.person_add_outlined;
                  logColor = AppColors.secondary;
                } else if (log['type'] == 'verification') {
                  logIcon = Icons.file_present_rounded;
                  logColor = Colors.amber[800]!;
                } else if (log['type'] == 'moderation') {
                  logIcon = Icons.report_problem_outlined;
                  logColor = AppColors.error;
                }

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: logColor.withValues(alpha: 0.1),
                    child: Icon(logIcon, color: logColor, size: 20),
                  ),
                  title: Text(
                    log['event']!,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  trailing: Text(
                    log['time']!,
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.outline),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAdminStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              const Icon(Icons.arrow_outward_rounded, size: 16, color: AppColors.outline),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
