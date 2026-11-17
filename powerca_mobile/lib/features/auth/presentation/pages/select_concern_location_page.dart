import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/priority_service.dart';
import '../../../../shared/widgets/auth_sheet.dart';
import '../../../../shared/widgets/soft_page.dart';
import '../../../../shared/widgets/soft_ui.dart';
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
    final p = SoftPalette.of(context);
    return AuthSheet(
      title: 'Choose your workspace',
      subtitle: "Select the concern and location you're working from.",
      subtitleExtra: Text('Signed in as ${widget.currentStaff.name}'),
      icon: Icons.domain_rounded,
      children: [
        // Error Message
        if (_errorMessage != null) ...[
          _buildErrorCard(p),
          const SizedBox(height: 16),
        ],

        // Concern Selection
        _buildSectionLabel('Concern'),
        _buildConcernDropdown(p),

        const SizedBox(height: 16),

        // Location Selection
        _buildSectionLabel('Location'),
        _buildLocationDropdown(p),

        const SizedBox(height: 24),

        // Submit Button
        _buildSubmitButton(),
      ],
    );
  }

  Widget _buildErrorCard(SoftPalette p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: p.tint(p.danger),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: p.danger, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: SoftText.body(p, size: 13, color: p.danger),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: p.danger,
            onPressed: _loadConcerns,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return SoftFieldLabel(label);
  }

  Widget _buildConcernDropdown(SoftPalette p) {
    if (_isLoadingConcerns) {
      return _buildLoadingContainer(p);
    }

    if (_concerns.isEmpty && !_isLoadingConcerns) {
      return _buildEmptyContainer(p, 'No concerns found');
    }

    return DropdownButtonFormField<Map<String, dynamic>>(
      value: _selectedConcern,
      decoration: softInputDecoration(
        context,
        hint: 'Select a concern',
        icon: Icons.apartment_outlined,
      ),
      dropdownColor: p.surface,
      borderRadius: BorderRadius.circular(16),
      icon: Icon(Icons.expand_more_rounded, color: p.muted, size: 22),
      isExpanded: true,
      items: _concerns.map((concern) {
        return DropdownMenuItem<Map<String, dynamic>>(
          value: concern,
          child: Text(
            concern['orgname']?.toString() ?? 'Unknown',
            overflow: TextOverflow.ellipsis,
            style: softInputTextStyle(context),
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
    );
  }

  Widget _buildLocationDropdown(SoftPalette p) {
    if (_isLoadingLocations) {
      return _buildLoadingContainer(p);
    }

    if (_selectedConcern == null) {
      return _buildDisabledContainer(p, 'Select a concern first');
    }

    if (_locations.isEmpty && !_isLoadingLocations) {
      return _buildEmptyContainer(p, 'No locations found for this concern');
    }

    return DropdownButtonFormField<Map<String, dynamic>>(
      value: _selectedLocation,
      decoration: softInputDecoration(
        context,
        hint: 'Select a location',
        icon: Icons.location_on_outlined,
      ),
      dropdownColor: p.surface,
      borderRadius: BorderRadius.circular(16),
      icon: Icon(Icons.expand_more_rounded, color: p.muted, size: 22),
      isExpanded: true,
      items: _locations.map((location) {
        return DropdownMenuItem<Map<String, dynamic>>(
          value: location,
          child: Text(
            location['locname']?.toString() ?? 'Unknown',
            overflow: TextOverflow.ellipsis,
            style: softInputTextStyle(context),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedLocation = value;
        });
      },
    );
  }

  Widget _buildLoadingContainer(SoftPalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: p.ink),
        ),
      ),
    );
  }

  Widget _buildEmptyContainer(SoftPalette p, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
      decoration: BoxDecoration(
        color: p.tint(p.warning),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: p.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: SoftText.body(p, color: p.ink)),
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledContainer(SoftPalette p, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_rounded, color: p.muted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: SoftText.body(p, color: p.muted)),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final bool isEnabled =
        _selectedConcern != null && _selectedLocation != null && !_isSubmitting;

    return SoftPillButton(
      label: 'Continue',
      loading: _isSubmitting,
      onPressed: isEnabled ? _submitSelection : null,
    );
  }
}
