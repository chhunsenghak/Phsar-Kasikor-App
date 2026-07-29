import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final notifications = state.notifications;

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
          'Notification Center',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              state.markAllNotificationsRead();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All notifications marked as read')),
              );
            },
            child: Text(
              'Mark all read',
              style: GoogleFonts.inter(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    size: 72,
                    color: AppColors.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'All Caught Up!',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No new alerts or activities.',
                    style: GoogleFonts.inter(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                final bool isRead = notif['isRead'] as bool;

                return CustomCard(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: isRead ? AppColors.surface : AppColors.surfaceContainerLowest,
                  borderSide: isRead
                      ? BorderSide.none
                      : const BorderSide(color: AppColors.primary, width: 1.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Notification status dot/icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isRead
                              ? AppColors.surfaceContainerLow
                              : AppColors.secondaryContainer.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isRead ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                          size: 20,
                          color: isRead ? AppColors.outline : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Info Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    notif['title'] as String,
                                    style: GoogleFonts.inter(
                                      fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                ),
                                Text(
                                  notif['time'] as String,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.outline,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notif['body'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
