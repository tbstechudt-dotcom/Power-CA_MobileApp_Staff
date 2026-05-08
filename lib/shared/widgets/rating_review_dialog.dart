import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/theme_provider.dart';

/// Bottom sheet dialog for collecting app ratings and reviews.
/// Shows 5 interactive stars + mandatory text review.
/// Returns true if submitted, false/null if skipped.
class RatingReviewBottomSheet extends StatefulWidget {
  final int staffId;

  const RatingReviewBottomSheet({
    super.key,
    required this.staffId,
  });

  /// Show the rating bottom sheet. Returns true if review was submitted.
  static Future<bool?> show(BuildContext context, {required int staffId}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => RatingReviewBottomSheet(staffId: staffId),
    );
  }

  @override
  State<RatingReviewBottomSheet> createState() =>
      _RatingReviewBottomSheetState();
}

class _RatingReviewBottomSheetState extends State<RatingReviewBottomSheet> {
  int _rating = 0;
  final _reviewController = TextEditingController();
  bool _isSubmitting = false;

  bool get _canSubmit =>
      _rating > 0 && _reviewController.text.trim().isNotEmpty && !_isSubmitting;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_rating == 0 || _reviewController.text.trim().isEmpty) return;
    setState(() => _isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('app_reviews').upsert({
        'staff_id': widget.staffId,
        'rating': _rating,
        'review_text': _reviewController.text.trim(),
      }, onConflict: 'staff_id');
    } catch (e) {
      debugPrint('Error submitting review to Supabase: $e');
    }

    // Mark as reviewed locally regardless of Supabase result
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        '${StorageConstants.keyHasReviewed}${widget.staffId}',
        true,
      );
    } catch (e) {
      debugPrint('Error saving review status: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Thank you for submitting your Reviews'),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  void _skipReview() {
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final sheetBg = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final handleColor =
        isDarkMode ? const Color(0xFF475569) : const Color(0xFFE5E7EB);
    final titleColor =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);
    final subtitleColor =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final fieldBg =
        isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB);
    final fieldBorder =
        isDarkMode ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
    final hintColor =
        isDarkMode ? const Color(0xFF64748B) : const Color(0xFF9CA3AF);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 24.h),

                // Star icon
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.star_rounded,
                      size: 28.sp,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),

                // Title
                Text(
                  'Rate Your Experience',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                SizedBox(height: 8.h),

                // Subtitle
                Text(
                  'How would you rate the PowerCA app?',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    color: subtitleColor,
                  ),
                ),
                SizedBox(height: 24.h),

                // Star rating row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    final isSelected = starIndex <= _rating;
                    return GestureDetector(
                      onTap: () => setState(() => _rating = starIndex),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.w),
                        child: Icon(
                          isSelected
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 40.sp,
                          color: isSelected
                              ? const Color(0xFFFFC107)
                              : (isDarkMode
                                  ? const Color(0xFF475569)
                                  : const Color(0xFFD1D5DB)),
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: 8.h),

                // Rating label
                Text(
                  _rating == 0
                      ? 'Tap a star to rate'
                      : _rating <= 2
                          ? 'We\'ll do better!'
                          : _rating == 3
                              ? 'It\'s okay'
                              : _rating == 4
                                  ? 'We like it!'
                                  : 'Excellent!',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: _rating == 0 ? hintColor : const Color(0xFFF59E0B),
                  ),
                ),
                SizedBox(height: 20.h),

                // Review text field
                TextField(
                  controller: _reviewController,
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.sp,
                    color: titleColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Share your feedback (required)',
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.sp,
                      color: hintColor,
                    ),
                    filled: true,
                    fillColor: fieldBg,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(color: fieldBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(color: fieldBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                    ),
                  ),
                ),
                SizedBox(height: 24.h),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _canSubmit ? _submitReview : null,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      backgroundColor: _canSubmit
                          ? const Color(0xFF3B82F6)
                          : (isDarkMode
                              ? const Color(0xFF334155)
                              : const Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Submit Review',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: _canSubmit
                                  ? Colors.white
                                  : (isDarkMode
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF9CA3AF)),
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 12.h),

                // Skip button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _isSubmitting ? null : _skipReview,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    child: Text(
                      'Maybe Later',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
