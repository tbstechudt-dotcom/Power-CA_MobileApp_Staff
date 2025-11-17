import 'package:equatable/equatable.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/pinboard_item.dart';

abstract class PinboardState extends Equatable {
  const PinboardState();

  @override
  List<Object?> get props => [];
}

class PinboardInitial extends PinboardState {}

class PinboardLoading extends PinboardState {}

class PinboardLoaded extends PinboardState {
  final List<PinboardItem> items;

  const PinboardLoaded(this.items);

  @override
  List<Object?> get props => [items];
}

class PinboardItemDetailsLoaded extends PinboardState {
  final PinboardItem item;
  final List<Comment> comments;
  final bool isLoadingComments;

  const PinboardItemDetailsLoaded({
    required this.item,
    this.comments = const [],
    this.isLoadingComments = false,
  });

  PinboardItemDetailsLoaded copyWith({
    PinboardItem? item,
    List<Comment>? comments,
    bool? isLoadingComments,
  }) {
    return PinboardItemDetailsLoaded(
      item: item ?? this.item,
      comments: comments ?? this.comments,
      isLoadingComments: isLoadingComments ?? this.isLoadingComments,
    );
  }

  @override
  List<Object?> get props => [item, comments, isLoadingComments];
}

class PinboardError extends PinboardState {
  final String message;

  const PinboardError(this.message);

  @override
  List<Object?> get props => [message];
}

class CommentAdded extends PinboardState {
  final Comment comment;

  const CommentAdded(this.comment);

  @override
  List<Object?> get props => [comment];
}

class LikeToggled extends PinboardState {
  final String pinboardItemId;

  const LikeToggled(this.pinboardItemId);

  @override
  List<Object?> get props => [pinboardItemId];
}
