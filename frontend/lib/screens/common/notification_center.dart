import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  IconData _getIconData(String title, String rawTitle) {
    final t = title.toLowerCase();
    final r = rawTitle.toLowerCase();
    
    if (r.contains('bid') || r.contains('offer') || r.contains('negotiate') || r.contains('contract') ||
        t.contains('bid') || t.contains('offer') || t.contains('ដេញថ្លៃ') || t.contains('កិច្ចសន្យា')) {
      return Icons.handshake_rounded;
    }
    if (r.contains('approve') || r.contains('verify') || r.contains('success') ||
        t.contains('approve') || t.contains('success') || t.contains('អនុម័ត') || t.contains('ជោគជ័យ')) {
      return Icons.verified_rounded;
    }
    if (r.contains('welcome') || r.contains('login') ||
        t.contains('welcome') || t.contains('login') || t.contains('ស្វាគមន៍')) {
      return Icons.waving_hand_rounded;
    }
    if (r.contains('address') || r.contains('location') || r.contains('addr') ||
        t.contains('address') || t.contains('location') || t.contains('អាសយដ្ឋាន') || t.contains('ទីតាំង')) {
      return Icons.location_on_rounded;
    }
    return Icons.notifications_rounded;
  }

  Color _getIconColor(String title, String rawTitle) {
    final t = title.toLowerCase();
    final r = rawTitle.toLowerCase();
    
    if (r.contains('bid') || r.contains('offer') || r.contains('negotiate') || r.contains('contract') ||
        t.contains('bid') || t.contains('offer') || t.contains('ដេញថ្លៃ') || t.contains('កិច្ចសន្យា')) {
      return AppColors.primary;
    }
    if (r.contains('approve') || r.contains('verify') || r.contains('success') ||
        t.contains('approve') || t.contains('success') || t.contains('អនុម័ត') || t.contains('ជោគជ័យ')) {
      return Colors.teal;
    }
    if (r.contains('welcome') || r.contains('login') ||
        t.contains('welcome') || t.contains('login') || t.contains('ស្វាគមន៍')) {
      return Colors.orange;
    }
    if (r.contains('address') || r.contains('location') || r.contains('addr') ||
        t.contains('address') || t.contains('location') || t.contains('អាសយដ្ឋាន') || t.contains('ទីតាំង')) {
      return Colors.redAccent;
    }
    return AppColors.primary;
  }

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
          state.translate('notification_center'),
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
            },
            child: Text(
              state.translate('mark_all_read'),
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
                    state.translate('all_caught_up'),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.translate('no_new_alerts'),
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
                final String rawTitle = notif['title'] as String? ?? '';
                final String rawBody = notif['body'] as String? ?? '';
                final String title = state.hasTranslation(rawTitle) ? state.translate(rawTitle) : rawTitle;
                final String body = state.hasTranslation(rawBody) ? state.translate(rawBody) : rawBody;
                final iconData = _getIconData(title, rawTitle);
                final iconColor = _getIconColor(title, rawTitle);

                final String notifId = notif['id']?.toString() ?? index.toString();

                return Dismissible(
                  key: Key(notifId),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    state.deleteNotification(notifId);
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                        const SizedBox(width: 6),
                        Text(
                          state.translate('delete'),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  child: CustomCard(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: isRead
                        ? AppColors.surface
                        : iconColor.withValues(alpha: 0.05),
                    borderSide: BorderSide(
                      color: isRead
                          ? AppColors.outlineVariant.withValues(alpha: 0.3)
                          : iconColor.withValues(alpha: 0.4),
                      width: 1.0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Notification status dot/icon
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isRead
                                ? AppColors.surfaceContainerLow.withValues(alpha: 0.6)
                                : iconColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            iconData,
                            size: 20,
                            color: isRead ? iconColor.withValues(alpha: 0.5) : iconColor,
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
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: GoogleFonts.inter(
                                              fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                              fontSize: 15,
                                              color: isRead ? AppColors.onSurface.withValues(alpha: 0.7) : AppColors.onSurface,
                                            ),
                                          ),
                                        ),
                                        if (!isRead)
                                          Container(
                                            margin: const EdgeInsets.only(left: 8),
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: iconColor,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: iconColor.withValues(alpha: 0.5),
                                                  blurRadius: 4,
                                                  spreadRadius: 1,
                                                )
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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
                                body,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: isRead ? AppColors.onSurfaceVariant.withValues(alpha: 0.7) : AppColors.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
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
