import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/pinboard_item.dart';
import '../bloc/pinboard_bloc.dart';
import '../bloc/pinboard_event.dart';
import '../bloc/pinboard_state.dart';

class PinboardCategoryListPage extends StatefulWidget {
  final PinboardCategory category;
  final String categoryTitle;

  const PinboardCategoryListPage({
    super.key,
    required this.category,
    required this.categoryTitle,
  });

  @override
  State<PinboardCategoryListPage> createState() =>
      _PinboardCategoryListPageState();
}

class _PinboardCategoryListPageState extends State<PinboardCategoryListPage> {
  @override
  void initState() {
    super.initState();
    context.read<PinboardBloc>().add(
          LoadPinboardItems(category: widget.category),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryTitle),
        elevation: 0,
      ),
      body: BlocBuilder<PinboardBloc, PinboardState>(
        builder: (context, state) {
          if (state is PinboardLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is PinboardError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64.sp,
                    color: Colors.red,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16.sp),
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<PinboardBloc>().add(
                            LoadPinboardItems(category: widget.category),
                          );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is PinboardLoaded) {
            if (state.items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 64.sp,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'No items in ${widget.categoryTitle.toLowerCase()}',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<PinboardBloc>().add(
                      RefreshPinboardItems(category: widget.category),
                    );
              },
              child: ListView.separated(
                padding: EdgeInsets.all(16.w),
                itemCount: state.items.length,
                separatorBuilder: (context, index) =>
                    SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  return _PinboardItemCard(
                    item: item,
                    onTap: () {
                      // TODO: This BLoC-based page is not currently used.
                      // The app uses pinboard_main_page.dart with direct Supabase integration.
                      // To re-enable navigation, update PinboardDetailPage to support BLoC pattern
                      // or convert this page to use direct Supabase queries.
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Detail view not available in this mode'),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _PinboardItemCard extends StatelessWidget {
  final PinboardItem item;
  final VoidCallback onTap;

  const _PinboardItemCard({
    required this.item,
    required this.onTap,
  });

  Color _getCategoryColor() {
    switch (item.category) {
      case PinboardCategory.dueDate:
        return Colors.orange;
      case PinboardCategory.meetings:
        return Colors.blue;
      case PinboardCategory.greetings:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor();
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image (if available)
            if (item.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12.r),
                  topRight: Radius.circular(12.r),
                ),
                child: Image.network(
                  item.imageUrl!,
                  height: 180.h,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 180.h,
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.image_not_supported,
                        size: 64.sp,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),

            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: 8.h),

                  // Description
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[600],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: 12.h),

                  // Event Date and Location
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16.sp,
                        color: categoryColor,
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          '${dateFormat.format(item.eventDate)} at ${timeFormat.format(item.eventDate)}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (item.location != null) ...[
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16.sp,
                          color: categoryColor,
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            item.location!,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  SizedBox(height: 12.h),
                  const Divider(height: 1),
                  SizedBox(height: 12.h),

                  // Author and Stats
                  Row(
                    children: [
                      // Author
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12.r,
                              backgroundColor: categoryColor.withValues(alpha: 0.2),
                              child: Icon(
                                Icons.person,
                                size: 14.sp,
                                color: categoryColor,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Expanded(
                              child: Text(
                                item.authorName,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Stats
                      Row(
                        children: [
                          Icon(
                            item.isLikedByCurrentUser
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 16.sp,
                            color: item.isLikedByCurrentUser
                                ? Colors.red
                                : Colors.grey,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            '${item.likesCount}',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                          SizedBox(width: 12.w),
                          Icon(
                            Icons.comment_outlined,
                            size: 16.sp,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            '${item.commentsCount}',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
