import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityService {
  final SupabaseClient _client = Supabase.instance.client;

  // Local comments cache backed by SharedPreferences
  static final Map<String, List<Map<String, dynamic>>> _localComments = {};
  static final Map<String, int> _localCommentCounts = {};
  static bool _loadedFromPrefs = false;

  static Future<void> _loadLocalComments() async {
    if (_loadedFromPrefs) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('community_local_comments');
      if (saved != null && saved.isNotEmpty) {
        final decoded = jsonDecode(saved) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          if (value is List) {
            _localComments[key] = value.map((c) => Map<String, dynamic>.from(c as Map)).toList();
            _localCommentCounts[key] = _localComments[key]!.length;
          }
        });
      }
      _loadedFromPrefs = true;
    } catch (e) {
      debugPrint('Error loading local comments from prefs: $e');
    }
  }

  static Future<void> _saveLocalComments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('community_local_comments', jsonEncode(_localComments));
    } catch (e) {
      debugPrint('Error saving local comments to prefs: $e');
    }
  }

  /// Fetch community posts joined with shelter, pet, and author info
  Future<List<Map<String, dynamic>>> fetchPosts({String? category}) async {
    try {
      await _loadLocalComments();
      final user = _client.auth.currentUser;

      var query = _client
          .from('community_posts')
          .select('*, author:author_id(id, full_name, email, avatar_url), shelter:shelter_id(id, name, logo_url), pet:pet_id(id, name, type, breed, image_url), post_comments(count)');

      if (category != null && category != 'All' && category.isNotEmpty) {
        query = query.eq('category', category);
      }

      final response = await query
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;

      // If user is logged in, fetch their liked posts to flag is_liked_by_me
      Set<String> userLikedPostIds = {};
      if (user != null) {
        try {
          final likesResponse = await _client
              .from('post_likes')
              .select('post_id')
              .eq('user_id', user.id);
          for (var item in (likesResponse as List<dynamic>)) {
            if (item['post_id'] != null) {
              userLikedPostIds.add(item['post_id'].toString());
            }
          }
        } catch (e) {
          debugPrint('Error fetching user post likes: $e');
        }
      }

      return data.map((item) {
        final map = Map<String, dynamic>.from(item as Map<String, dynamic>);
        final postId = map['id']?.toString() ?? '';
        map['is_liked_by_me'] = userLikedPostIds.contains(postId);

        // Extract live count from Supabase post_comments relation or local cache
        final postCommentsRelation = map['post_comments'] as List<dynamic>?;
        int remoteCount = 0;
        if (postCommentsRelation != null && postCommentsRelation.isNotEmpty) {
          remoteCount = (postCommentsRelation[0]['count'] as num?)?.toInt() ?? 0;
        } else {
          remoteCount = (map['comment_count'] as num?)?.toInt() ?? 0;
        }

        final localCount = _localCommentCounts[postId] ?? 0;
        map['comment_count'] = math.max(remoteCount, localCount);

        return map;
      }).toList();
    } catch (e) {
      debugPrint('Error fetching community posts: $e');
      return [];
    }
  }

  /// Toggle like/unlike on a community post and update like_count
  Future<bool> toggleLike(String postId, bool isCurrentlyLiked, int currentLikes) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to like a post.');
    }

    try {
      if (isCurrentlyLiked) {
        await _client
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', user.id);
        
        final newCount = (currentLikes > 0) ? currentLikes - 1 : 0;
        try {
          await _client
              .from('community_posts')
              .update({'like_count': newCount})
              .eq('id', postId);
        } catch (_) {}
        return false;
      } else {
        await _client
            .from('post_likes')
            .insert({
              'post_id': postId,
              'user_id': user.id,
            });

        final newCount = currentLikes + 1;
        try {
          await _client
              .from('community_posts')
              .update({'like_count': newCount})
              .eq('id', postId);
        } catch (_) {}
        return true;
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
      rethrow;
    }
  }

  /// Fetch real comments for a post
  Future<List<Map<String, dynamic>>> fetchComments(String postId) async {
    await _loadLocalComments();
    try {
      final response = await _client
          .from('post_comments')
          .select('*, author:user_id(id, full_name, email, avatar_url)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      final List<dynamic> list = response as List<dynamic>;
      final remoteComments = list.map((item) => Map<String, dynamic>.from(item as Map<String, dynamic>)).toList();

      // Merge with any local comments
      final local = _localComments[postId] ?? [];
      final Set<String> existingIds = remoteComments.map((c) => c['id']?.toString() ?? '').toSet();
      for (final loc in local) {
        if (!existingIds.contains(loc['id'])) {
          remoteComments.add(loc);
        }
      }

      _localCommentCounts[postId] = remoteComments.length;
      return remoteComments;
    } catch (e) {
      debugPrint('Notice: Remote post_comments fallback to local memory: $e');
      return _localComments[postId] ?? [];
    }
  }

  /// Add a real comment to a post
  Future<Map<String, dynamic>> addComment({
    required String postId,
    required String content,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to comment.');
    }

    final String authorName = user.userMetadata?['full_name'] ??
        user.userMetadata?['name'] ??
        user.email?.split('@').first ??
        'User';

    final newComment = <String, dynamic>{
      'id': 'cmt_${DateTime.now().millisecondsSinceEpoch}',
      'post_id': postId,
      'user_id': user.id,
      'content': content.trim(),
      'created_at': DateTime.now().toIso8601String(),
      'author': {
        'id': user.id,
        'full_name': authorName,
        'email': user.email,
      },
    };

    // Store in local cache and save immediately
    if (!_localComments.containsKey(postId)) {
      _localComments[postId] = [];
    }
    _localComments[postId]!.add(newComment);
    _localCommentCounts[postId] = _localComments[postId]!.length;
    await _saveLocalComments();

    // Attempt remote save to Supabase
    try {
      final insertData = {
        'post_id': postId,
        'user_id': user.id,
        'content': content.trim(),
      };
      final res = await _client.from('post_comments').insert(insertData).select();
      if (res.isNotEmpty) {
        final remote = Map<String, dynamic>.from(res[0]);
        remote['author'] = newComment['author'];
        return remote;
      }
    } catch (e) {
      debugPrint('Saved locally, remote sync pending migration: $e');
    }

    // Try incrementing comment_count on post
    try {
      final current = _localCommentCounts[postId] ?? 1;
      await _client
          .from('community_posts')
          .update({'comment_count': current})
          .eq('id', postId);
    } catch (_) {}

    return newComment;
  }

  /// Create a new community post (users or shelters)
  Future<bool> createPost({
    required String content,
    String? imageUrl,
    String? category,
    String? petId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to create a post.');
    }

    try {
      final insertData = <String, dynamic>{
        'content': content.trim(),
        'author_id': user.id,
        'like_count': 0,
        'comment_count': 0,
        'is_pinned': false,
      };

      if (category != null && category.isNotEmpty) {
        insertData['category'] = category;
      }

      if (imageUrl != null && imageUrl.trim().isNotEmpty) {
        insertData['image_url'] = imageUrl.trim();
      }
      if (petId != null && petId.isNotEmpty) {
        insertData['pet_id'] = petId;
      }

      await _client.from('community_posts').insert(insertData);
      return true;
    } catch (e) {
      debugPrint('Error creating community post: $e');
      rethrow;
    }
  }

  /// Fetch active broadcast announcements
  Future<List<Map<String, dynamic>>> fetchAnnouncements() async {
    try {
      final response = await _client
          .from('announcements')
          .select()
          .order('created_at', ascending: false)
          .limit(5);

      final List<dynamic> list = response as List<dynamic>;
      return list.map((item) => Map<String, dynamic>.from(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
      return [];
    }
  }
}
