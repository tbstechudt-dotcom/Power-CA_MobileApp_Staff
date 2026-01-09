import '../../domain/entities/pinboard_item.dart';

class PinboardItemModel extends PinboardItem {
  const PinboardItemModel({
    required super.id,
    required super.authorName,
    required super.authorId,
    required super.title,
    required super.description,
    super.imageUrl,
    super.location,
    required super.eventDate,
    required super.createdAt,
    required super.category,
    super.likesCount,
    super.isLikedByCurrentUser,
    super.commentsCount,
  });

  factory PinboardItemModel.fromJson(Map<String, dynamic> json) {
    return PinboardItemModel(
      id: json['id']?.toString() ?? '',
      authorName: json['author_name']?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      location: json['location']?.toString(),
      eventDate: json['event_date'] != null
          ? DateTime.parse(json['event_date'])
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      category: _parseCategoryFromString(json['category']?.toString()),
      likesCount: json['likes_count'] ?? 0,
      isLikedByCurrentUser: json['is_liked_by_current_user'] ?? false,
      commentsCount: json['comments_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author_name': authorName,
      'author_id': authorId,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'location': location,
      'event_date': eventDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'category': _categoryToString(category),
      'likes_count': likesCount,
      'is_liked_by_current_user': isLikedByCurrentUser,
      'comments_count': commentsCount,
    };
  }

  static PinboardCategory _parseCategoryFromString(String? category) {
    switch (category?.toLowerCase()) {
      case 'due_date':
      case 'duedate':
        return PinboardCategory.dueDate;
      case 'meetings':
        return PinboardCategory.meetings;
      case 'greetings':
        return PinboardCategory.greetings;
      default:
        return PinboardCategory.dueDate;
    }
  }

  static String _categoryToString(PinboardCategory category) {
    switch (category) {
      case PinboardCategory.dueDate:
        return 'due_date';
      case PinboardCategory.meetings:
        return 'meetings';
      case PinboardCategory.greetings:
        return 'greetings';
    }
  }

  PinboardItem toEntity() {
    return PinboardItem(
      id: id,
      authorName: authorName,
      authorId: authorId,
      title: title,
      description: description,
      imageUrl: imageUrl,
      location: location,
      eventDate: eventDate,
      createdAt: createdAt,
      category: category,
      likesCount: likesCount,
      isLikedByCurrentUser: isLikedByCurrentUser,
      commentsCount: commentsCount,
    );
  }
}
