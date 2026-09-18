import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/core/bloc/auth_bloc.dart';
import 'package:vidhai/core/bloc/auth_event.dart';
import 'package:vidhai/core/bloc/auth_state.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/core/widgets/profile_avatar.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';
import 'package:vidhai/data/india_location_catalog.dart';
import 'package:vidhai/data/models/user_profile.dart';
import 'package:vidhai/features/assistant/assistant_button.dart';
import 'package:vidhai/features/assistant/assistant_field_registry.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/services/location_service.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _stateController = TextEditingController();
  final _districtController = TextEditingController();
  final _locationService = LocationService();

  String _selectedGender = '';
  DateTime? _dateOfBirth;
  int _age = 0;
  AddressData? _verifiedAddress;

  String? _selectedState;
  String? _selectedDistrict;
  List<String> _districtOptions = const [];
  List<String> _stateSuggestions = const [];
  List<String> _districtSuggestions = const [];
  List<AddressSearchResult> _addressSuggestions = const [];

  bool _loadingDistricts = false;
  bool _searchingAddress = false;
  bool _gettingLocation = false;
  bool _isLoading = false;
  String? _locationError;

  late String _selectedAvatar;
  bool _assistantFieldsRegistered = false;

  static const _genderValues = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    final avatars = ProfileAvatarPresets.values;
    _selectedAvatar =
        avatars[DateTime.now().millisecondsSinceEpoch % avatars.length];
    _loadInitialData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_assistantFieldsRegistered) return;
    _registerAssistantFields();
    _assistantFieldsRegistered = true;
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedName = prefs.getString('user_display_name')?.trim() ?? '';
    if (!mounted) return;
    if (cachedName.isNotEmpty && _nameController.text.trim().isEmpty) {
      setState(() => _nameController.text = cachedName);
    }
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
        set: (value) {
          final clean = value.trim();
          if (clean.isEmpty) return false;
          _nameController.text = clean;
          if (mounted) setState(() {});
          return true;
        },
      ),
    );

    registry.registerField(
      'personal_details',
      AssistantFieldEntry(
        field: 'gender',
        label: loc.gender,
        suggestions: _genderValues.join(', '),
        read: () => _selectedGender,
        set: (value) {
          for (final gender in _genderValues) {
            if (gender.toLowerCase() == value.trim().toLowerCase()) {
              if (mounted) setState(() => _selectedGender = gender);
              return true;
            }
          }
          return false;
        },
      ),
    );

    registry.registerField(
      'personal_details',
      AssistantFieldEntry(
        field: 'age',
        label: loc.t('age_years'),
        read: () => _age > 0 ? '$_age' : '',
        set: (value) {
          final parsed = int.tryParse(value.trim());
          if (parsed == null || parsed < 1 || parsed > 120) return false;
          if (mounted) {
            setState(() {
              _age = parsed;
              _dateOfBirth = DateTime(DateTime.now().year - parsed, 1, 1);
            });
          }
          return true;
        },
      ),
    );

    registry.registerField(
      'personal_details',
      AssistantFieldEntry(
        field: 'address',
        label: loc.address,
        read: () => _addressController.text.trim(),
        set: (value) {
          final clean = value.trim();
          if (clean.isEmpty) return false;
          _addressController.text = clean;
          _searchAddress(clean);
          return true;
        },
      ),
    );

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
          await _submitProfile();
          return {'saved': true};
        },
      ),
    );
  }

  void _unregisterAssistantFields() {
    final registry = AssistantFieldRegistry.instance;
    for (final field in ['name', 'gender', 'age', 'address']) {
      registry.unregisterField('personal_details', field);
    }
    registry.unregisterAction('personal_details', 'submit_profile');
  }

  @override
  void dispose() {
    _unregisterAssistantFields();
    _nameController.dispose();
    _addressController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  void _calculateAge() {
    if (_dateOfBirth == null) {
      setState(() => _age = 0);
      return;
    }

    final now = DateTime.now();
    var calculatedAge = now.year - _dateOfBirth!.year;
    if (now.month < _dateOfBirth!.month ||
        (now.month == _dateOfBirth!.month &&
            now.day < _dateOfBirth!.day)) {
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
    if (picked == null) return;
    setState(() => _dateOfBirth = picked);
    _calculateAge();
  }

  List<String> _filterStates(String query) {
    return IndiaLocationCatalog.searchStates(query).take(8).toList();
  }

  Future<void> _selectState(String state) async {
    setState(() {
      _selectedState = state;
      _stateController.text = state;
      _stateSuggestions = const [];
      _selectedDistrict = null;
      _districtController.clear();
      _districtOptions = const [];
      _districtSuggestions = const [];
      _addressSuggestions = const [];
      _verifiedAddress = null;
      _addressController.clear();
      _loadingDistricts = true;
      _locationError = null;
    });

    final districts = await IndiaLocationCatalog.districtsForState(state);
    if (!mounted || _selectedState != state) return;
    setState(() {
      _districtOptions = districts;
      _loadingDistricts = false;
    });
  }

  Future<void> _selectDistrict(String district) async {
    final state = _selectedState;
    final cleanDistrict = district.trim();
    if (state == null || cleanDistrict.isEmpty) return;

    setState(() {
      _selectedDistrict = cleanDistrict;
      _districtController.text = cleanDistrict;
      _districtSuggestions = const [];
      _addressSuggestions = const [];
      _addressController.clear();
      _verifiedAddress = null;
      _locationError = null;
    });
  }

  Future<void> _searchAddress(String query) async {
    final state = _selectedState;
    if (state == null || query.trim().length < 2) {
      if (mounted) {
        setState(() {
          _addressSuggestions = const [];
          _searchingAddress = false;
        });
      }
      return;
    }

    setState(() => _searchingAddress = true);
    final results = await _locationService.searchIndianAddresses(
      query,
      state: state,
      district: _selectedDistrict,
    );
    if (!mounted) return;
    setState(() {
      _addressSuggestions = results;
      _searchingAddress = false;
    });
  }

  Future<void> _selectAddress(AddressSearchResult result) async {
    final resultState = result.state?.trim();
    final resultDistrict = result.district?.trim();

    setState(() {
      _verifiedAddress = result.toAddressData();
      _addressController.text = result.displayText;
      _addressSuggestions = const [];

      if (resultState != null && resultState.isNotEmpty) {
        _selectedState = resultState;
        _stateController.text = resultState;
      }
      if (resultDistrict != null && resultDistrict.isNotEmpty) {
        _selectedDistrict = resultDistrict;
        _districtController.text = resultDistrict;
      }
    });

    if (resultState != null && resultState.isNotEmpty) {
      final districts =
          await IndiaLocationCatalog.districtsForState(resultState);
      if (!mounted) return;
      setState(() => _districtOptions = districts);
    }
  }

  Future<void> _useCurrentLocation() async {
    final loc = AppLocalizations.of(context);
    setState(() {
      _gettingLocation = true;
      _locationError = null;
    });

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locationError = loc.locationPermissionNeeded;
          _gettingLocation = false;
        });
        return;
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        setState(() {
          _locationError = loc.locationDetectionFailed;
          _gettingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final placemarks = await _locationService.getPlacemarksFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        if (!mounted) return;
        setState(() {
          _locationError = loc.locationDetectionFailed;
          _gettingLocation = false;
        });
        return;
      }

      final pm = placemarks.first;
      if (!_locationService.isIndiaCountry(
        pm.country,
        isoCode: pm.isoCountryCode,
      )) {
        if (!mounted) return;
        setState(() {
          _locationError = loc.t('india_locations_only');
          _gettingLocation = false;
        });
        return;
      }

      final state = (pm.administrativeArea ?? '').trim();
      final district = (pm.subAdministrativeArea ?? pm.locality ?? '').trim();
      final parts = <String>[
        if ((pm.street ?? '').trim().isNotEmpty) pm.street!.trim(),
        if ((pm.subLocality ?? '').trim().isNotEmpty) pm.subLocality!.trim(),
        if ((pm.locality ?? '').trim().isNotEmpty) pm.locality!.trim(),
        if (district.isNotEmpty && district != pm.locality) district,
        if (state.isNotEmpty) state,
        'India',
        if ((pm.postalCode ?? '').trim().isNotEmpty) pm.postalCode!.trim(),
      ];
      final fullAddress = parts.toSet().join(', ');

      final address = AddressData(
        fullAddress: fullAddress,
        latitude: position.latitude,
        longitude: position.longitude,
        city: pm.locality,
        district: district,
        state: state,
        country: 'India',
        pincode: pm.postalCode,
        isVerified: true,
      );

      final districts = state.isEmpty
          ? const <String>[]
          : await IndiaLocationCatalog.districtsForState(state);

      if (!mounted) return;
      setState(() {
        _selectedState = state.isEmpty ? null : state;
        _selectedDistrict = district.isEmpty ? null : district;
        _stateController.text = state;
        _districtController.text = district;
        _districtOptions = districts;
        _verifiedAddress = address;
        _addressController.text = fullAddress;
        _stateSuggestions = const [];
        _districtSuggestions = const [];
        _addressSuggestions = const [];
        _gettingLocation = false;
      });
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _locationError = loc.locationDetectionFailed;
        _gettingLocation = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationError = loc.locationDetectionFailed;
        _gettingLocation = false;
      });
    }
  }

  Future<void> _submitProfile() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    if (_selectedState == null ||
        _selectedDistrict == null ||
        _verifiedAddress == null ||
        !_verifiedAddress!.isVerified ||
        !_locationService.isIndiaCountry(_verifiedAddress!.country)) {
      setState(() => _locationError =
          AppLocalizations.of(context).selectFromSuggestions);
      return;
    }

    setState(() => _isLoading = true);

    context.read<AuthBloc>().add(
          ProfileSaved(
            fullName: _nameController.text.trim(),
            gender: _selectedGender,
            dateOfBirth: _dateOfBirth,
            age: _age,
            address: _verifiedAddress?.toMap(),
            avatarUrl: _selectedAvatar,
          ),
        );
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
      hintStyle: TextStyle(
        color: colors.onSurfaceMuted.withValues(alpha: 0.65),
      ),
      labelStyle: TextStyle(color: colors.onSurfaceMuted),
      prefixIcon: Icon(icon, color: colors.brandDeep, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colors.bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.brandDeep, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.danger, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
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
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(
              directionalIcon(context, Icons.arrow_back_ios_rounded),
              color: colors.onBackground,
              size: 20,
            ),
            onPressed: _goBack,
          ),
          title: Text(
            loc.personalDetails,
            style: TextStyle(
              color: colors.onBackground,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: false,
          actions: const [
            VidhAIAssistantButton(
              screen: 'personal_details',
              size: 38,
              iconSize: 19,
            ),
            SizedBox(width: 10),
          ],
        ),
        body: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthProfileSaved) {
              setState(() => _isLoading = false);
              if (state.domain == 'farmer') {
                Navigator.of(context)
                    .pushReplacementNamed('/farmer_details');
              } else {
                Navigator.of(context).pushReplacementNamed('/main_shell');
              }
            } else if (state is AuthErrorState) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.errorMessage ?? loc.errorFallback,
                  ),
                  backgroundColor: colors.danger,
                ),
              );
            }
          },
          child: Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _buildHero(loc, colors),
                const SizedBox(height: 16),
                _buildAvatarCard(loc, colors),
                const SizedBox(height: 16),
                _buildPersonalCard(loc, colors),
                const SizedBox(height: 16),
                _buildLocationCard(loc, colors),
                const SizedBox(height: 20),
                _buildSubmitButton(loc, colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(AppLocalizations loc, VidhAIColorsX colors) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.brandDeep,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.brandDeep.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.personalDetails,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loc.pdSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '1 / 2',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarCard(AppLocalizations loc, VidhAIColorsX colors) {
    return _sectionCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            colors,
            icon: Icons.account_circle_outlined,
            title: loc.profileAvatar,
          ),
          const SizedBox(height: 16),
          Center(
            child: ProfileAvatarView(
              avatarValue: _selectedAvatar,
              size: 94,
              backgroundColor: colors.brandDeep.withValues(alpha: 0.09),
              borderColor: colors.brandDeep.withValues(alpha: 0.30),
              fallbackText: _nameController.text,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: ProfileAvatarPresets.values.map((avatar) {
              final selected = avatar == _selectedAvatar;
              return Semantics(
                button: true,
                selected: selected,
                label: loc.profileAvatar,
                child: InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: () => setState(() => _selectedAvatar = avatar),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 54,
                    height: 54,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? colors.brandDeep.withValues(alpha: 0.10)
                          : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? colors.brandDeep
                            : colors.borderColor,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        ProfileAvatarPresets.emojiFor(avatar),
                        style: const TextStyle(fontSize: 29),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalCard(AppLocalizations loc, VidhAIColorsX colors) {
    final dobText = _dateOfBirth == null
        ? ''
        : DateFormat('dd MMM yyyy').format(_dateOfBirth!);

    return _sectionCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            colors,
            icon: Icons.badge_outlined,
            title: loc.personalDetails,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 15,
            ),
            onChanged: (_) => setState(() {}),
            decoration: _inputDecoration(
              label: loc.fullName,
              icon: Icons.person_outline_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().length < 2) {
                return loc.requiredField;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Text(
            loc.gender,
            style: TextStyle(
              color: colors.onSurfaceMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _genderValues.map((value) {
              final selected = _selectedGender == value;
              final label = switch (value) {
                'Male' => loc.male,
                'Female' => loc.female,
                _ => loc.otherGender,
              };
              return ChoiceChip(
                selected: selected,
                label: Text(label),
                avatar: Icon(
                  value == 'Female'
                      ? Icons.female_rounded
                      : value == 'Male'
                          ? Icons.male_rounded
                          : Icons.person_outline_rounded,
                  size: 17,
                  color: selected
                      ? colors.brandDeep
                      : colors.onSurfaceMuted,
                ),
                onSelected: (_) =>
                    setState(() => _selectedGender = value),
                backgroundColor: colors.bg,
                selectedColor:
                    colors.brandDeep.withValues(alpha: 0.12),
                side: BorderSide(
                  color: selected
                      ? colors.brandDeep
                      : colors.borderColor,
                ),
                labelStyle: TextStyle(
                  color: selected
                      ? colors.brandDeep
                      : colors.onBackground,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            }).toList(),
          ),
          if (_selectedGender.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                loc.requiredField,
                style: TextStyle(
                  color: colors.danger,
                  fontSize: 11,
                ),
              ),
            ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: _inputDecoration(
                label: loc.dateOfBirth,
                icon: Icons.cake_outlined,
                suffixIcon: Icon(
                  Icons.calendar_month_rounded,
                  color: colors.brandDeep,
                  size: 20,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      dobText.isEmpty ? loc.selectDate : dobText,
                      style: TextStyle(
                        color: dobText.isEmpty
                            ? colors.onSurfaceMuted
                            : colors.onBackground,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (_age > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color:
                            colors.brandDeep.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_age',
                        style: TextStyle(
                          color: colors.brandDeep,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_dateOfBirth == null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                loc.requiredField,
                style: TextStyle(
                  color: colors.danger,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(
    AppLocalizations loc,
    VidhAIColorsX colors,
  ) {
    return _sectionCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            colors,
            icon: Icons.location_on_outlined,
            title: loc.location,
            trailing: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: colors.brandDeep.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                "🇮🇳 ${loc.t('india')}",
                style: TextStyle(
                  color: colors.brandDeep,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _gettingLocation ? null : _useCurrentLocation,
              icon: _gettingLocation
                  ? SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.brandDeep,
                      ),
                    )
                  : Icon(
                      Icons.my_location_rounded,
                      color: colors.brandDeep,
                      size: 18,
                    ),
              label: Text(
                _gettingLocation
                    ? loc.detectingLocation
                    : loc.useCurrentLocation,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.brandDeep,
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(
                  color: colors.brandDeep.withValues(alpha: 0.35),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _stateController,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: colors.onBackground),
            decoration: _inputDecoration(
              label: loc.state,
              icon: Icons.map_outlined,
            ),
            onTap: () {
              if (_stateController.text.trim().isEmpty) {
                setState(() {
                  _stateSuggestions =
                      IndiaLocationCatalog.states.take(8).toList();
                });
              }
            },
            onChanged: (value) {
              setState(() {
                _selectedState = null;
                _selectedDistrict = null;
                _districtController.clear();
                _districtOptions = const [];
                _districtSuggestions = const [];
                _verifiedAddress = null;
                _addressController.clear();
                _stateSuggestions = _filterStates(value);
              });
            },
            validator: (_) =>
                _selectedState == null ? loc.requiredField : null,
          ),
          _buildTextSuggestions(
            colors: colors,
            values: _stateSuggestions,
            onTap: _selectState,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _districtController,
            enabled: _selectedState != null && !_loadingDistricts,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: colors.onBackground),
            decoration: _inputDecoration(
              label: loc.district,
              icon: Icons.location_city_outlined,
              suffixIcon: _loadingDistricts
                  ? Padding(
                      padding: const EdgeInsets.all(13),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.brandDeep,
                        ),
                      ),
                    )
                  : null,
            ),
            onTap: () {
              if (_districtController.text.trim().isEmpty) {
                setState(() {
                  _districtSuggestions =
                      _districtOptions.take(8).toList();
                });
              }
            },
            onChanged: (value) {
              setState(() {
                _selectedDistrict = null;
                _verifiedAddress = null;
                _addressController.clear();
                _districtSuggestions =
                    IndiaLocationCatalog.filterDistricts(
                  _districtOptions,
                  value,
                ).take(8).toList();
              });
            },
            onFieldSubmitted: (value) {
              final clean = value.trim();
              if (clean.isNotEmpty && _selectedState != null) {
                _selectDistrict(clean);
              }
            },
            validator: (_) =>
                _selectedDistrict == null ? loc.requiredField : null,
          ),
          _buildTextSuggestions(
            colors: colors,
            values: _districtSuggestions,
            onTap: _selectDistrict,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            enabled: _selectedState != null &&
                _selectedDistrict != null,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: colors.onBackground),
            decoration: _inputDecoration(
              label: loc.searchAddress,
              icon: Icons.place_outlined,
              suffixIcon: _searchingAddress
                  ? Padding(
                      padding: const EdgeInsets.all(13),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.brandDeep,
                        ),
                      ),
                    )
                  : _verifiedAddress != null
                      ? Icon(
                          Icons.verified_rounded,
                          color: colors.brandDeep,
                          size: 20,
                        )
                      : null,
            ),
            onChanged: (value) {
              _verifiedAddress = null;
              _searchAddress(value);
            },
            validator: (_) {
              if (_verifiedAddress == null ||
                  !_verifiedAddress!.isVerified) {
                return loc.selectFromSuggestions;
              }
              return null;
            },
          ),
          _buildAddressSuggestions(colors),
          if (_locationError != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: colors.danger,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _locationError!,
                    style: TextStyle(
                      color: colors.danger,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextSuggestions({
    required VidhAIColorsX colors,
    required List<String> values,
    required Future<void> Function(String) onTap,
  }) {
    if (values.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 190),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderColor),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: values.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: colors.borderColor),
        itemBuilder: (_, index) {
          final value = values[index];
          return ListTile(
            dense: true,
            minTileHeight: 42,
            leading: Icon(
              Icons.location_on_outlined,
              color: colors.brandDeep,
              size: 18,
            ),
            title: Text(
              value,
              style: TextStyle(
                color: colors.onBackground,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () => onTap(value),
          );
        },
      ),
    );
  }

  Widget _buildAddressSuggestions(VidhAIColorsX colors) {
    if (_addressSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 210),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderColor),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _addressSuggestions.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: colors.borderColor),
        itemBuilder: (_, index) {
          final suggestion = _addressSuggestions[index];
          return ListTile(
            dense: true,
            leading: Icon(
              Icons.place_outlined,
              color: colors.brandDeep,
              size: 19,
            ),
            title: Text(
              suggestion.displayText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onBackground,
                fontSize: 12.5,
              ),
            ),
            onTap: () => _selectAddress(suggestion),
          );
        },
      ),
    );
  }

  Widget _sectionCard({
    required VidhAIColorsX colors,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.borderColor),
        boxShadow: [
          BoxShadow(
            color: colors.brandDeep.withValues(alpha: 0.055),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(
    VidhAIColorsX colors, {
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.brandDeep.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: colors.brandDeep,
            size: 19,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildSubmitButton(
    AppLocalizations loc,
    VidhAIColorsX colors,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.brandDeep,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              colors.brandDeep.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 23,
                height: 23,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.4,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    loc.continueBtn,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 19,
                  ),
                ],
              ),
      ),
    );
  }
}
