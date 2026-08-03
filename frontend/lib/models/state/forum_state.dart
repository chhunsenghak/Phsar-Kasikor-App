import 'base_app_state.dart';
import '../../services/api/forum_api.dart';

mixin ForumStateMixin on BaseAppState {
  final List<ForumPost> _forumPosts = [];
  List<ForumPost> get forumPosts => _forumPosts;

  Future<void> refreshForumPosts() async {
    if (token == null) return;
    try {
      final postsData = await ForumApi.fetchPosts(token!);
      _forumPosts.clear();
      for (var p in postsData) {
        _forumPosts.add(
          ForumPost(
            id: p['id'] ?? '',
            author: p['author_name'] ?? 'Farmer',
            role: 'Member',
            title: p['title'] ?? '',
            content: p['content'] ?? '',
            time: 'Recently',
            likes: p['likes_count'] ?? 0,
            comments: List.filled(p['comments_count'] ?? 0, 'Comment'),
          ),
        );
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> likePost(String id) async {
    final idx = _forumPosts.indexWhere((fp) => fp.id == id);
    if (idx != -1) {
      _forumPosts[idx].likes++;
      notifyListeners();
      if (token != null) {
        try {
          await ForumApi.likePost(token!, id);
        } catch (_) {}
      }
    }
  }

  Future<void> addComment(String postId, String commentText) async {
    final idx = _forumPosts.indexWhere((fp) => fp.id == postId);
    if (idx != -1) {
      _forumPosts[idx].comments.add('$userName: $commentText');
      notifyListeners();
      if (token != null) {
        try {
          await ForumApi.addComment(token!, postId, commentText);
        } catch (_) {}
      }
    }
  }

  Future<void> createPost(String title, String content) async {
    final newPost = ForumPost(
      id: 'fp_${DateTime.now().millisecondsSinceEpoch}',
      author: userName,
      role: currentRole == 'farmer' ? 'Farmer' : (currentRole == 'admin' ? 'Expert' : 'Buyer'),
      title: title,
      content: content,
      time: 'Just now',
      comments: [],
    );
    _forumPosts.insert(0, newPost);
    notifyListeners();

    if (token != null) {
      try {
        final res = await ForumApi.createPost(token!, title: title, content: content);
        if (res['id'] != null) {
          newPost.id = res['id'].toString();
          notifyListeners();
        }
      } catch (_) {}
    }
  }
}
