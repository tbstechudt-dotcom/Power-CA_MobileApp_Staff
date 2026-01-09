import 'package:equatable/equatable.dart';

class Comment extends Equatable {
  final String id;
  final String pinboardItemId;
  final String authorName;
  final String authorId;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Comment({
    required this.id,
    required this.pinboardItemId,
    required this.authorName,
    required this.authorId,
    required this.content,
    required this.createdAt,
    this.updatedAt,
  });

  Comment copyWith({
    String? id,
    String? pinboardItemId,
    String? authorName,
    String? authorId,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Comment(
      id: id ?? this.id,
      pinboardItemId: pinboardItemId ?? this.pinboardItemId,
      authorName: authorName ?? this.authorName,
      authorId: authorId ?? this.authorId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        pinboardItemId,
        authorName,
        authorId,
        content,
        createdAt,
        updatedAt,
      ];
}
