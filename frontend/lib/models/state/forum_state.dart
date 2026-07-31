import 'base_app_state.dart';

mixin ForumStateMixin on BaseAppState {
  final List<ForumPost> _forumPosts = [];
  List<ForumPost> get forumPosts => _forumPosts;

  void likePost(String id) {
    final idx = _forumPosts.indexWhere((fp) => fp.id == id);
    if (idx != -1) {
      _forumPosts[idx].likes++;
      notifyListeners();
    }
  }

  void addComment(String postId, String commentText) {
    final idx = _forumPosts.indexWhere((fp) => fp.id == postId);
    if (idx != -1) {
      _forumPosts[idx].comments.add('$userName: $commentText');
      notifyListeners();
    }
  }

  void createPost(String title, String content) {
    _forumPosts.insert(
      0,
      ForumPost(
        id: 'fp_${DateTime.now().millisecondsSinceEpoch}',
        author: userName,
        role: currentRole == 'farmer' ? 'Farmer' : (currentRole == 'admin' ? 'Expert' : 'Buyer'),
        title: title,
        content: content,
        time: 'Just now',
        comments: [],
      ),
    );
    notifyListeners();
  }

  Future<void> refreshForumPosts() async {
    // Stub for future community post pagination API
  }
}
