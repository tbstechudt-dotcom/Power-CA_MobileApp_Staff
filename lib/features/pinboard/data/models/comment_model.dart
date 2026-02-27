import '../../domain/entities/comment.dart';

class CommentModel extends Comment {
  const CommentModel({
    required super.id,
    required super.pinboardItemId,
    required super.authorName,
    required super.authorId,
    required super.content,
    required super.createdAt,
    super.updatedAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id']?.toString() ?? '',
      pinboardItemId: json['pinboard_item_id']?.toString() ?? '',
      authorName: json['author_name']?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pinboard_item_id': pinboardItemId,
      'author_name': authorName,
      'author_id': authorId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Comment toEntity() {
    return Comment(
      id: id,
      pinboardItemId: pinboardItemId,
      authorName: authorName,
      authorId: authorId,
      content: content,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
