import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/pinboard_item.dart';
import '../models/comment_model.dart';
import '../models/pinboard_item_model.dart';

abstract class PinboardRemoteDataSource {
  Future<List<PinboardItemModel>> getPinboardItems({
    PinboardCategory? category,
  });

  Future<PinboardItemModel> getPinboardItemById(String id);

  Future<List<CommentModel>> getComments(String pinboardItemId);

  Future<CommentModel> addComment({
    required String pinboardItemId,
    required String content,
    required String authorId,
    required String authorName,
  });

  Future<void> toggleLike({
    required String pinboardItemId,
    required String userId,
  });

  Future<PinboardItemModel> createPinboardItem({
    required String title,
    required String description,
    String? imageUrl,
    String? location,
    required DateTime eventDate,
    required PinboardCategory category,
    required String authorId,
    required String authorName,
  });
}

class PinboardRemoteDataSourceImpl implements PinboardRemoteDataSource {
  final SupabaseClient supabaseClient;

  PinboardRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<PinboardItemModel>> getPinboardItems({
    PinboardCategory? category,
  }) async {
    try {
      dynamic query = supabaseClient
          .from('pinboard_items')
          .select('''
            *,
            pinboard_likes!left(user_id),
            pinboard_comments!left(id)
          ''');

      if (category != null) {
        final categoryStr = _categoryToString(category);
        query = query.eq('category', categoryStr);
      }

      query = query.order('created_at', ascending: false);

      final response = await query;

      final currentUserId = supabaseClient.auth.currentUser?.id;

      return (response as List).map((item) {
        final itemMap = item as Map<String, dynamic>;
        final likes = itemMap['pinboard_likes'] as List? ?? [];
        final comments = itemMap['pinboard_comments'] as List? ?? [];

        return PinboardItemModel.fromJson({
          ...itemMap,
          'likes_count': likes.length,
          'is_liked_by_current_user': currentUserId != null
              ? likes.any((like) => like['user_id'] == currentUserId)
              : false,
          'comments_count': comments.length,
        });
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch pinboard items: $e');
    }
  }

  @override
  Future<PinboardItemModel> getPinboardItemById(String id) async {
    try {
      final response = await supabaseClient
          .from('pinboard_items')
          .select('''
            *,
            pinboard_likes!left(user_id),
            pinboard_comments!left(id)
          ''')
          .eq('id', id)
          .single();

      final currentUserId = supabaseClient.auth.currentUser?.id;
      final responseMap = response as Map<String, dynamic>;
      final likes = responseMap['pinboard_likes'] as List? ?? [];
      final comments = responseMap['pinboard_comments'] as List? ?? [];

      return PinboardItemModel.fromJson({
        ...responseMap,
        'likes_count': likes.length,
        'is_liked_by_current_user': currentUserId != null
            ? likes.any((like) => like['user_id'] == currentUserId)
            : false,
        'comments_count': comments.length,
      });
    } catch (e) {
      throw Exception('Failed to fetch pinboard item: $e');
    }
  }

  @override
  Future<List<CommentModel>> getComments(String pinboardItemId) async {
    try {
      final response = await supabaseClient
          .from('pinboard_comments')
          .select()
          .eq('pinboard_item_id', pinboardItemId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => CommentModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch comments: $e');
    }
  }

  @override
  Future<CommentModel> addComment({
    required String pinboardItemId,
    required String content,
    required String authorId,
    required String authorName,
  }) async {
    try {
      final response = await supabaseClient
          .from('pinboard_comments')
          .insert({
            'pinboard_item_id': pinboardItemId,
            'author_id': authorId,
            'author_name': authorName,
            'content': content,
          })
          .select()
          .single();

      return CommentModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  @override
  Future<void> toggleLike({
    required String pinboardItemId,
    required String userId,
  }) async {
    try {
      // Check if like exists
      final existingLike = await supabaseClient
          .from('pinboard_likes')
          .select()
          .eq('pinboard_item_id', pinboardItemId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingLike != null) {
        // Unlike
        await supabaseClient
            .from('pinboard_likes')
            .delete()
            .eq('pinboard_item_id', pinboardItemId)
            .eq('user_id', userId);
      } else {
        // Like
        await supabaseClient.from('pinboard_likes').insert({
          'pinboard_item_id': pinboardItemId,
          'user_id': userId,
        });
      }
    } catch (e) {
      throw Exception('Failed to toggle like: $e');
    }
  }

  @override
  Future<PinboardItemModel> createPinboardItem({
    required String title,
    required String description,
    String? imageUrl,
    String? location,
    required DateTime eventDate,
    required PinboardCategory category,
    required String authorId,
    required String authorName,
  }) async {
    try {
      final response = await supabaseClient
          .from('pinboard_items')
          .insert({
            'title': title,
            'description': description,
            'image_url': imageUrl,
            'location': location,
            'event_date': eventDate.toIso8601String(),
            'category': _categoryToString(category),
            'author_id': authorId,
            'author_name': authorName,
          })
          .select()
          .single();

      final responseMap = response as Map<String, dynamic>;
      return PinboardItemModel.fromJson({
        ...responseMap,
        'likes_count': 0,
        'is_liked_by_current_user': false,
        'comments_count': 0,
      });
    } catch (e) {
      throw Exception('Failed to create pinboard item: $e');
    }
  }

  String _categoryToString(PinboardCategory category) {
    switch (category) {
      case PinboardCategory.dueDate:
        return 'due_date';
      case PinboardCategory.meetings:
        return 'meetings';
      case PinboardCategory.greetings:
        return 'greetings';
    }
  }
}
