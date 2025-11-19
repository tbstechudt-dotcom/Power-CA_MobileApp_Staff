import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/pinboard_item.dart';
import '../bloc/pinboard_bloc.dart';
import '../bloc/pinboard_event.dart';
import '../bloc/pinboard_state.dart';
import 'pinboard_detail_page.dart';

class PinboardMainPage extends StatefulWidget {
  const PinboardMainPage({super.key});

  @override
  State<PinboardMainPage> createState() => _PinboardMainPageState();
}

class _PinboardMainPageState extends State<PinboardMainPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load initial data for first tab
    context.read<PinboardBloc>().add(
          const LoadPinboardItems(category: PinboardCategory.dueDate),
        );

    // Listen to tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadDataForTab(_tabController.index);
      }
    });
  }

  void _loadDataForTab(int index) {
    PinboardCategory category;
    switch (index) {
      case 0:
        category = PinboardCategory.dueDate;
        break;
      case 1:
        category = PinboardCategory.meetings;
        break;
      case 2:
        category = PinboardCategory.greetings;
        break;
      default:
        category = PinboardCategory.dueDate;
    }
    context.read<PinboardBloc>().add(LoadPinboardItems(category: category));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getCategoryColor(PinboardCategory category) {
    switch (category) {
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
    return Column(
      children: [
        // Tab Bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorWeight: 3,
            tabs: [
              Tab(
                icon: Icon(Icons.calendar_today, size: 20),
                text: 'Due Date',
              ),
              Tab(
                icon: Icon(Icons.people, size: 20),
                text: 'Meetings',
              ),
              Tab(
                icon: Icon(Icons.celebration, size: 20),
                text: 'Greetings',
              ),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _PinboardListView(category: PinboardCategory.dueDate),
              _PinboardListView(category: PinboardCategory.meetings),
              _PinboardListView(category: PinboardCategory.greetings),
            ],
          ),
        ),
      ],
    );
  }
}

class _PinboardListView extends StatelessWidget {
  final PinboardCategory category;

  const _PinboardListView({required this.category});

  Color _getCategoryColor() {
    switch (category) {
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
    return BlocBuilder<PinboardBloc, PinboardState>(
      builder: (context, state) {
        if (state is PinboardLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is PinboardError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  state.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    context.read<PinboardBloc>().add(
                          LoadPinboardItems(category: category),
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
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No items yet',
                    style: TextStyle(
                      fontSize: 16,
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
                    RefreshPinboardItems(category: category),
                  );
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = state.items[index];
                return _PinboardCard(
                  item: item,
                  categoryColor: _getCategoryColor(),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BlocProvider.value(
                          value: context.read<PinboardBloc>(),
                          child: PinboardDetailPage(itemId: item.id),
                        ),
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
    );
  }
}

class _PinboardCard extends StatelessWidget {
  final PinboardItem item;
  final Color categoryColor;
  final VoidCallback onTap;

  const _PinboardCard({
    required this.item,
    required this.categoryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image (if available)
            if (item.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: Image.network(
                  item.imageUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 180,
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 64,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Description
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 12),

                  // Event Date and Location
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: categoryColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${dateFormat.format(item.eventDate)} at ${timeFormat.format(item.eventDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (item.location != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: categoryColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.location!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),
                  const Divider(height: 1),
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
                              backgroundColor: categoryColor.withValues(alpha: 0.2),
                              child: Icon(
                                Icons.person,
                                size: 14,
                                color: categoryColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.authorName,
                                style: const TextStyle(
                                  fontSize: 12,
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
                            size: 16,
                            color: item.isLikedByCurrentUser
                                ? Colors.red
                                : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${item.likesCount}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.comment_outlined,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${item.commentsCount}',
                            style: const TextStyle(fontSize: 12),
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
