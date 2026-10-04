import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notifications_screen.dart';
import '../services/community_service.dart';
import '../services/notification_service.dart';
import '../services/theme_service.dart';

// ============================================================
// REPOST DATA MODEL
// ============================================================
class _RepostData {
  final String originalPostId;
  final String reposterName;
  final String reposterImage;
  final String originalAuthor;
  final String? originalAvatar;
  final String originalTime;
  final String originalContent;
  final String? originalImage;
  final String category;
  final DateTime repostedAt;

  _RepostData({
    required this.originalPostId,
    required this.reposterName,
    required this.reposterImage,
    required this.originalAuthor,
    this.originalAvatar,
    required this.originalTime,
    required this.originalContent,
    this.originalImage,
    required this.category,
    required this.repostedAt,
  });
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final CommunityService _communityService = CommunityService();
  final SupabaseClient _supabase = Supabase.instance.client;

  static const Color primaryColor = Color(0xFFA94327);
  static const Color backgroundColor = Color(0xFFF6F8F9);
  static const Color darkText = Color(0xFF263238);

  String selectedCategory = 'All';
  final List<String> categories = const [
    'All',
    'Success Stories',
    'Announcements',
    'Tips',
  ];

  bool _loadingPosts = true;
  List<Map<String, dynamic>> _posts = [];
  final Map<String, bool> _likedPostIds = {};
  final Map<String, int> _likeCounts = {};
  final Map<String, int> _commentCounts = {};

  // Repost feature states
  final Set<String> _repostedPostIds = {};
  final List<_RepostData> _repostedPosts = [];

