import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/soft_page.dart';
import '../../../../shared/widgets/soft_ui.dart';
import '../../domain/entities/comment.dart';
import '../bloc/pinboard_bloc.dart';
import '../bloc/pinboard_event.dart';

class CommentsTab extends StatefulWidget {
  final String pinboardItemId;
  final List<Comment> comments;
  final bool isLoading;

  const CommentsTab({
    super.key,
    required this.pinboardItemId,
    required this.comments,
    required this.isLoading,
  });

  @override
  State<CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends State<CommentsTab> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _addComment() {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    context.read<PinboardBloc>().add(
          AddCommentEvent(
            pinboardItemId: widget.pinboardItemId,
            content: content,
          ),
        );

    _commentController.clear();
    _commentFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);

    return Column(
      children: [
        // Comments List
        Expanded(
          child: widget.isLoading
              ? Center(
                  child: CircularProgressIndicator(color: p.ink, strokeWidth: 2.4),
                )
              : widget.comments.isEmpty
                  ? const SoftMessage(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'No comments yet',
                      message: 'Be the first to comment!',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      itemCount: widget.comments.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final comment = widget.comments[index];
                        return _CommentItem(comment: comment);
                      },
                    ),
        ),

        // Comment Input
        Container(
          decoration: BoxDecoration(
            color: p.background,
            border: Border(top: BorderSide(color: p.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      style: softInputTextStyle(context),
                      decoration: softInputDecoration(
                        context,
                        hint: 'Write a comment...',
                        dense: true,
                      ).copyWith(
                        border: _roundBorder(p.border),
                        enabledBorder: _roundBorder(p.border),
                        focusedBorder: _roundBorder(p.ink, 1.4),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: p.pill,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _addComment,
                      child: SizedBox(
                        width: 46,
                        height: 46,
                        child: Icon(Icons.arrow_upward_rounded, size: 22, color: p.onPill),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _roundBorder(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: c, width: w),
      );
}

class _CommentItem extends StatelessWidget {
  final Comment comment;

  const _CommentItem({required this.comment});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final initial = comment.authorName.trim().isNotEmpty
        ? comment.authorName.trim()[0].toUpperCase()
        : '?';

    return SoftCard(
      padding: const EdgeInsets.all(14),
      radius: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: p.accentSoft,
            child: Text(
              initial,
              style: SoftText.heading(p, size: 13).copyWith(color: p.accent),
            ),
          ),
          const SizedBox(width: 12),
          // Comment Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author and Date
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.authorName,
                        style: SoftText.heading(p, size: 14),
                      ),
                    ),
                    Text(
                      dateFormat.format(comment.createdAt),
                      style: SoftText.caption(p, size: 11),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Comment Text
                Text(
                  comment.content,
                  style: SoftText.body(p, color: p.ink),
                ),

                // Edited indicator
                if (comment.updatedAt != null &&
                    comment.updatedAt != comment.createdAt) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Edited',
                    style: SoftText.caption(p, size: 11).copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
