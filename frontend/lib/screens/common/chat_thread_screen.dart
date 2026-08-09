import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../services/api/chat_api.dart';
import '../../utils/api_error.dart';
import '../../widgets/app_snackbar.dart';

class ChatThreadScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;

  const ChatThreadScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await ChatApi.fetchChatHistory(state.token!, widget.otherUserId);
      setState(() {
        _messages = list;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      setState(() {
        _error = state.translate('failed_to_load_messages');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  Future<void> _send() async {
    final state = Provider.of<AppState>(context, listen: false);
    final text = _controller.text.trim();
    if (text.isEmpty || state.token == null || _isSending) return;

    setState(() => _isSending = true);
    try {
      await ChatApi.sendChatMessage(state.token!, widget.otherUserId, text);
      _controller.clear();
      await _loadMessages();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, friendlyApiError(state, e));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _timeText(dynamic createdAt) {
    final dt = DateTime.tryParse(createdAt?.toString() ?? '');
    if (dt == null) return '';
    final cambodia = dt.toUtc().add(const Duration(hours: 7));
    int hour = cambodia.hour;
    final minute = cambodia.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return '$hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final String myId = state.userProfile?['id']?.toString() ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
        title: Text(
          widget.otherUserName,
          style: GoogleFonts.inter(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? Center(child: Text(_error!, style: GoogleFonts.inter(color: AppColors.error)))
                    : _messages.isEmpty
                        ? Center(
                            child: Text(
                              state.translate('no_messages_in_thread'),
                              style: GoogleFonts.inter(color: AppColors.outline),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final bool isMine = msg['sender_id']?.toString() == myId;
                              return Align(
                                alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                  decoration: BoxDecoration(
                                    color: isMine ? AppColors.primary : AppColors.surfaceContainerLow,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(14),
                                      topRight: const Radius.circular(14),
                                      bottomLeft: Radius.circular(isMine ? 14 : 2),
                                      bottomRight: Radius.circular(isMine ? 2 : 14),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        msg['message_text']?.toString() ?? '',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: isMine ? Colors.white : AppColors.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _timeText(msg['created_at']),
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: isMine ? Colors.white.withValues(alpha: 0.75) : AppColors.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.4))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: state.translate('type_a_message'),
                        hintStyle: GoogleFonts.inter(color: AppColors.outline, fontSize: 14),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSending ? null : _send,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : const Icon(Icons.send_rounded, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
