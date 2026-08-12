import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import 'disputes_screen.dart';

// TODO: placeholder contact details — replace with the real support
// email/phone once one exists. Nothing in this app wires up a live
// contact channel today, so these are shown as-is rather than invented
// to look more "real" than they are.
const String _kSupportEmail = 'support@phsarkasikor.com';
const String _kSupportPhone = '+855 12 345 678';

class HelpDisputesScreen extends StatelessWidget {
  const HelpDisputesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final faqs = _buildFaqs(state);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
        title: Text(
          state.translate('help_disputes'),
          style: GoogleFonts.inter(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CustomCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.translate('contact_support'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  state.translate('contact_support_hint'),
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.email_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(_kSupportEmail, style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurface)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(_kSupportPhone, style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurface)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            state.translate('faq_title'),
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.onSurface),
          ),
          const SizedBox(height: 12),
          CustomCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < faqs.length; i++) ...[
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: Text(
                        faqs[i].$1,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.onSurface),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          faqs[i].$2,
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  if (i < faqs.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          CustomCard(
            padding: const EdgeInsets.all(16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DisputesScreen()),
            ),
            child: Row(
              children: [
                const Icon(Icons.gavel_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.translate('my_disputes'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.onSurface),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.outline),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<(String, String)> _buildFaqs(AppState state) {
    return [
      (state.translate('faq_q_khqr'), state.translate('faq_a_khqr')),
      (state.translate('faq_q_contract'), state.translate('faq_a_contract')),
      (state.translate('faq_q_final_payment'), state.translate('faq_a_final_payment')),
      (state.translate('faq_q_tracking'), state.translate('faq_a_tracking')),
      (state.translate('faq_q_report_problem'), state.translate('faq_a_report_problem')),
      (state.translate('faq_q_dispute_outcome'), state.translate('faq_a_dispute_outcome')),
      (state.translate('faq_q_verification'), state.translate('faq_a_verification')),
    ];
  }
}
