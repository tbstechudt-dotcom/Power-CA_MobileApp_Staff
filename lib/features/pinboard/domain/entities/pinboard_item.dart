import 'package:equatable/equatable.dart';

enum PinboardCategory {
  dueDate,
  meetings,
  greetings,
}

class PinboardItem extends Equatable {
  final String id;
  final String authorName;
  final String authorId;
  final String title;
  final String description;
  final String? imageUrl;
  final String? location;
  final DateTime eventDate;
  final DateTime createdAt;
  final PinboardCategory category;
  final int likesCount;
  final bool isLikedByCurrentUser;
  final int commentsCount;

  const PinboardItem({
    required this.id,
    required this.authorName,
    required this.authorId,
    required this.title,
    required this.description,
    this.imageUrl,
    this.location,
    required this.eventDate,
    required this.createdAt,
    required this.category,
    this.likesCount = 0,
    this.isLikedByCurrentUser = false,
    this.commentsCount = 0,
  });

  PinboardItem copyWith({
    String? id,
    String? authorName,
    String? authorId,
    String? title,
    String? description,
    String? imageUrl,
    String? location,
    DateTime? eventDate,
    DateTime? createdAt,
    PinboardCategory? category,
    int? likesCount,
    bool? isLikedByCurrentUser,
    int? commentsCount,
  }) {
    return PinboardItem(
      id: id ?? this.id,
      authorName: authorName ?? this.authorName,
      authorId: authorId ?? this.authorId,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      location: location ?? this.location,
      eventDate: eventDate ?? this.eventDate,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
      likesCount: likesCount ?? this.likesCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      commentsCount: commentsCount ?? this.commentsCount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        authorName,
        authorId,
        title,
        description,
        imageUrl,
        location,
        eventDate,
        createdAt,
        category,
        likesCount,
        isLikedByCurrentUser,
        commentsCount,
      ];
}
