import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../core/services/priority_service.dart';
import '../../domain/entities/staff.dart';

/// Select Concern & Location Page
/// Shown after sign-in to allow staff to select their working concern and location
class SelectConcernLocationPage extends StatefulWidget {
  final Staff currentStaff;

  const SelectConcernLocationPage({
    super.key,
    required this.currentStaff,
  });

  @override
  State<SelectConcernLocationPage> createState() =>
      _SelectConcernLocationPageState();
}

class _SelectConcernLocationPageState extends State<SelectConcernLocationPage> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _concerns = [];
  List<Map<String, dynamic>> _locations = [];

  Map<String, dynamic>? _selectedConcern;
  Map<String, dynamic>? _selectedLocation;

  bool _isLoadingConcerns = true;
  bool _isLoadingLocations = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConcerns();
  }

  /// Load concerns (organizations) from database
  Future<void> _loadConcerns() async {
    setState(() {
      _isLoadingConcerns = true;
      _errorMessage = null;
    });

    try {
      debugPrint('Loading concerns from orgmaster...');

      // Fetch organizations (column is orgname, not org_name)
      final response = await _supabase
          .from('orgmaster')
          .select('org_id, orgname')
          .order('orgname');

      debugPrint('Concerns response: $response');
      debugPrint('Concerns count: ${response.length}');

      if (!mounted) return;

      setState(() {
        _concerns = List<Map<String, dynamic>>.from(response);
        _isLoadingConcerns = false;

        // If staff has a default org_id, pre-select it
        if (widget.currentStaff.orgId > 0 && _concerns.isNotEmpty) {
          final defaultConcern = _concerns.firstWhere(
            (c) => c['org_id'] == widget.currentStaff.orgId,
            orElse: () => <String, dynamic>{},
          );
          if (defaultConcern.isNotEmpty) {
            _selectedConcern = defaultConcern;
            _loadLocations(widget.currentStaff.orgId);
          }
        }
      });
    } catch (e, stack) {
      debugPrint('Error loading concerns: $e');
      debugPrint('Stack: $stack');

      if (!mounted) return;

      setState(() {
        _isLoadingConcerns = false;
        _errorMessage = 'Failed to load concerns: ${e.toString()}';
      });
    }
  }

  /// Load locations for selected concern
  Future<void> _loadLocations(int orgId) async {
    setState(() {
      _isLoadingLocations = true;
      _locations = [];
      _selectedLocation = null;
    });

    try {
      debugPrint('Loading locations for org_id: $orgId');

      // Fetch locations for the selected organization (column is locname, not loc_name)
      final response = await _supabase
          .from('locmaster')
          .select('loc_id, locname, org_id')
          .eq('org_id', orgId)
          .order('locname');

      debugPrint('Locations response: $response');
      debugPrint('Locations count: ${response.length}');

      if (!mounted) return;

      setState(() {
        _locations = List<Map<String, dynamic>>.from(response);
        _isLoadingLocations = false;

        // If staff has a default loc_id, pre-select it
        if (widget.currentStaff.locId > 0 && _locations.isNotEmpty) {
          final defaultLocation = _locations.firstWhere(
            (l) => l['loc_id'] == widget.currentStaff.locId,
            orElse: () => <String, dynamic>{},
          );
          if (defaultLocation.isNotEmpty) {
            _selectedLocation = defaultLocation;
          }
        }
      });
    } catch (e, stack) {
      debugPrint('Error loading locations: $e');
      debugPrint('Stack: $stack');

      if (!mounted) return;

      setState(() {
        _isLoadingLocations = false;
      });
      _showError('Failed to load locations: ${e.toString()}');
    }
  }

  /// Submit selection and navigate to dashboard
  Future<void> _submitSelection() async {
    if (_selectedConcern == null) {
      _showError('Please select a concern');
      return;
    }
    if (_selectedLocation == null) {
      _showError('Please select a location');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Create updated staff with selected org and location
      final updatedStaff = Staff(
        staffId: widget.currentStaff.staffId,
        name: widget.currentStaff.name,
        username: widget.currentStaff.username,
        orgId: _selectedConcern!['org_id'],
        locId: _selectedLocation!['loc_id'],
        conId: widget.currentStaff.conId,
        email: widget.currentStaff.email,
        phoneNumber: widget.currentStaff.phoneNumber,
        dateOfBirth: widget.currentStaff.dateOfBirth,
        staffType: widget.currentStaff.staffType,
        isActive: widget.currentStaff.isActive,
      );

      // Set staff ID in PriorityService
      await PriorityService.setCurrentStaffId(updatedStaff.staffId);

      if (!mounted) return;

      // Navigate to dashboard with updated staff
      Navigator.pushReplacementNamed(
        context,
        '/dashboard',
        arguments: updatedStaff,
      );
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      _showError('Failed to proceed: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Select Concern & Location',
          style: GoogleFonts.inter(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              _buildWelcomeCard(),

              SizedBox(height: 24.h),

              // Error Message
              if (_errorMessage != null) ...[
                _buildErrorCard(),
                SizedBox(height: 16.h),
              ],

              // Concern Selection
              _buildSectionLabel('Select Concern'),
              SizedBox(height: 8.h),
              _buildConcernDropdown(),

              SizedBox(height: 24.h),

              // Location Selection
              _buildSectionLabel('Select Location'),
              SizedBox(height: 8.h),
              _buildLocationDropdown(),

              SizedBox(height: 40.h),

              // Submit Button
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 28.sp,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome!',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      widget.currentStaff.name,
                      style: GoogleFonts.inter(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            'Please select your concern and location to continue.',
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 24.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                color: Colors.red.shade700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Colors.red,
            onPressed: _loadConcerns,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF080E29),
      ),
    );
  }

  Widget _buildConcernDropdown() {
    if (_isLoadingConcerns) {
      return _buildLoadingContainer();
    }

    if (_concerns.isEmpty && !_isLoadingConcerns) {
      return _buildEmptyContainer('No concerns found');
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<Map<String, dynamic>>(
        value: _selectedConcern,
        decoration: InputDecoration(
          hintText: 'Select a concern',
          hintStyle: GoogleFonts.inter(
            fontSize: 14.sp,
            color: const Color(0xFF94A3B8),
          ),
          prefixIcon: Icon(
            Icons.business_rounded,
            color: AppTheme.primaryColor,
            size: 22.sp,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        ),
        dropdownColor: Colors.white,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: const Color(0xFF64748B),
          size: 24.sp,
        ),
        isExpanded: true,
        items: _concerns.map((concern) {
          return DropdownMenuItem<Map<String, dynamic>>(
            value: concern,
            child: Text(
              concern['orgname']?.toString() ?? 'Unknown',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedConcern = value;
            _selectedLocation = null;
            _locations = [];
          });
          if (value != null) {
            _loadLocations(value['org_id']);
          }
        },
      ),
    );
  }

  Widget _buildLocationDropdown() {
    if (_isLoadingLocations) {
      return _buildLoadingContainer();
    }

    if (_selectedConcern == null) {
      return _buildDisabledContainer('Select a concern first');
    }

    if (_locations.isEmpty && !_isLoadingLocations) {
      return _buildEmptyContainer('No locations found for this concern');
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<Map<String, dynamic>>(
        value: _selectedLocation,
        decoration: InputDecoration(
          hintText: 'Select a location',
          hintStyle: GoogleFonts.inter(
            fontSize: 14.sp,
            color: const Color(0xFF94A3B8),
          ),
          prefixIcon: Icon(
            Icons.location_on_rounded,
            color: AppTheme.primaryColor,
            size: 22.sp,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        ),
        dropdownColor: Colors.white,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: const Color(0xFF64748B),
          size: 24.sp,
        ),
        isExpanded: true,
        items: _locations.map((location) {
          return DropdownMenuItem<Map<String, dynamic>>(
            value: location,
            child: Text(
              location['locname']?.toString() ?? 'Unknown',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedLocation = value;
          });
        },
      ),
    );
  }

  Widget _buildLoadingContainer() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: SizedBox(
          width: 24.w,
          height: 24.h,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyContainer(String message) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22.sp),
          SizedBox(width: 12.w),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledContainer(String message) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_rounded, color: const Color(0xFF94A3B8), size: 22.sp),
          SizedBox(width: 12.w),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final bool isEnabled =
        _selectedConcern != null && _selectedLocation != null && !_isSubmitting;

    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: ElevatedButton(
        onPressed: isEnabled ? _submitSelection : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          disabledBackgroundColor: const Color(0xFFCBD5E1),
          elevation: isEnabled ? 2 : 0,
          shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSubmitting
            ? SizedBox(
                width: 24.w,
                height: 24.h,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue',
                    style: GoogleFonts.inter(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 20.sp,
                    color: Colors.white,
                  ),
                ],
              ),
      ),
    );
  }

}
