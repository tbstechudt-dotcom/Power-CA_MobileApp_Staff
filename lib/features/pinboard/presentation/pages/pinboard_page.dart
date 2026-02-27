import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/theme_provider.dart';
import '../../../../shared/widgets/modern_bottom_navigation.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../auth/domain/entities/staff.dart';
import '../../data/datasources/pinboard_remote_datasource.dart';
import '../../data/repositories/pinboard_repository_impl.dart';
import '../../domain/usecases/add_comment_usecase.dart';
import '../../domain/usecases/get_comments_usecase.dart';
import '../../domain/usecases/get_pinboard_item_by_id_usecase.dart';
import '../../domain/usecases/get_pinboard_items_usecase.dart';
import '../../domain/usecases/toggle_like_usecase.dart';
import '../bloc/pinboard_bloc.dart';
import 'pinboard_main_page.dart';

/// Key for storing last pinboard visit timestamp (shared with app_header.dart)
const String _kLastPinboardVisitKey = 'last_pinboard_visit_timestamp';

class PinboardPage extends StatefulWidget {
  final Staff currentStaff;

  const PinboardPage({
    super.key,
    required this.currentStaff,
  });

  @override
  State<PinboardPage> createState() => _PinboardPageState();
}

class _PinboardPageState extends State<PinboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // Mark pinboard as visited when this page opens
    _markPinboardAsVisited();
  }

  /// Update status bar style based on theme
  void _updateStatusBarStyle(bool isDarkMode) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
      ),
    );
  }

  /// Save current timestamp as last pinboard visit
  Future<void> _markPinboardAsVisited() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kLastPinboardVisitKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('Error saving pinboard visit timestamp: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final scaffoldBgColor = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8F9FC);
    final headerBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    // Update status bar style based on theme
    _updateStatusBarStyle(isDarkMode);

    // Get Supabase client
    final supabaseClient = Supabase.instance.client;

    // Create data source
    final dataSource = PinboardRemoteDataSourceImpl(
      supabaseClient: supabaseClient,
    );

    // Create repository
    final repository = PinboardRepositoryImpl(
      remoteDataSource: dataSource,
      supabaseClient: supabaseClient,
    );

    // Create use cases
    final getPinboardItems = GetPinboardItemsUseCase(repository);
    final getPinboardItemById = GetPinboardItemByIdUseCase(repository);
    final getComments = GetCommentsUseCase(repository);
    final addComment = AddCommentUseCase(repository);
    final toggleLike = ToggleLikeUseCase(repository);

    return BlocProvider(
      create: (context) => PinboardBloc(
        getPinboardItems: getPinboardItems,
        getPinboardItemById: getPinboardItemById,
        getComments: getComments,
        addComment: addComment,
        toggleLike: toggleLike,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: scaffoldBgColor,
        drawer: AppDrawer(currentStaff: widget.currentStaff),
        body: Column(
          children: [
            // Status bar area
            Container(
              color: headerBgColor,
              child: SafeArea(
                bottom: false,
                child: AppHeader(
                  currentStaff: widget.currentStaff,
                  onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              ),
            ),

            // Pinboard Main Content
            Expanded(
              child: PinboardMainPage(currentStaff: widget.currentStaff),
            ),
          ],
        ),
        bottomNavigationBar: ModernBottomNavigation(
          currentIndex: 3,
          currentStaff: widget.currentStaff,
        ),
      ),
    );
  }
}
