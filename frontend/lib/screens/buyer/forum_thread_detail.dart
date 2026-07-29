import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';

class ForumThreadDetailScreen extends StatefulWidget {
  final ForumPost post;

  const ForumThreadDetailScreen({super.key, required this.post});

  @override
  State<ForumThreadDetailScreen> createState() => _ForumThreadDetailScreenState();
}

class _ForumThreadDetailScreenState extends State<ForumThreadDetailScreen> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitComment() {
    if (_commentController.text.trim().isEmpty) return;
    
    final state = Provider.of<AppState>(context, listen: false);
    state.addComment(widget.post.id, _commentController.text.trim());
    _commentController.clear();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comment published!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    // Find live post in case comments were updated
    final livePost = state.forumPosts.firstWhere(
      (fp) => fp.id == widget.post.id,
      orElse: () => widget.post,
    );

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
          'Community Discussion',
          style: GoogleFonts.inter(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Post Card
                  CustomCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Text(
                                livePost.author.substring(0, 1).toUpperCase(),
                                style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    livePost.author,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      livePost.role.toUpperCase(),
                                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              livePost.time,
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          livePost.title,
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          livePost.content,
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant, height: 1.5),
                        ),
                        const Divider(height: 32),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.favorite_rounded, color: AppColors.error),
                              onPressed: () {
                                state.likePost(livePost.id);
                              },
                            ),
                            Text(
                              '${livePost.likes} Likes',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Comments (${livePost.comments.length})',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 12),
                  // Comments List
                  if (livePost.comments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24.0),
                        child: Text(
                          'No comments yet. Start the conversation!',
                          style: GoogleFonts.inter(color: AppColors.outline),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: livePost.comments.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final comment = livePost.comments[index];
                        final parts = comment.split(': ');
                        final author = parts[0];
                        final text = parts.sublist(1).join(': ');

                        return CustomCard(
                          padding: const EdgeInsets.all(12),
                          backgroundColor: AppColors.surfaceContainerLow,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                author,
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                text,
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurface),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          // Reply Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Write a response...',
                        hintStyle: GoogleFonts.inter(fontSize: 14),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                    onPressed: _submitComment,
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
