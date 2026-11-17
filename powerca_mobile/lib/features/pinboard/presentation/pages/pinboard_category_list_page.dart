import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/soft_page.dart';
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
    final p = SoftPalette.of(context);
    return SoftScaffold(
      title: widget.categoryTitle,
      body: BlocBuilder<PinboardBloc, PinboardState>(
        builder: (context, state) {
          if (state is PinboardLoading) {
            return Center(
              child: CircularProgressIndicator(color: p.ink, strokeWidth: 2.4),
            );
          }

          if (state is PinboardError) {
            return SoftMessage(
              icon: Icons.error_outline_rounded,
              title: 'Something went wrong',
              message: state.message,
              color: p.danger,
              actionLabel: 'Retry',
              onAction: () {
                context.read<PinboardBloc>().add(
                      LoadPinboardItems(category: widget.category),
                    );
              },
            );
          }

          if (state is PinboardLoaded) {
            if (state.items.isEmpty) {
              return SoftMessage(
                icon: Icons.inbox_outlined,
                title: 'No items in ${widget.categoryTitle.toLowerCase()}',
              );
            }

            return RefreshIndicator(
              color: p.ink,
              onRefresh: () async {
                context.read<PinboardBloc>().add(
                      RefreshPinboardItems(category: widget.category),
                    );
              },
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: state.items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
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

  Color _getCategoryColor(SoftPalette p) {
    switch (item.category) {
      case PinboardCategory.dueDate:
        return p.warning;
      case PinboardCategory.meetings:
        return p.accent;
      case PinboardCategory.greetings:
        return p.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final categoryColor = _getCategoryColor(p);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return SoftCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image (if available)
          if (item.imageUrl != null)
            Image.network(
              item.imageUrl!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 180,
                  color: p.surfaceAlt,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 48,
                    color: p.muted,
                  ),
                );
              },
            ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  item.title,
                  style: SoftText.heading(p, size: 17),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 6),

                // Description
                Text(
                  item.description,
                  style: SoftText.body(p),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 12),

                // Event Date and Location
                _metaRow(
                  p,
                  Icons.access_time_rounded,
                  categoryColor,
                  '${dateFormat.format(item.eventDate)} at ${timeFormat.format(item.eventDate)}',
                ),

                if (item.location != null) ...[
                  const SizedBox(height: 6),
                  _metaRow(p, Icons.location_on_outlined, categoryColor, item.location!),
                ],

                const SizedBox(height: 14),
                Divider(height: 1, color: p.border),
                const SizedBox(height: 12),

                // Author and Stats
                Row(
                  children: [
                    // Author
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: p.tint(categoryColor),
                            child: Icon(
                              Icons.person_rounded,
                              size: 14,
                              color: categoryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.authorName,
                              style: SoftText.caption(p).copyWith(color: p.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Stats
                    Icon(
                      item.isLikedByCurrentUser
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 16,
                      color: item.isLikedByCurrentUser ? p.danger : p.muted,
                    ),
                    const SizedBox(width: 4),
                    Text('${item.likesCount}', style: SoftText.caption(p)),
                    const SizedBox(width: 12),
                    Icon(Icons.chat_bubble_outline_rounded, size: 15, color: p.muted),
                    const SizedBox(width: 4),
                    Text('${item.commentsCount}', style: SoftText.caption(p)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(SoftPalette p, IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: SoftText.caption(p).copyWith(color: p.inkSoft),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
