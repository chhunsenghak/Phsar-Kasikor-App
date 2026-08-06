import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../services/api/chat_api.dart';
import 'chat_thread_screen.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  List<dynamic> _conversations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await ChatApi.fetchConversations(state.token!);
      setState(() {
        _conversations = list;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _dateText(dynamic createdAt) {
    final dt = DateTime.tryParse(createdAt?.toString() ?? '');
    if (dt == null) return '';
    final cambodia = dt.toUtc().add(const Duration(hours: 7));
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    if (cambodia.year == now.year && cambodia.month == now.month && cambodia.day == now.day) {
      int hour = cambodia.hour;
      final minute = cambodia.minute.toString().padLeft(2, '0');
      final ampm = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return '$hour:$minute $ampm';
    }
    return '${cambodia.year}-${cambodia.month.toString().padLeft(2, '0')}-${cambodia.day.toString().padLeft(2, '0')}';
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
        title: Text(
          state.translate('messages'),
          style: GoogleFonts.inter(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
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
                            const Icon(Icons.forum_outlined, size: 48, color: AppColors.outlineVariant),
                            const SizedBox(height: 12),
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
                        itemCount: _conversations.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, indent: 76),
                        itemBuilder: (context, index) {
                          final convo = _conversations[index];
                          final int unread = (convo['unread_count'] as num?)?.toInt() ?? 0;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(color: AppColors.secondaryContainer, shape: BoxShape.circle),
                              child: const Icon(Icons.person_outline_rounded, color: AppColors.onSecondaryContainer),
                            ),
                            title: Text(
                              convo['other_user_name']?.toString() ?? '',
                              style: GoogleFonts.inter(
                                fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600,
                                fontSize: 15,
                                color: AppColors.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              convo['last_message']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: unread > 0 ? AppColors.onSurface : AppColors.onSurfaceVariant,
                                fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _dateText(convo['last_message_at']),
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
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatThreadScreen(
                                    otherUserId: convo['other_user_id'].toString(),
                                    otherUserName: convo['other_user_name']?.toString() ?? '',
                                  ),
                                ),
                              );
                              _load();
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}