  String _currentUserName = 'User';
  String _currentUserImage = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadPosts();
  }

  // ============================================================
  // LOAD USER
  // ============================================================
  Future<void> _loadCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      String name = user.userMetadata?['full_name']?.toString().trim() ?? '';
      String avatar = user.userMetadata?['avatar_url']?.toString().trim() ?? '';

      if (name.isEmpty) {
        name = user.email?.split('@').first ?? 'User';
      }

      try {
        final profile = await _supabase
            .from('profiles')
            .select('full_name, avatar_url')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null) {
          final dbName = profile['full_name']?.toString().trim() ?? '';
          final dbAvatar = profile['avatar_url']?.toString().trim() ?? '';
          if (dbName.isNotEmpty) name = dbName;
          if (dbAvatar.isNotEmpty) avatar = dbAvatar;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _currentUserName = name;
          _currentUserImage = avatar;
        });
      }
    } catch (_) {}
  }

  // ============================================================
  // LOAD POSTS FROM SUPABASE
  // ============================================================
  Future<void> _loadPosts() async {
    setState(() => _loadingPosts = true);
    try {
      final fetched = await _communityService.fetchPosts();

      if (mounted) {
        setState(() {
          _posts = fetched;
          for (final post in fetched) {
            final id = post['id']?.toString() ?? '';
            _likedPostIds[id] = post['is_liked_by_me'] == true;
            _likeCounts[id] = (post['like_count'] as num?)?.toInt() ?? 0;
            _commentCounts[id] = (post['comment_count'] as num?)?.toInt() ?? 0;
          }
          _loadingPosts = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading community posts: $e');
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  // ============================================================
  // LIKE TOGGLE (REAL DATABASE PERSISTENCE)
  // ============================================================
  Future<void> _toggleLike(String postId) async {
    final bool currentLiked = _likedPostIds[postId] ?? false;
    final int currentCount = _likeCounts[postId] ?? 0;

    // Optimistic UI update
    setState(() {
      _likedPostIds[postId] = !currentLiked;
      _likeCounts[postId] = currentLiked
          ? (currentCount > 0 ? currentCount - 1 : 0)
          : currentCount + 1;
    });

    try {
      final bool newLiked = await _communityService.toggleLike(
        postId,
        currentLiked,
        currentCount,
      );
      if (mounted) {
        setState(() {
          _likedPostIds[postId] = newLiked;
        });
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _likedPostIds[postId] = currentLiked;
          _likeCounts[postId] = currentCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please log in to like posts: $e')),
        );
      }
    }
  }

  // ============================================================
  // SHARE POST (NATIVE SHARE)
  // ============================================================
  void _sharePost({required String author, required String content}) {
    SharePlus.instance.share(
      ShareParams(
        text:
            '$author shared on My Future Pet:\n\n$content\n\n'
            'Download My Future Pet to adopt and support rescue pets!',
        subject: 'My Future Pet Story',
      ),
    );
  }

  // ============================================================
  // COMMENTS BOTTOM SHEET (REAL DATA)
  // ============================================================
  void _showCommentsModal(String postId, String authorName) {
    final bool isDark = ThemeService.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CommentsSheet(
        postId: postId,
        postAuthor: authorName,
        isDark: isDark,
        communityService: _communityService,
        onCommentAdded: () {
          setState(() {
            _commentCounts[postId] = (_commentCounts[postId] ?? 0) + 1;
          });
        },
      ),
    );
  }

  // ============================================================
  // REPOST LOGIC
  // ============================================================
  Future<void> _confirmRemoveRepost(String postId) async {
    final bool? remove = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Repost?'),
        content: const Text('This post will be removed from your reposted feed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (remove == true && mounted) {
      setState(() {
        _repostedPostIds.remove(postId);
        _repostedPosts.removeWhere((r) => r.originalPostId == postId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Repost removed from your community feed.')),
      );
    }
  }

  Future<void> _handleRepost(Map<String, dynamic> post) async {
    final String postId = post['id']?.toString() ?? '';
    if (postId.isEmpty) return;

    if (_repostedPostIds.contains(postId)) {
      await _confirmRemoveRepost(postId);
      return;
    }

    final authorMap = post['author'] as Map<String, dynamic>?;
    final shelterMap = post['shelter'] as Map<String, dynamic>?;
    String authorName = 'My Future Pet';
    String? authorAvatar;
    if (shelterMap != null && shelterMap['name'] != null) {
      authorName = shelterMap['name'].toString().toUpperCase();
      authorAvatar = shelterMap['logo_url']?.toString();
    } else if (authorMap != null && authorMap['full_name'] != null) {
      authorName = authorMap['full_name'].toString();
      authorAvatar = authorMap['avatar_url']?.toString();
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Repost Story?'),
        content: Text('Repost this story by "$authorName" to the top of your community feed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Repost'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final newRepost = _RepostData(
        originalPostId: postId,
        reposterName: _currentUserName,
        reposterImage: _currentUserImage,
        originalAuthor: authorName,
        originalAvatar: authorAvatar,
        originalTime: _formatTimeAgo(post['created_at']),
        originalContent: post['content']?.toString() ?? '',
        originalImage: post['image_url']?.toString(),
        category: post['category']?.toString() ?? 'Success Stories',
        repostedAt: DateTime.now(),
      );

      setState(() {
        _repostedPostIds.add(postId);
        _repostedPosts.insert(0, newRepost);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post reposted to the top of your feed!')),
      );
    }
  }
  // CREATE POST MODAL (USER POSTING)
  // ============================================================
  void _openCreatePostModal() {
    final bool isDark = ThemeService.isDarkMode(context);
    final TextEditingController contentController = TextEditingController();
    final TextEditingController imageController = TextEditingController();
    String postCategory = 'Success Stories';
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Create Community Post',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          color: isDark ? const Color(0xFF94A3B8) : Colors.grey,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Success Stories', 'Announcements', 'Tips'].map((cat) {
                        final selected = postCategory == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: selected,
                          selectedColor: primaryColor,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : (isDark ? const Color(0xFFE2E8F0) : darkText),
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          onSelected: (val) {
                            if (val) setModalState(() => postCategory = cat);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: contentController,
                      maxLines: 4,
                      style: TextStyle(color: isDark ? const Color(0xFFF8FAFC) : darkText),
                      decoration: InputDecoration(
                        hintText: "Share your pet story, update, or tip...",
                        hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: primaryColor, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: imageController,
                      style: TextStyle(color: isDark ? const Color(0xFFF8FAFC) : darkText),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.link_rounded, color: primaryColor),
                        hintText: "Optional image URL (https://...)",
                        hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: primaryColor, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: submitting
                            ? null
                            : () async {
                                final text = contentController.text.trim();
                                final messenger = ScaffoldMessenger.of(context);
                                if (text.isEmpty) {
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('Please enter your post content.')),
                                  );
                                  return;
                                }

                                setModalState(() => submitting = true);
                                try {
                                  await _communityService.createPost(
                                    content: text,
                                    category: postCategory,
                                    imageUrl: imageController.text.trim().isNotEmpty
                                        ? imageController.text.trim()
                                        : null,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _loadPosts();
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('Post published to Community Feed!')),
                                  );
                                } catch (err) {
                                  setModalState(() => submitting = false);
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Error publishing post: $err')),
                                  );
                                }
                              },
                        child: submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Publish Post',
                                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // FORMAT NUMBER
  // ============================================================
  String _formatCount(int count) {
    if (count >= 1000) {
      final double k = count / 1000.0;
      return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}k';
    }
    return count.toString();
  }

  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    try {
      final dt = DateTime.parse(timestamp.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays >= 7) {
        return '${dt.month}/${dt.day}/${dt.year}';
      } else if (diff.inDays >= 1) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours >= 1) {
        return '${diff.inHours}h ago';
      } else if (diff.inMinutes >= 1) {
        return '${diff.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (_) {
      return 'Recently';
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.isDarkMode(context);
    final bgCol = isDark ? const Color(0xFF0F172A) : backgroundColor;

    return Scaffold(
      backgroundColor: bgCol,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildCategoryBar(),
            Expanded(
              child: Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: _loadPosts,
                    color: primaryColor,
                    child: _buildFeed(),
                  ),
                  Positioned(
                    right: 18,
                    bottom: 20,
                    child: _buildCreatePostButton(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildHeader() {
    final isDark = ThemeService.isDarkMode(context);

    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF1E293B) : backgroundColor,
      padding: const EdgeInsets.fromLTRB(18, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFD9E4E7),
                width: 1,
              ),
            ),
            child: ClipOval(
              child: _currentUserImage.isNotEmpty
                  ? Image.network(
                      _currentUserImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.pets_rounded, color: primaryColor, size: 24),
                    )
                  : Center(
                      child: Text(
                        _currentUserName.isNotEmpty ? _currentUserName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 18),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Community',
            style: TextStyle(
              color: isDark ? const Color(0xFFF8FAFC) : primaryColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 27,
                  color: isDark ? const Color(0xFFCBD5E1) : primaryColor,
                ),
                ValueListenableBuilder<int>(
                  valueListenable: NotificationService().unreadCountNotifier,
                  builder: (context, count, _) {
                    if (count <= 0) return const SizedBox.shrink();
                    return Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD32F2F),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CATEGORY BAR
  // ============================================================
  Widget _buildCategoryBar() {
    final isDark = ThemeService.isDarkMode(context);

    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF1E293B) : backgroundColor,
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: categories.map((cat) {
            final isSelected = selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() => selectedCategory = cat);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor
                        : (isDark ? const Color(0xFF0F172A) : Colors.white),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSelected
                          ? primaryColor
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? const Color(0xFF94A3B8) : darkText),
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ============================================================
  // POSTS LIST
  // ============================================================
  Widget _buildFeed() {
    if (_loadingPosts) {
      return const Center(child: CircularProgressIndicator(color: primaryColor));
    }

    final filtered = selectedCategory == 'All'
        ? _posts
        : _posts.where((p) => p['category'] == selectedCategory).toList();

    final filteredReposts = _repostedPosts.where((repost) {
      if (selectedCategory == 'All') return true;
      return repost.category == selectedCategory;
    }).toList();

    if (filtered.isEmpty && filteredReposts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              children: [
                Icon(Icons.feed_outlined, size: 54, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No community posts yet in "$selectedCategory"',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final int totalCount = filteredReposts.length + filtered.length;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index < filteredReposts.length) {
          return _buildRepostCard(filteredReposts[index]);
        }
        final post = filtered[index - filteredReposts.length];
        return _buildPostCard(post);
      },
    );
  }

  // ============================================================
  // POST CARD (MATCHES FIGMA / USER SCREENSHOT + REPOST)
  // ============================================================
  Widget _buildPostCard(Map<String, dynamic> post) {
    final bool isDark = ThemeService.isDarkMode(context);
    final String postId = post['id']?.toString() ?? '';
    final String content = post['content']?.toString() ?? '';
    final String? imageUrl = post['image_url']?.toString();
    final String timeAgo = _formatTimeAgo(post['created_at']);

    // Author info
    final authorMap = post['author'] as Map<String, dynamic>?;
    final shelterMap = post['shelter'] as Map<String, dynamic>?;

    String authorName = 'My Future Pet';
    String? authorAvatar;

    if (shelterMap != null && shelterMap['name'] != null) {
      authorName = shelterMap['name'].toString().toUpperCase();
      authorAvatar = shelterMap['logo_url']?.toString();
    } else if (authorMap != null && authorMap['full_name'] != null) {
      authorName = authorMap['full_name'].toString();
      authorAvatar = authorMap['avatar_url']?.toString();
    }

    final bool isLiked = _likedPostIds[postId] ?? false;
    final int likes = _likeCounts[postId] ?? ((post['like_count'] as num?)?.toInt() ?? 0);
    final int comments = _commentCounts[postId] ?? ((post['comment_count'] as num?)?.toInt() ?? 0);
    final bool isReposted = _repostedPostIds.contains(postId);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCFE8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Time, More options
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFD0E3EA),
                  backgroundImage: (authorAvatar != null && authorAvatar.isNotEmpty)
                      ? NetworkImage(authorAvatar)
                      : null,
                  child: (authorAvatar == null || authorAvatar.isEmpty)
                      ? Text(
                          authorName.isNotEmpty ? authorName[0].toUpperCase() : 'P',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          color: isDark ? const Color(0xFFF8FAFC) : darkText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.more_horiz_rounded,
                  color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
                ),
              ],
            ),
          ),

          // Post Image (if present)
          if (imageUrl != null && imageUrl.trim().isNotEmpty)
            Container(
              width: double.infinity,
              height: 230,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              ),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 40),
                ),
              ),
            ),

          // Post Text Content
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Text(
              content,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              ),
            ),
          ),

          // Faint divider line
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          ),

          // ACTION BAR: Heart, Comment, Repost, Share
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                // Heart / Like
                GestureDetector(
                  onTap: () => _toggleLike(postId),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 21,
                        color: isLiked ? Colors.red : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatCount(likes),
                        style: TextStyle(
                          color: isLiked ? Colors.red : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 20),

                // Comment
                GestureDetector(
                  onTap: () => _showCommentsModal(postId, authorName),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 20,
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatCount(comments),
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 20),

                // Repost
                GestureDetector(
                  onTap: () => _handleRepost(post),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Icon(
                        isReposted ? Icons.repeat_on_rounded : Icons.repeat_rounded,
                        size: 21,
                        color: isReposted
                            ? primaryColor
                            : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isReposted ? 'Reposted' : 'Repost',
                        style: TextStyle(
                          color: isReposted
                              ? primaryColor
                              : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                          fontSize: 12,
                          fontWeight: isReposted ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Share
                GestureDetector(
                  onTap: () => _sharePost(author: authorName, content: content),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.share_outlined,
                      size: 21,
                      color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REPOST CARD (MARY'S DESIGN WITH LIVE SUPABASE SYNC)
  // ============================================================
  Widget _buildRepostCard(_RepostData repost) {
    final bool isDark = ThemeService.isDarkMode(context);
    final String postId = repost.originalPostId;

    final bool isLiked = _likedPostIds[postId] ?? false;
    final int likes = _likeCounts[postId] ?? 0;
    final int comments = _commentCounts[postId] ?? 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCFE8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Repost Header: Current User / Reposter Info
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFD0E3EA),
                backgroundImage: repost.reposterImage.isNotEmpty
                    ? NetworkImage(repost.reposterImage)
                    : null,
                child: repost.reposterImage.isEmpty
                    ? Text(
                        repost.reposterName.isNotEmpty ? repost.reposterName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 13),
                      )
                    : null,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            repost.reposterName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? const Color(0xFFF8FAFC) : darkText,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.repeat_rounded,
                          size: 15,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Reposted',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Just now',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
                onPressed: () => _confirmRemoveRepost(postId),
                tooltip: 'Remove Repost',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Nested Box Containing Original Story
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Original author header
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFFD0E3EA),
                        backgroundImage: (repost.originalAvatar != null && repost.originalAvatar!.isNotEmpty)
                            ? NetworkImage(repost.originalAvatar!)
                            : null,
                        child: (repost.originalAvatar == null || repost.originalAvatar!.isEmpty)
                            ? Text(
                                repost.originalAuthor.isNotEmpty ? repost.originalAuthor[0].toUpperCase() : 'P',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 11),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              repost.originalAuthor,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: isDark ? const Color(0xFFF8FAFC) : darkText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              repost.originalTime,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Original image (if present)
                if (repost.originalImage != null && repost.originalImage!.trim().isNotEmpty)
                  Image.network(
                    repost.originalImage!,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),

                // Original content text
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Text(
                    repost.originalContent,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Divider
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          ),

          // Action row: Live database synced
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                // Like
                GestureDetector(
                  onTap: () => _toggleLike(postId),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 20,
                        color: isLiked ? Colors.red : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatCount(likes),
                        style: TextStyle(
                          color: isLiked ? Colors.red : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 20),

                // Comment
                GestureDetector(
                  onTap: () => _showCommentsModal(postId, repost.originalAuthor),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 19,
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatCount(comments),
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 20),

                // Reposted toggle
                GestureDetector(
                  onTap: () => _confirmRemoveRepost(postId),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.repeat_on_rounded,
                        size: 19,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Reposted',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Share
                GestureDetector(
                  onTap: () => _sharePost(author: repost.originalAuthor, content: repost.originalContent),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.share_outlined,
                      size: 20,
                      color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FLOATING CREATE POST BUTTON
  // ============================================================
  Widget _buildCreatePostButton() {
    return GestureDetector(
      onTap: _openCreatePostModal,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.edit_rounded,
          color: Colors.white,
          size: 25,
        ),
      ),
    );
  }
}

// ============================================================
// REAL COMMENTS BOTTOM SHEET
// ============================================================
class _CommentsSheet extends StatefulWidget {
  final String postId;
  final String postAuthor;
  final bool isDark;
  final CommunityService communityService;
  final VoidCallback onCommentAdded;

  const _CommentsSheet({
    required this.postId,
    required this.postAuthor,
    required this.isDark,
    required this.communityService,
    required this.onCommentAdded,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _commentCtrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    final list = await widget.communityService.fetchComments(widget.postId);
    if (mounted) {
      setState(() {
        _comments = list;
        _loading = false;
      });
    }
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    _commentCtrl.clear();

    try {
      final newComment = await widget.communityService.addComment(
        postId: widget.postId,
        content: text,
      );

      if (mounted) {
        setState(() {
          _comments.add(newComment);
          _submitting = false;
        });
        widget.onCommentAdded();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please log in to comment: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = widget.isDark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7 + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Comments (${_comments.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: isDark ? const Color(0xFF94A3B8) : Colors.grey,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),

          // Comments List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFA94327)))
                : _comments.isEmpty
                    ? Center(
                        child: Text(
                          'No comments yet. Start the conversation!',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500,
                            fontSize: 13.5,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final c = _comments[index];
                          final author = c['author'] as Map<String, dynamic>?;
                          final name = author?['full_name']?.toString() ?? 'User';
                          final content = c['content']?.toString() ?? '';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFFD0E3EA),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFFA94327),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          content,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Bottom Input Bar
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    style: TextStyle(color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B), fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400, fontSize: 13.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _submitComment(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFFA94327)),
                  onPressed: _submitComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}