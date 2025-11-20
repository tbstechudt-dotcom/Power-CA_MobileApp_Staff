import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../shared/widgets/modern_bottom_navigation.dart';
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

class PinboardPage extends StatelessWidget {
  final Staff currentStaff;

  const PinboardPage({
    super.key,
    required this.currentStaff,
  });

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // Modern Top App Bar
              _buildModernAppBar(context),

              // Pinboard Main Content
              Expanded(
                child: PinboardMainPage(currentStaff: currentStaff),
              ),
            ],
          ),
        ),
        bottomNavigationBar: ModernBottomNavigation(
          currentIndex: 3,
          currentStaff: currentStaff,
        ),
      ),
    );
  }

  Widget _buildModernAppBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Avatar
          Container(
            width: 44.w,
            height: 44.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF0846B1), Color(0xFF2255FC)],
              ),
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0846B1).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                currentStaff.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          // Name and role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentStaff.name.split(' ').first,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF080E29),
                  ),
                ),
                Text(
                  'Staff Member',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF8F8E90),
                  ),
                ),
              ],
            ),
          ),
          // Notifications
          Container(
            width: 40.w,
            height: 40.h,
            decoration: const BoxDecoration(
              color: Color(0xFFF5F7FA),
              shape: BoxShape.circle,
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.notifications_outlined,
                    size: 20.sp,
                    color: const Color(0xFF080E29),
                  ),
                ),
                Positioned(
                  right: 10.w,
                  top: 10.h,
                  child: Container(
                    width: 8.w,
                    height: 8.h,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF1E05),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
