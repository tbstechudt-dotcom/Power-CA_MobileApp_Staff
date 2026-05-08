import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/add_comment_usecase.dart';
import '../../domain/usecases/get_comments_usecase.dart';
import '../../domain/usecases/get_pinboard_item_by_id_usecase.dart';
import '../../domain/usecases/get_pinboard_items_usecase.dart';
import '../../domain/usecases/toggle_like_usecase.dart';
import 'pinboard_event.dart';
import 'pinboard_state.dart';

class PinboardBloc extends Bloc<PinboardEvent, PinboardState> {
  final GetPinboardItemsUseCase getPinboardItems;
  final GetPinboardItemByIdUseCase getPinboardItemById;
  final GetCommentsUseCase getComments;
  final AddCommentUseCase addComment;
  final ToggleLikeUseCase toggleLike;

  PinboardBloc({
    required this.getPinboardItems,
    required this.getPinboardItemById,
    required this.getComments,
    required this.addComment,
    required this.toggleLike,
  }) : super(PinboardInitial()) {
    on<LoadPinboardItems>(_onLoadPinboardItems);
    on<LoadPinboardItemDetails>(_onLoadPinboardItemDetails);
    on<LoadComments>(_onLoadComments);
    on<AddCommentEvent>(_onAddComment);
    on<ToggleLikeEvent>(_onToggleLike);
    on<RefreshPinboardItems>(_onRefreshPinboardItems);
  }

  Future<void> _onLoadPinboardItems(
    LoadPinboardItems event,
    Emitter<PinboardState> emit,
  ) async {
    emit(PinboardLoading());

    final result = await getPinboardItems(category: event.category);

    result.fold(
      (failure) => emit(PinboardError(failure.message)),
      (items) => emit(PinboardLoaded(items)),
    );
  }

  Future<void> _onLoadPinboardItemDetails(
    LoadPinboardItemDetails event,
    Emitter<PinboardState> emit,
  ) async {
    emit(PinboardLoading());

    final result = await getPinboardItemById(event.id);

    await result.fold(
      (failure) async => emit(PinboardError(failure.message)),
      (item) async {
        emit(PinboardItemDetailsLoaded(
          item: item,
          isLoadingComments: true,
        ));

        // Load comments
        final commentsResult = await getComments(event.id);

        commentsResult.fold(
          (failure) {
            // Keep item loaded, just show error for comments
            emit(PinboardItemDetailsLoaded(
              item: item,
              comments: [],
              isLoadingComments: false,
            ));
          },
          (comments) {
            emit(PinboardItemDetailsLoaded(
              item: item,
              comments: comments,
              isLoadingComments: false,
            ));
          },
        );
      },
    );
  }

  Future<void> _onLoadComments(
    LoadComments event,
    Emitter<PinboardState> emit,
  ) async {
    if (state is PinboardItemDetailsLoaded) {
      final currentState = state as PinboardItemDetailsLoaded;
      emit(currentState.copyWith(isLoadingComments: true));

      final result = await getComments(event.pinboardItemId);

      result.fold(
        (failure) {
          emit(currentState.copyWith(isLoadingComments: false));
        },
        (comments) {
          emit(currentState.copyWith(
            comments: comments,
            isLoadingComments: false,
          ));
        },
      );
    }
  }

  Future<void> _onAddComment(
    AddCommentEvent event,
    Emitter<PinboardState> emit,
  ) async {
    final result = await addComment(
      pinboardItemId: event.pinboardItemId,
      content: event.content,
    );

    await result.fold(
      (failure) async => emit(PinboardError(failure.message)),
      (comment) async {
        emit(CommentAdded(comment));

        // Reload comments
        final commentsResult = await getComments(event.pinboardItemId);

        if (state is PinboardItemDetailsLoaded) {
          final currentState = state as PinboardItemDetailsLoaded;

          commentsResult.fold(
            (failure) {},
            (comments) {
              emit(currentState.copyWith(
                comments: comments,
                item: currentState.item.copyWith(
                  commentsCount: comments.length,
                ),
              ));
            },
          );
        }
      },
    );
  }

  Future<void> _onToggleLike(
    ToggleLikeEvent event,
    Emitter<PinboardState> emit,
  ) async {
    final result = await toggleLike(event.pinboardItemId);

    await result.fold(
      (failure) async => emit(PinboardError(failure.message)),
      (_) async {
        emit(LikeToggled(event.pinboardItemId));

        // Reload item details to update like count
        if (state is PinboardItemDetailsLoaded) {
          final itemResult = await getPinboardItemById(event.pinboardItemId);

          itemResult.fold(
            (failure) {},
            (item) {
              if (state is PinboardItemDetailsLoaded) {
                final currentState = state as PinboardItemDetailsLoaded;
                emit(currentState.copyWith(item: item));
              }
            },
          );
        }
      },
    );
  }

  Future<void> _onRefreshPinboardItems(
    RefreshPinboardItems event,
    Emitter<PinboardState> emit,
  ) async {
    final result = await getPinboardItems(category: event.category);

    result.fold(
      (failure) => emit(PinboardError(failure.message)),
      (items) => emit(PinboardLoaded(items)),
    );
  }
}
