import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:vidhai/core/bloc/auth_bloc.dart';
import 'package:vidhai/core/bloc/auth_event.dart';
import 'package:vidhai/core/bloc/auth_state.dart';
import 'package:vidhai/data/models/user_profile.dart';
import 'package:vidhai/services/location_service.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/features/assistant/assistant_button.dart';
import 'package:vidhai/features/assistant/assistant_field_registry.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _locationService = LocationService();

  String _selectedGender = '';
  DateTime? _dateOfBirth;
  int _age = 0;
  AddressData? _verifiedAddress;
  List<AddressSearchResult> _locationSuggestions = [];
  bool _isSearchingLocation = false;
  bool _isLoading = false;
  File? _avatarFile;
  String? _domain;

  // Automatic location detection
  bool _isDetectingLocation = false;
  AddressData? _detectedLocation;
  String? _locationError;

  static const _genderValues = ['Male', 'Female', 'Other'];

  bool _assistantFieldsRegistered = false;

  @override
  void initState() {
    super.initState();
    _loadDomain();
    _detectCurrentLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_assistantFieldsRegistered) return;
    _registerAssistantFields();
    _assistantFieldsRegistered = true;
  }

  void _registerAssistantFields() {
    final loc = AppLocalizations.of(context);
    final registry = AssistantFieldRegistry.instance;
    registry.registerField(
        'personal_details',
        AssistantFieldEntry(
          field: 'name',
          label: loc.fullName,
          read: () => _nameController.text.trim(),
          set: (v) {
            _nameController.text = v;
            return true;
          },
        ));
    registry.registerField(
        'personal_details',
        AssistantFieldEntry(
          field: 'gender',
          label: loc.gender,
          suggestions: _genderValues.join(', '),
          read: () => _selectedGender,
          set: (v) {
            for (final g in _genderValues) {
              if (g.toLowerCase() == v.trim().toLowerCase()) {
                _selectedGender = g;
                return true;
              }
            }
            return false;
          },
        ));
    registry.registerField(
        'personal_details',
        AssistantFieldEntry(
          field: 'age',
          label: loc.t('age_years'),
          read: () => _age > 0 ? '$_age' : '',
          set: (v) {
            final ageNum = int.tryParse(v.trim());
            if (ageNum == null || ageNum < 1 || ageNum > 120) return false;
            _age = ageNum;
            _dateOfBirth = DateTime(DateTime.now().year - ageNum, 1, 1);
            return true;
          },
        ));
    registry.registerField(
        'personal_details',
        AssistantFieldEntry(
          field: 'address',
          label: loc.address,
          read: () => _addressController.text.trim(),
          set: (v) {
            _addressController.text = v;
            _searchLocation(v);
            return true;
          },
        ));
    registry.registerAction(
        'personal_details',
        AssistantActionEntry(
          action: 'submit_profile',
          label: loc.t('save_profile'),
          requiresConfirmation: true,
          confirmLabelKey: 'save',
          cancelLabelKey: 'review',
          run: (args) async {
            if (!mounted) return {'error': 'Screen not active.'};
            _submitProfile();
            return {'saved': true};
          },
        ));
  }

  void _unregisterAssistantFields() {
    final registry = AssistantFieldRegistry.instance;
    for (final f in ['name', 'gender', 'age', 'address']) {
      registry.unregisterField('personal_details', f);
    }
    registry.unregisterAction('personal_details', 'submit_profile');
  }

  Future<void> _loadDomain() async {
    final prefs = await SharedPreferences.getInstance();
    final domain = prefs.getString('selected_domain') ?? 'farmer';
    if (mounted) {
      setState(() {
        _domain = domain;
      });
    }
  }

  @override
  void dispose() {
    _unregisterAssistantFields();
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _calculateAge() {
    if (_dateOfBirth == null) {
      setState(() => _age = 0);
      return;
    }
    final now = DateTime.now();
    int calculatedAge = now.year - _dateOfBirth!.year;
    if (now.month < _dateOfBirth!.month ||
        (now.month == _dateOfBirth!.month && now.day < _dateOfBirth!.day)) {
      calculatedAge--;
    }
    setState(() => _age = calculatedAge);
  }

  Future<void> _pickDate() async {
    final loc = AppLocalizations.of(context);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: loc.selectDate,
      cancelText: loc.cancel,
      confirmText: loc.continueBtn,
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
      _calculateAge();
    }
  }

  Future<void> _pickAvatar() async {
    final loc = AppLocalizations.of(context);
    final colors = VidhAIColorsX(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: colors.brandDeep),
                title: Text(loc.takePhoto,
                    style: TextStyle(color: colors.onBackground)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: colors.brandDeep),
                title: Text(loc.chooseFromGallery,
                    style: TextStyle(color: colors.onBackground)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source != null) {
      final picker = ImagePicker();
      final picked =
          await picker.pickImage(source: source, maxWidth: 512, maxHeight: 512);
      if (picked != null) {
        setState(() => _avatarFile = File(picked.path));
      }
    }
  }

  Future<void> _detectCurrentLocation() async {
    setState(() {
      _isDetectingLocation = true;
      _locationError = null;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted) {
            setState(() {
              _isDetectingLocation = false;
              _locationError =
                  AppLocalizations.of(context).locationPermissionNeeded;
            });
          }
          return;
        }
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() {
            _isDetectingLocation = false;
            _locationError =
                AppLocalizations.of(context).locationDetectionFailed;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final placemarks = await _locationService.getPlacemarksFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        final pm = placemarks.first;
        final parts = <String>[
          if (pm.subLocality != null && pm.subLocality!.isNotEmpty)
            pm.subLocality!,
          if (pm.locality != null && pm.locality!.isNotEmpty) pm.locality!,
          if (pm.administrativeArea != null &&
              pm.administrativeArea!.isNotEmpty)
            pm.administrativeArea!,
        ];

        final displayLocation =
            parts.isNotEmpty ? parts.join(', ') : pm.country ?? '';

        final addressParts = <String>[
          if (pm.street != null && pm.street!.isNotEmpty) pm.street!,
          if (pm.subLocality != null && pm.subLocality!.isNotEmpty)
            pm.subLocality!,
          if (pm.locality != null && pm.locality!.isNotEmpty) pm.locality!,
          if (pm.administrativeArea != null &&
              pm.administrativeArea!.isNotEmpty)
            pm.administrativeArea!,
          if (pm.country != null && pm.country!.isNotEmpty) pm.country!,
          if (pm.postalCode != null && pm.postalCode!.isNotEmpty)
            pm.postalCode!,
        ];

        setState(() {
          _detectedLocation = AddressData(
            fullAddress: addressParts.isNotEmpty
                ? addressParts.join(', ')
                : displayLocation,
            latitude: position.latitude,
            longitude: position.longitude,
            city: pm.locality,
            district: pm.subAdministrativeArea,
            state: pm.administrativeArea,
            country: pm.country,
            pincode: pm.postalCode,
            isVerified: true,
          );
          _verifiedAddress = _detectedLocation;
          _addressController.text = _detectedLocation!.fullAddress;
          _isDetectingLocation = false;
        });
      } else if (mounted) {
        setState(() {
          _isDetectingLocation = false;
          _locationError = AppLocalizations.of(context).locationDetectionFailed;
        });
      }
    } on PlatformException {
      if (mounted) {
        setState(() {
          _isDetectingLocation = false;
          _locationError = AppLocalizations.of(context).locationDetectionFailed;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isDetectingLocation = false;
          _locationError = AppLocalizations.of(context).locationDetectionFailed;
        });
      }
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.length < 3) {
      setState(() => _locationSuggestions = []);
      return;
    }
    setState(() => _isSearchingLocation = true);
    final results = await _locationService.searchAddresses(query);
    if (mounted) {
      setState(() {
        _locationSuggestions = results;
        _isSearchingLocation = false;
      });
    }
  }

  void _selectLocation(AddressSearchResult result) {
    _addressController.text = result.displayText;
    _verifiedAddress = result.toAddressData();
    setState(() => _locationSuggestions = []);
  }

  void _submitProfile() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    context.read<AuthBloc>().add(ProfileSaved(
          fullName: _nameController.text.trim(),
          gender: _selectedGender,
          dateOfBirth: _dateOfBirth,
          age: _age,
          address: _verifiedAddress?.toMap(),
          avatarUrl: null,
        ));
  }

  /// Opens the online-only realtime AI Live screen; fills the reviewed
  /// name / age / gender / address suggestions back into the form.
  Future<void> _openAiLive() async {
    final loc = AppLocalizations.of(context);
    final result = await Navigator.of(context).pushNamed(
      '/ai_live',
      arguments: loc.languageCode,
    );
    if (!mounted) return;
    if (result is Map && result.isNotEmpty) {
      _applyAiLiveSuggestions(Map<String, String>.from(result));
    }
  }

  void _applyAiLiveSuggestions(Map<String, String> values) {
    final loc = AppLocalizations.of(context);
    final colors = VidhAIColorsX(context);
    setState(() {
      final name = values['name'];
      if (name != null && name.trim().isNotEmpty) {
        _nameController.text = name.trim();
      }
      final gender = values['gender'];
      if (gender != null && gender.trim().isNotEmpty) {
        for (final g in _genderValues) {
          if (g.toLowerCase() == gender.toLowerCase()) {
            _selectedGender = g;
            break;
          }
        }
      }
      final age = values['age'];
      if (age != null) {
        final ageNum = int.tryParse(age.trim());
        if (ageNum != null && ageNum >= 1 && ageNum <= 120) {
          _age = ageNum;
          _dateOfBirth = DateTime(DateTime.now().year - ageNum, 1, 1);
        }
      }
      final address = values['address'];
      if (address != null && address.trim().isNotEmpty) {
        _addressController.text = address.trim();
        _verifiedAddress = AddressData(
          fullAddress: address.trim(),
          isVerified: true,
        );
        _locationSuggestions = [];
      }
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(loc.aiLiveApplied),
        backgroundColor: colors.success,
        duration: const Duration(seconds: 2),
      ));
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
    String? hintText,
  }) {
    final colors = VidhAIColorsX(context);
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      hintStyle: TextStyle(color: colors.onSurfaceMuted.withValues(alpha: 0.6)),
      labelStyle: TextStyle(color: colors.onSurfaceMuted),
      prefixIcon: Icon(icon, color: colors.onSurfaceMuted, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.brandDeep, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.danger, width: 1.5),
      ),
      errorStyle: TextStyle(color: colors.danger, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  void _goBack() {
    Navigator.of(context).pushReplacementNamed('/domain_selection');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = VidhAIColorsX(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: colors.bg,
        appBar: AppBar(
          backgroundColor: colors.bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(directionalIcon(context, Icons.arrow_back_ios),
                color: colors.onBackground, size: 20),
            onPressed: _goBack,
          ),
          title: Text(
            loc.personalDetails,
            style: TextStyle(
                color: colors.onBackground, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          actions: [
            const VidhAIAssistantButton(
                screen: 'personal_details', size: 36, iconSize: 18),
            const SizedBox(width: 12),
          ],
        ),
        body: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthProfileSaved) {
              setState(() => _isLoading = false);
              if (state.domain == 'farmer') {
                Navigator.of(context).pushReplacementNamed('/farmer_details');
              } else {
                Navigator.of(context).pushReplacementNamed('/main_shell');
              }
            } else if (state is AuthErrorState) {
              setState(() => _isLoading = false);
              final loc = AppLocalizations.of(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(state.errorMessage ?? loc.errorFallback),
                backgroundColor: colors.danger,
              ));
            }
          },
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // -- Header subtitle --
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    loc.pdSubtitle,
                    style: TextStyle(
                      color: colors.onSurfaceMuted,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // -- AI Live (realtime speech-to-form) --
                _buildAiLiveCard(loc, colors),
                const SizedBox(height: 20),

                // -- Avatar --
                _buildAvatarSection(loc),
                const SizedBox(height: 28),

                // -- Name --
                _buildNameField(loc),
                const SizedBox(height: 14),

                // -- Gender --
                _buildGenderField(loc),
                const SizedBox(height: 14),

                // -- DOB --
                _buildDOBField(loc),
                const SizedBox(height: 14),

                // -- Age (calculated) --
                _buildAgeField(loc),
                const SizedBox(height: 14),

                // -- Address --
                _buildAddressField(loc),
                const SizedBox(height: 20),

                // -- Current Location Card --
                _buildCurrentLocationCard(loc, colors),
                const SizedBox(height: 24),

                // -- Continue Button --
                _buildSubmitButton(loc),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiLiveCard(AppLocalizations loc, VidhAIColorsX colors) {
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openAiLive,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.brandDeep.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(Icons.mic_rounded, color: colors.brandDeep, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.aiLiveButton,
                      style: TextStyle(
                        color: colors.onBackground,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loc.aiLiveDescription,
                      style:
                          TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(
                directionalIcon(context, Icons.arrow_forward_ios),
                color: colors.onSurfaceMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(AppLocalizations loc) {
    final colors = VidhAIColorsX(context);
    return Center(
      child: GestureDetector(
        onTap: _pickAvatar,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surface,
                    border: Border.all(color: colors.borderColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: colors.brandDeep.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _avatarFile != null
                        ? Image.file(
                            _avatarFile!,
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                          )
                        : Center(
                            child: Icon(
                              _domain == 'farmer'
                                  ? Icons.agriculture_rounded
                                  : Icons.shopping_cart_rounded,
                              size: 46,
                              color: _domain == 'farmer'
                                  ? colors.brandDeep
                                  : colors.warning,
                            ),
                          ),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: colors.brandDeep,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surface, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              loc.t('tap_to_change_photo'),
              style: TextStyle(
                color: colors.onSurfaceMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField(AppLocalizations loc) {
    final colors = VidhAIColorsX(context);
    return TextFormField(
      controller: _nameController,
      style: TextStyle(color: colors.onBackground, fontSize: 15),
      textCapitalization: TextCapitalization.words,
      decoration: _inputDecoration(
        label: loc.fullName,
        icon: Icons.person_outline_rounded,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return loc.requiredField;
        if (v.trim().length < 2) return loc.requiredField;
        return null;
      },
    );
  }

  Widget _buildGenderField(AppLocalizations loc) {
    final colors = VidhAIColorsX(context);
    return DropdownButtonFormField<String>(
      initialValue: _selectedGender.isEmpty ? null : _selectedGender,
      style: TextStyle(color: colors.onBackground, fontSize: 15),
      dropdownColor: colors.surface,
      decoration: _inputDecoration(
        label: loc.gender,
        icon: Icons.wc_outlined,
      ),
      items: _genderValues
          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
          .toList(),
      onChanged: (v) => setState(() => _selectedGender = v ?? ''),
      validator: (v) => v == null || v.isEmpty ? loc.requiredField : null,
    );
  }

  Widget _buildDOBField(AppLocalizations loc) {
    final colors = VidhAIColorsX(context);
    final displayText = _dateOfBirth != null
        ? DateFormat('dd MMMM yyyy').format(_dateOfBirth!)
        : '';

    return GestureDetector(
      onTap: _pickDate,
      child: AbsorbPointer(
        child: TextFormField(
          controller: TextEditingController(text: displayText),
          style: TextStyle(color: colors.onBackground, fontSize: 15),
          decoration: _inputDecoration(
            label: loc.dateOfBirth,
            icon: Icons.cake_outlined,
            suffixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child:
                  Icon(Icons.calendar_today, color: colors.brandDeep, size: 18),
            ),
          ),
          validator: (v) => _dateOfBirth == null ? loc.requiredField : null,
        ),
      ),
    );
  }

  Widget _buildAgeField(AppLocalizations loc) {
    final colors = VidhAIColorsX(context);
    return TextFormField(
      controller: TextEditingController(text: _age > 0 ? '$_age' : ''),
      readOnly: true,
      style: TextStyle(
        color: _age > 0 ? colors.onBackground : colors.onSurfaceMuted,
        fontSize: 15,
      ),
      decoration: _inputDecoration(
        label: loc.ageCalculated,
        icon: Icons.numbers_rounded,
      ),
    );
  }

  Widget _buildAddressField(AppLocalizations loc) {
    final colors = VidhAIColorsX(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _addressController,
          style: TextStyle(color: colors.onBackground, fontSize: 15),
          onChanged: _searchLocation,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return loc.requiredField;
            if (_verifiedAddress == null || !_verifiedAddress!.isVerified) {
              return loc.selectFromSuggestions;
            }
            return null;
          },
          decoration: _inputDecoration(
            label: loc.searchAddress,
            icon: Icons.location_on_outlined,
            suffixIcon: _isSearchingLocation
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.brandDeep,
                      ),
                    ),
                  )
                : _verifiedAddress != null && _verifiedAddress!.isVerified
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(end: 12),
                        child: Icon(Icons.verified,
                            color: colors.brandDeep, size: 20),
                      )
                    : null,
          ),
        ),
        if (_locationSuggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.borderColor),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _locationSuggestions.length,
              itemBuilder: (context, i) {
                final s = _locationSuggestions[i];
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.location_on_outlined,
                      color: colors.brandDeep, size: 20),
                  title: Text(s.displayText,
                      style:
                          TextStyle(color: colors.onBackground, fontSize: 13)),
                  onTap: () => _selectLocation(s),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCurrentLocationCard(AppLocalizations loc, VidhAIColorsX colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderColor),
        boxShadow: [
          BoxShadow(
            color: colors.brandDeep.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.brandDeep.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(Icons.my_location, color: colors.brandDeep, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                loc.currentLocation,
                style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isDetectingLocation) ...[
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.brandDeep,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    loc.detectingLocation,
                    style: TextStyle(
                      color: colors.onSurfaceMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (_detectedLocation != null) ...[
            Row(
              children: [
                const Text('📍', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _buildLocationDisplayString(),
                    style: TextStyle(
                      color: colors.onBackground,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (_locationError != null) ...[
            Row(
              children: [
                Icon(Icons.error_outline,
                    color: colors.danger.withValues(alpha: 0.8), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _locationError!,
                    style: TextStyle(
                      color: colors.onSurfaceMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _detectCurrentLocation,
                icon: Icon(Icons.refresh, color: colors.brandDeep, size: 16),
                label: Text(
                  loc.retryLocation,
                  style: TextStyle(color: colors.brandDeep, fontSize: 13),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Icon(Icons.location_off_outlined,
                    color: colors.onSurfaceMuted, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc.locationDetectionFailed,
                    style: TextStyle(
                      color: colors.onSurfaceMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _detectCurrentLocation,
                icon: Icon(Icons.refresh, color: colors.brandDeep, size: 16),
                label: Text(
                  loc.retryLocation,
                  style: TextStyle(color: colors.brandDeep, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _buildLocationDisplayString() {
    if (_detectedLocation == null) return '';
    final parts = <String>[
      if (_detectedLocation!.city != null &&
          _detectedLocation!.city!.isNotEmpty)
        _detectedLocation!.city!,
      if (_detectedLocation!.state != null &&
          _detectedLocation!.state!.isNotEmpty)
        _detectedLocation!.state!,
    ];
    return parts.isNotEmpty ? parts.join(', ') : _detectedLocation!.fullAddress;
  }

  Widget _buildSubmitButton(AppLocalizations loc) {
    final colors = VidhAIColorsX(context);
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.brandDeep,
          foregroundColor: Colors.white,
          disabledBackgroundColor: colors.brandDeep.withValues(alpha: 0.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Text(
                loc.continueBtn,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
