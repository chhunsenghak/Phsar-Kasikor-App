import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/app_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_input.dart';
import '../../widgets/app_snackbar.dart';
import 'forum_thread_detail.dart';

class CommunityPortalScreen extends StatefulWidget {
  const CommunityPortalScreen({super.key});

  @override
  State<CommunityPortalScreen> createState() => _CommunityPortalScreenState();
}

class _CommunityPortalScreenState extends State<CommunityPortalScreen> {
  final _commentControllers = <String, TextEditingController>{};

  @override
  void dispose() {
    for (var controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showNewPostSheet(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppDesign.borderRadiusDefault)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      state.translate('create_community_post'),
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                CustomInput(
                  label: state.translate('post_title_label'),
                  hintText: state.translate('post_title_hint'),
                  controller: titleController,
                ),
                const SizedBox(height: 16),
                Text(
                  state.translate('post_content_label'),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: contentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: state.translate('post_content_hint'),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDesign.borderRadiusDefault),
                      borderSide: const BorderSide(color: AppColors.outlineVariant),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: state.translate('publish_post'),
                  icon: Icons.send_rounded,
                  onPressed: () {
                    if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                      state.createPost(
                        titleController.text,
                        contentController.text,
                      );
                      Navigator.pop(context);
                      AppSnackBar.success(context, state.translate('post_published_success'));
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final posts = state.forumPosts;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: posts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final post = posts[index];
                  _commentControllers.putIfAbsent(post.id, () => TextEditingController());
                  return _buildPostCard(context, state, post);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.translate('community_portal_title'),
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  state.translate('community_portal_subtitle'),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: AppColors.primary),
              icon: const Icon(Icons.add_comment_rounded, color: Colors.white),
              onPressed: () => _showNewPostSheet(context),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildPostCard(BuildContext context, AppState state, ForumPost post) {
    return CustomCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ForumThreadDetailScreen(post: post),
          ),
        );
      },
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPostAuthorMetadata(post),
          const SizedBox(height: 16),
          _buildPostContent(post),
          const SizedBox(height: 16),
          _buildPostActionBar(state, post),
          if (post.comments.isNotEmpty) ...[
            _buildPostComments(post),
          ],
          _buildCommentInput(state, post),
        ],
      ),
    );
  }

  Widget _buildPostAuthorMetadata(ForumPost post) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Text(
            post.author[0],
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    post.author,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getRoleBadgeColor(post.role),
                      borderRadius: BorderRadius.circular(AppDesign.borderRadiusSm),
                    ),
                    child: Text(
                      post.role,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getRoleTextColor(post.role),
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 2),
              Text(
                post.time,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.outline,
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostContent(ForumPost post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          post.title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          post.content,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: AppColors.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPostActionBar(AppState state, ForumPost post) {
    return Column(
      children: [
        const Divider(color: AppColors.outlineVariant),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => state.likePost(post.id),
              icon: const Icon(Icons.thumb_up_alt_outlined, size: 18, color: AppColors.primary),
              label: Text(
                state.translate('likes_count', arguments: {'count': post.likes.toString()}),
                style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.comment_outlined, size: 18, color: AppColors.outline),
            const SizedBox(width: 6),
            Text(
              state.translate('comments_count', arguments: {'count': post.comments.length.toString()}),
              style: GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPostComments(ForumPost post) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppDesign.borderRadiusSm),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: post.comments.length,
            separatorBuilder: (context, idx) => const Divider(height: 16),
            itemBuilder: (context, idx) {
              final parts = post.comments[idx].split(': ');
              final cAuthor = parts[0];
              final cBody = parts.sublist(1).join(': ');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cAuthor,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cBody,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCommentInput(AppState state, ForumPost post) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentControllers[post.id],
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: state.translate('add_comment_hint'),
                  hintStyle: GoogleFonts.inter(color: AppColors.outline),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLowest,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDesign.borderRadiusSm),
                    borderSide: const BorderSide(color: AppColors.outlineVariant),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: AppColors.primary),
              onPressed: () {
                final text = _commentControllers[post.id]?.text;
                if (text != null && text.isNotEmpty) {
                  state.addComment(post.id, text);
                  _commentControllers[post.id]?.clear();
                }
              },
            )
          ],
        ),
      ],
    );
  }

  Color _getRoleBadgeColor(String role) {
    if (role == 'Expert') return AppColors.primaryContainer.withValues(alpha: 0.15);
    if (role == 'Farmer') return AppColors.secondaryContainer;
    return AppColors.surfaceContainerHigh;
  }

  Color _getRoleTextColor(String role) {
    if (role == 'Expert') return AppColors.primary;
    if (role == 'Farmer') return AppColors.onSecondaryContainer;
    return AppColors.onSurfaceVariant;
  }
}
