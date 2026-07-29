import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';

// Import all screens
import '../buyer/marketplace_home.dart';
import '../buyer/market_price_tracker.dart';
import '../buyer/community_portal.dart';
import 'user_profile_settings.dart';
import '../farmer/farmer_dashboard.dart';
import '../admin/admin_dashboard_overview.dart';
import '../admin/refined_farmer_verification_queue.dart';
import '../admin/content_review_moderation.dart';
import 'notification_center.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final String role = state.currentRole;

    // Resolve the navigation list based on the user's role
    final List<Map<String, dynamic>> navItems = _getNavItemsForRole(state, role);

    // Clamp index to prevent out-of-range on role change
    int selectedIndex = state.currentNavIndex;
    if (selectedIndex >= navItems.length) {
      selectedIndex = 0;
    }

    final activeWidget = navItems[selectedIndex]['screen'] as Widget;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.eco_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'AgriMarket',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        actions: [
          // Role quick-pill display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _getRoleBadgeColor(role),
              borderRadius: BorderRadius.circular(AppDesign.borderRadiusSm),
            ),
            child: Center(
              child: Text(
                role.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _getRoleTextColor(role),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Notifications Icon Button
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: AppColors.onSurface),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationCenterScreen(),
                    ),
                  );
                },
              ),
              // Unread notification dot
              if (state.notifications.any((n) => !n['isRead']))
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
            ],
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
            height: 1,
          ),
        ),
      ),
      body: activeWidget,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: AppDesign.level1Shadow,
          border: Border(
            top: BorderSide(
              color: AppColors.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: state.currentNavIndex >= navItems.length ? 0 : state.currentNavIndex,
          onTap: (index) {
            state.setNavIndex(index);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.outline,
          selectedLabelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          items: navItems.map((item) {
            return BottomNavigationBarItem(
              icon: Icon(item['icon'] as IconData),
              activeIcon: Icon(item['activeIcon'] as IconData),
              label: item['label'] as String,
            );
          }).toList(),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getNavItemsForRole(AppState state, String role) {
    if (role == 'farmer' || role == 'association') {
      return [
        {
          'label': state.translate('dashboard'),
          'icon': Icons.dashboard_outlined,
          'activeIcon': Icons.dashboard_rounded,
          'screen': const FarmerDashboardScreen(),
        },
        {
          'label': state.translate('prices'),
          'icon': Icons.trending_up_outlined,
          'activeIcon': Icons.trending_up_rounded,
          'screen': const MarketPriceTrackerScreen(),
        },
        {
          'label': state.translate('community'),
          'icon': Icons.forum_outlined,
          'activeIcon': Icons.forum_rounded,
          'screen': const CommunityPortalScreen(),
        },
        {
          'label': state.translate('profile'),
          'icon': Icons.person_outline_rounded,
          'activeIcon': Icons.person_rounded,
          'screen': const UserProfileSettingsScreen(),
        },
      ];
    } else if (role == 'admin') {
      return [
        {
          'label': state.translate('admin_panel'),
          'icon': Icons.admin_panel_settings_outlined,
          'activeIcon': Icons.admin_panel_settings_rounded,
          'screen': const AdminDashboardOverviewScreen(),
        },
        {
          'label': state.translate('verifications'),
          'icon': Icons.verified_outlined,
          'activeIcon': Icons.verified_rounded,
          'screen': const RefinedFarmerVerificationQueueScreen(),
        },
        {
          'label': state.translate('moderation'),
          'icon': Icons.gavel_outlined,
          'activeIcon': Icons.gavel_rounded,
          'screen': const ContentReviewModerationScreen(),
        },
        {
          'label': state.translate('profile'),
          'icon': Icons.person_outline_rounded,
          'activeIcon': Icons.person_rounded,
          'screen': const UserProfileSettingsScreen(),
        },
      ];
    } else {
      // Default: Buyer
      return [
        {
          'label': state.translate('marketplace'),
          'icon': Icons.storefront_outlined,
          'activeIcon': Icons.storefront_rounded,
          'screen': const MarketplaceHomeScreen(),
        },
        {
          'label': state.translate('prices'),
          'icon': Icons.trending_up_outlined,
          'activeIcon': Icons.trending_up_rounded,
          'screen': const MarketPriceTrackerScreen(),
        },
        {
          'label': state.translate('community'),
          'icon': Icons.forum_outlined,
          'activeIcon': Icons.forum_rounded,
          'screen': const CommunityPortalScreen(),
        },
        {
          'label': state.translate('profile'),
          'icon': Icons.person_outline_rounded,
          'activeIcon': Icons.person_rounded,
          'screen': const UserProfileSettingsScreen(),
        },
      ];
    }
  }

  Color _getRoleBadgeColor(String role) {
    if (role == 'farmer' || role == 'association') return AppColors.secondaryContainer;
    if (role == 'admin') return AppColors.errorContainer;
    return AppColors.primaryContainer.withValues(alpha: 0.15);
  }

  Color _getRoleTextColor(String role) {
    if (role == 'farmer' || role == 'association') return AppColors.onSecondaryContainer;
    if (role == 'admin') return AppColors.error;
    return AppColors.primary;
  }
}
