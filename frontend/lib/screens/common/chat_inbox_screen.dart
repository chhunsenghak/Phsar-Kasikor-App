import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../services/api/chat_api.dart';
import '../../utils/api_error.dart';
import '../../utils/phnom_penh_time.dart';
import '../../utils/visibility_listener.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/user_avatar.dart';
import 'chat_thread_screen.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> with WidgetsBindingObserver {
  List<dynamic> _conversations = [];
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;
  int _loadSequence = 0;
  VisibilityCancel? _cancelVisibilityListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cancelVisibilityListener = onPageVisible(() => _load(silent: true));
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelVisibilityListener?.call();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Same reasoning as chat_thread_screen.dart — a background tab/app can
    // throttle or pause this timer, so catch up immediately on resume
    // instead of waiting for the next tick.
    if (state == AppLifecycleState.resumed) {
      _load(silent: true);
    }
  }

  Future<void> _load({bool silent = false}) async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) return;
    final int requestId = ++_loadSequence;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final list = await ChatApi.fetchConversations(state.token!);
      if (!mounted || requestId != _loadSequence) return;
      setState(() => _conversations = list);
    } catch (e) {
      if (!mounted || silent || requestId != _loadSequence) return;
      setState(() => _error = friendlyApiError(state, e));
    } finally {
      if (mounted && !silent) setState(() => _isLoading = false);
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
        iconTheme: const IconThemeData(color: AppColors.onSurface),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.forum_rounded, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              state.translate('messages'),
              style: GoogleFonts.inter(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text(_error!, style: GoogleFonts.inter(color: AppColors.outline)),
                    ],
                  ),
                )
              : _conversations.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.forum_outlined, size: 40, color: AppColors.outlineVariant),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              state.translate('no_conversations_yet'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(color: AppColors.outline),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _conversations.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final convo = _conversations[index];
                          final int unread = (convo['unread_count'] as num?)?.toInt() ?? 0;
                          final String otherUserId = convo['other_user_id']?.toString() ?? '';
                          final String otherUserName = convo['other_user_name']?.toString() ?? '';
                          return CustomCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevationLevel: 2,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatThreadScreen(
                                    otherUserId: otherUserId,
                                    otherUserName: otherUserName,
                                  ),
                                ),
                              );
                              _load();
                            },
                            child: Row(
                              children: [
                                UserAvatar(name: otherUserName, seed: otherUserId, radius: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        otherUserName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600,
                                          fontSize: 15,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        convo['last_message']?.toString() ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: unread > 0 ? AppColors.onSurface : AppColors.onSurfaceVariant,
                                          fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      formatPhnomPenhSmartDate(convo['last_message_at']?.toString()),
                                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.outline),
                                    ),
                                    if (unread > 0) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          unread.toString(),
                                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
