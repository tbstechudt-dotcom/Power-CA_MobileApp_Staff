import 'package:equatable/equatable.dart';
import '../../domain/entities/pinboard_item.dart';

abstract class PinboardEvent extends Equatable {
  const PinboardEvent();

  @override
  List<Object?> get props => [];
}

class LoadPinboardItems extends PinboardEvent {
  final PinboardCategory? category;

  const LoadPinboardItems({this.category});

  @override
  List<Object?> get props => [category];
}

class LoadPinboardItemDetails extends PinboardEvent {
  final String id;

  const LoadPinboardItemDetails(this.id);

  @override
  List<Object?> get props => [id];
}

class LoadComments extends PinboardEvent {
  final String pinboardItemId;

  const LoadComments(this.pinboardItemId);

  @override
  List<Object?> get props => [pinboardItemId];
}

class AddCommentEvent extends PinboardEvent {
  final String pinboardItemId;
  final String content;

  const AddCommentEvent({
    required this.pinboardItemId,
    required this.content,
  });

  @override
  List<Object?> get props => [pinboardItemId, content];
}

class ToggleLikeEvent extends PinboardEvent {
  final String pinboardItemId;

  const ToggleLikeEvent(this.pinboardItemId);

  @override
  List<Object?> get props => [pinboardItemId];
}

class RefreshPinboardItems extends PinboardEvent {
  final PinboardCategory? category;

  const RefreshPinboardItems({this.category});

  @override
  List<Object?> get props => [category];
}
