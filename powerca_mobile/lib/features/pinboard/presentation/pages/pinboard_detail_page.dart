import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/pinboard_bloc.dart';
import '../bloc/pinboard_event.dart';
import '../bloc/pinboard_state.dart';
import '../widgets/event_details_tab.dart';
import '../widgets/comments_tab.dart';

class PinboardDetailPage extends StatefulWidget {
  final String itemId;

  const PinboardDetailPage({
    super.key,
    required this.itemId,
  });

  @override
  State<PinboardDetailPage> createState() => _PinboardDetailPageState();
}

class _PinboardDetailPageState extends State<PinboardDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<PinboardBloc>().add(
          LoadPinboardItemDetails(widget.itemId),
        );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<PinboardBloc, PinboardState>(
        listener: (context, state) {
          if (state is LikeToggled) {
            // Optionally show a snackbar
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Like toggled'),
                duration: Duration(seconds: 1),
              ),
            );
          }

          if (state is CommentAdded) {
            // Optionally show a snackbar
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Comment added'),
                duration: Duration(seconds: 1),
              ),
            );
          }
        },
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
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
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
                            LoadPinboardItemDetails(widget.itemId),
                          );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is PinboardItemDetailsLoaded) {
            final item = state.item;

            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: item.imageUrl != null ? 250 : 0,
                    floating: false,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      background: item.imageUrl != null
                          ? Image.network(
                              item.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            )
                          : null,
                    ),
                  ),
                ];
              },
              body: Column(
                children: [
                  // Tabs
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Theme.of(context).primaryColor,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Theme.of(context).primaryColor,
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.event),
                          text: 'Event',
                        ),
                        Tab(
                          icon: Icon(Icons.comment),
                          text: 'Comments',
                        ),
                      ],
                    ),
                  ),

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        EventDetailsTab(item: item),
                        CommentsTab(
                          pinboardItemId: item.id,
                          comments: state.comments,
                          isLoading: state.isLoadingComments,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
