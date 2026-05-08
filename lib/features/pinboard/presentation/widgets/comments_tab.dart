import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/theme_provider.dart';
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
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final emptyIconColor = isDarkMode ? const Color(0xFF64748B) : Colors.grey[400];
    final emptyTextColor = isDarkMode ? const Color(0xFF94A3B8) : Colors.grey[600];
    final emptySubtextColor = isDarkMode ? const Color(0xFF64748B) : Colors.grey[500];
    final inputContainerBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final inputFieldBgColor = isDarkMode ? const Color(0xFF334155) : Colors.grey[100];
    final inputTextColor = isDarkMode ? const Color(0xFFF1F5F9) : Colors.black;
    final inputHintColor = isDarkMode ? const Color(0xFF64748B) : Colors.grey[600];
    final dividerColor = isDarkMode ? const Color(0xFF334155) : Colors.grey[300];

    return Column(
      children: [
        // Comments List
        Expanded(
          child: widget.isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : widget.comments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.comment_outlined,
                            size: 64.sp,
                            color: emptyIconColor,
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'No comments yet',
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: emptyTextColor,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Be the first to comment!',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: emptySubtextColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.all(16.w),
                      itemCount: widget.comments.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 24.h, color: dividerColor),
                      itemBuilder: (context, index) {
                        final comment = widget.comments[index];
                        return _CommentItem(comment: comment, isDarkMode: isDarkMode);
                      },
                    ),
        ),

        // Comment Input
        Container(
          decoration: BoxDecoration(
            color: inputContainerBgColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      style: TextStyle(color: inputTextColor),
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle: TextStyle(color: inputHintColor),
                        filled: true,
                        fillColor: inputFieldBgColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.r),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _addComment,
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
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
}

class _CommentItem extends StatelessWidget {
  final Comment comment;
  final bool isDarkMode;

  const _CommentItem({required this.comment, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final authorNameColor = isDarkMode ? const Color(0xFFF1F5F9) : Colors.black;
    final dateColor = isDarkMode ? const Color(0xFF64748B) : Colors.grey[600];
    final contentColor = isDarkMode ? const Color(0xFFCBD5E1) : Colors.grey[800];
    final editedColor = isDarkMode ? const Color(0xFF64748B) : Colors.grey[500];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.sp,
                        color: authorNameColor,
                      ),
                    ),
                  ),
                  Text(
                    dateFormat.format(comment.createdAt),
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: dateColor,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 6.h),

              // Comment Text
              Text(
                comment.content,
                style: TextStyle(
                  fontSize: 14.sp,
                  height: 1.4,
                  color: contentColor,
                ),
              ),

              // Edited indicator
              if (comment.updatedAt != null &&
                  comment.updatedAt != comment.createdAt) ...[
                SizedBox(height: 4.h),
                Text(
                  'Edited',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: editedColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
