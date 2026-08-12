import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../services/api/chat_api.dart';
import '../../utils/api_error.dart';
import '../../widgets/app_snackbar.dart';
import '../../utils/phnom_penh_time.dart';
import '../../utils/visibility_listener.dart';
import '../../widgets/user_avatar.dart';
import '../buyer/contract_builder_screen.dart';
import 'order_contract_history_screen.dart';

const double _kAvatarSlotWidth = 36; // avatar (28) + gap (8), for grouped-message alignment

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

class _ChatThreadScreenState extends State<ChatThreadScreen> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  Timer? _pollTimer;
  int _loadSequence = 0;
  VisibilityCancel? _cancelVisibilityListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Belt-and-suspenders alongside didChangeAppLifecycleState below —
    // Flutter's own mapping of browser tab visibility to AppLifecycleState
    // has a history of rough edges across versions, so this listens to the
    // DOM event directly too (a no-op on mobile/desktop).
    _cancelVisibilityListener = onPageVisible(() => _loadMessages(silent: true));
    _loadMessages();
    // Re-checks in the background so a reply shows up without the buyer/
    // seller needing to leave and re-enter the thread. Also doubles as the
    // "seen" signal — opening/polling this thread is what marks the other
    // side's messages as read (see chat_service.get_conversation).
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadMessages(silent: true));
    // Fresh even on a cold start, so the contract action below is accurate
    // the first time this screen is ever opened this session.
    Provider.of<AppState>(context, listen: false).refreshContracts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelVisibilityListener?.call();
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Browsers throttle (or fully pause) a background tab's Timer, and
    // mobile OSes pause timers while backgrounded — the 4s poll above can
    // silently stop firing while this screen isn't actually visible, then
    // only "catch up" once something else forces a refresh (e.g. sending a
    // message). This is exactly what made the thread feel like it needed a
    // manual nudge to show a reply that had been sitting there the whole
    // time. Refreshing the instant this tab/app becomes visible again closes
    // that gap instead of waiting on the next timer tick.
    if (state == AppLifecycleState.resumed) {
      _loadMessages(silent: true);
    }
  }

  Future<void> _loadMessages({bool silent = false}) async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.token == null) return;
    // A silent poll and a send-triggered reload can overlap; if an older
    // request's response lands after a newer one's, it must not be allowed
    // to clobber the newer data back to a stale state.
    final int requestId = ++_loadSequence;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final list = await ChatApi.fetchChatHistory(state.token!, widget.otherUserId);
      if (!mounted || requestId != _loadSequence) return;
      final bool hasNewMessages = list.length > _messages.length;
      setState(() => _messages = list);
      // Don't yank a silently-polling user back to the bottom while they're
      // scrolled up reading history — only follow along on new arrivals, or
      // always on the initial/manual load.
      if (!silent || hasNewMessages) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      if (!mounted || silent || requestId != _loadSequence) return;
      setState(() => _error = state.translate('failed_to_load_messages'));
    } finally {
      if (mounted && !silent) setState(() => _isLoading = false);
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

  /// A contract can be proposed from inside the conversation once the buyer
  /// is actually interested — chat comes first now, not the other way
  /// around. Buyer-only, matching the app's existing buyer/seller action
  /// gating convention; the seller responds via the Contract Agreements tab
  /// once a proposal exists. A buyer/seller pair can have any number of
  /// contracts open at once (separate crops, separate delivery windows,
  /// etc.), so "Propose Contract" is always offered here — "View Contracts"
  /// only joins it in the menu as a shortcut when at least one already
  /// exists, it never replaces the ability to start another. Collapsed into
  /// a single 3-dot menu (rather than two side-by-side buttons) so the
  /// count growing to double digits never squeezes the AppBar.
  Widget _buildContractAction(AppState state) {
    if (state.currentRole != 'buyer') return const SizedBox.shrink();

    final myId = state.userProfile?['id']?.toString();
    final openCount = state.negotiations.where((n) =>
        n.isOpen &&
        ((n.buyerId == myId && n.sellerId == widget.otherUserId) ||
            (n.sellerId == myId && n.buyerId == widget.otherUserId))).length;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.onSurface),
      onSelected: (value) {
        if (value == 'view_contracts') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderContractHistoryScreen(
                initialTab: 0,
                isPushed: true,
                counterpartyId: widget.otherUserId,
                counterpartyName: widget.otherUserName,
              ),
            ),
          );
        } else if (value == 'propose_contract') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContractBuilderScreen(
                sellerId: widget.otherUserId,
                sellerName: widget.otherUserName,
              ),
            ),
          );
        }
      },
      itemBuilder: (context) => [
        if (openCount > 0)
          PopupMenuItem(
            value: 'view_contracts',
            child: Row(
              children: [
                const Icon(Icons.description_outlined, size: 18, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 10),
                Text(state.translate('view_contracts_count', arguments: {'count': openCount.toString()})),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'propose_contract',
          child: Row(
            children: [
              const Icon(Icons.handshake_outlined, size: 18, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 10),
              Text(state.translate('propose_contract')),
            ],
          ),
        ),
      ],
    );
  }

  /// Bubbles from the same sender within 5 minutes of each other are
  /// visually chained (tight spacing, avatar only on the last of the run)
  /// instead of repeating a full-weight bubble+avatar for every single
  /// message — the same convention WhatsApp/Telegram/Messenger all use, and
  /// a day boundary always breaks the chain (paired with the date
  /// separator).
  List<Widget> _buildMessageWidgets(AppState state, String myId) {
    final parsed = _messages
        .map((m) => (
              raw: m as Map<String, dynamic>,
              senderId: m['sender_id']?.toString() ?? '',
              at: backendUtcToPhnomPenh(m['created_at']?.toString()),
            ))
        .toList();

    final List<Widget> widgets = [];
    for (int i = 0; i < parsed.length; i++) {
      final cur = parsed[i];
      final prev = i > 0 ? parsed[i - 1] : null;
      final next = i < parsed.length - 1 ? parsed[i + 1] : null;

      final bool sameDayAsPrev = prev != null &&
          cur.at != null &&
          prev.at != null &&
          cur.at!.year == prev.at!.year &&
          cur.at!.month == prev.at!.month &&
          cur.at!.day == prev.at!.day;
      if (!sameDayAsPrev) {
        widgets.add(_buildDateSeparator(state, cur.at ?? DateTime.now()));
      }

      final bool groupedWithPrev = sameDayAsPrev &&
          prev.senderId == cur.senderId &&
          cur.at != null &&
          prev.at != null &&
          cur.at!.difference(prev.at!).inMinutes.abs() < 5;
      final bool groupedWithNext = next != null &&
          next.senderId == cur.senderId &&
          cur.at != null &&
          next.at != null &&
          cur.at!.year == next.at!.year &&
          cur.at!.month == next.at!.month &&
          cur.at!.day == next.at!.day &&
          next.at!.difference(cur.at!).inMinutes.abs() < 5;

      widgets.add(_buildBubble(
        cur.raw,
        isMine: cur.senderId == myId,
        showAvatar: !groupedWithNext,
        isFirstInGroup: !groupedWithPrev,
        isLastInGroup: !groupedWithNext,
        marginBottom: groupedWithNext ? 2 : 12,
      ));
    }
    return widgets;
  }

  Widget _buildDateSeparator(AppState state, DateTime phnomPenhDay) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final yesterday = now.subtract(const Duration(days: 1));
    String label;
    if (phnomPenhDay.year == now.year && phnomPenhDay.month == now.month && phnomPenhDay.day == now.day) {
      label = state.translate('today_label');
    } else if (phnomPenhDay.year == yesterday.year &&
        phnomPenhDay.month == yesterday.month &&
        phnomPenhDay.day == yesterday.day) {
      label = state.translate('yesterday_label');
    } else {
      label = formatDateOnly(phnomPenhDay);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(
    Map<String, dynamic> msg, {
    required bool isMine,
    required bool showAvatar,
    required bool isFirstInGroup,
    required bool isLastInGroup,
    required double marginBottom,
  }) {
    final bool isRead = msg['is_read'] == true;
    // The "tail" (small radius) sits on the last bubble of a group, nearest
    // the avatar/timestamp; a bubble continuing a group gets a flatter
    // corner on that same side instead of repeating a full tail each time.
    final BorderRadius radius = BorderRadius.only(
      topLeft: Radius.circular(!isMine && !isFirstInGroup ? 6 : 16),
      topRight: Radius.circular(isMine && !isFirstInGroup ? 6 : 16),
      bottomLeft: Radius.circular(isMine ? 16 : (isLastInGroup ? 4 : 16)),
      bottomRight: Radius.circular(isMine ? (isLastInGroup ? 4 : 16) : 16),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: marginBottom),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            SizedBox(
              width: _kAvatarSlotWidth,
              child: showAvatar
                  ? UserAvatar(name: widget.otherUserName, seed: widget.otherUserId, radius: 14)
                  : null,
            ),
          ],
          Flexible(
            child: Builder(builder: (context) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                decoration: BoxDecoration(
                  color: isMine ? AppColors.primary : AppColors.surfaceContainerLow,
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatPhnomPenhTime(msg['created_at']?.toString()),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: isMine ? Colors.white.withValues(alpha: 0.75) : AppColors.outline,
                          ),
                        ),
                        if (isMine) ...[
                          const SizedBox(width: 4),
                          Icon(
                            isRead ? Icons.done_all_rounded : Icons.done_rounded,
                            size: 14,
                            color: isRead ? Colors.lightBlueAccent : Colors.white.withValues(alpha: 0.75),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
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
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(name: widget.otherUserName, seed: widget.otherUserId, radius: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.otherUserName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        actions: [_buildContractAction(state)],
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLow,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.chat_bubble_outline_rounded, size: 32, color: AppColors.outlineVariant),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  state.translate('no_messages_in_thread'),
                                  style: GoogleFonts.inter(color: AppColors.outline),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            children: _buildMessageWidgets(state, myId),
                          ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: IconButton(
                      onPressed: _isSending ? null : _send,
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
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
