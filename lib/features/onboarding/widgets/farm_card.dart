import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/data/models/user_profile.dart';
import 'package:vidhai/services/ai/ai_service.dart';
import 'package:vidhai/services/location_service.dart';
import 'package:vidhai/data/india_location_catalog.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/features/assistant/assistant_field_registry.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';

class FarmCard extends StatefulWidget {
  final int farmIndex;
  final int totalFarms;
  final FarmProfile? initialData;
  final ValueChanged<FarmProfile> onDataChanged;
  final bool assistantEnabled;

  const FarmCard({
    super.key,
    required this.farmIndex,
    required this.totalFarms,
    this.initialData,
    required this.onDataChanged,
    this.assistantEnabled = false,
  });

  @override
  State<FarmCard> createState() => _FarmCardState();
}

class _FarmCardState extends State<FarmCard> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _sizeController;
  late final TextEditingController _locationController;
  late final TextEditingController _stateController;
  late final TextEditingController _districtController;
  String _sizeUnit = 'Acre';
  String _irrigationType = '';
  String _waterSource = '';
  String _soilType = '';
  String _waterAvailability = '';
  String _farmingMethod = '';
  AddressData? _farmLocation;
  SoilAiResult? _soilAiResult;
  bool _isSearchingLocation = false;
  bool _isGettingCurrentLocation = false;
  bool _isAnalyzingSoil = false;
  bool _isLoadingDistricts = false;
  List<AddressSearchResult> _locationSuggestions = [];
  List<String> _stateSuggestions = const [];
  List<String> _districtSuggestions = const [];
  List<String> _districtOptions = const [];
  String? _selectedState;
  String? _selectedDistrict;
  late final String _farmId;

  final LocationService _locationService = LocationService();
  Map<String, String> _assistantLocation = {};

  static const _sizeUnits = ['Acre', 'Hectare', 'Cent', 'Bigha'];
  static const _irrigationTypes = [
    'Drip',
    'Sprinkler',
    'Flood',
    'Rainfed',
    'Manual',
    'Other',
  ];
  static const _waterSources = [
    'Well',
    'Borewell',
    'River',
    'Canal',
    'Rainwater',
    'Pond',
    'Municipal',
    'Other',
  ];
  static const _soilTypes = [
    'Clay',
    'Sandy',
    'Loamy',
    'Silt',
    'Peat',
    'Chalk',
    'Saline',
    'Black (Regur)',
    'Red',
    'Laterite',
  ];
  static const _waterLevels = ['High', 'Medium', 'Low', 'Very Low', 'No Water'];
  static const _farmingMethods = [
    'Organic Farming',
    'Integrated Farming',
    'Conventional/Chemical Farming',
    'Natural Farming',
    'Precision Farming',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _farmId = (d?.farmId != null && d!.farmId.isNotEmpty)
        ? d.farmId
        : const Uuid().v4();
    _nameController = TextEditingController(text: d?.farmName ?? '');
    _sizeController = TextEditingController(text: d?.farmSize ?? '');
    _locationController =
        TextEditingController(text: d?.farmLocation?.fullAddress ?? '');
    _stateController =
        TextEditingController(text: d?.farmLocation?.state ?? '');
    _districtController =
        TextEditingController(text: d?.farmLocation?.district ?? '');
    _selectedState = (d?.farmLocation?.state ?? '').trim().isEmpty
        ? null
        : d!.farmLocation!.state!.trim();
    _selectedDistrict = (d?.farmLocation?.district ?? '').trim().isEmpty
        ? null
        : d!.farmLocation!.district!.trim();
    _sizeUnit = d?.farmSizeUnit ?? 'Acre';
    _irrigationType = d?.irrigationType ?? '';
    _waterSource = d?.waterSource ?? '';
    _soilType = d?.soilType ?? '';
    _waterAvailability = d?.waterAvailability ?? '';
    _farmingMethod = d?.farmingMethod ?? '';
    _farmLocation = d?.farmLocation;
    _soilAiResult = d?.soilAiResult;
    _registerAssistantFields();
    if (_selectedState != null) {
      _loadDistricts(_selectedState!);
    }
  }

  /// Exposes this farm form's real fields/actions to the VidhAI Assistant
  /// overlay when the screen opts in (Assisted Add Farm only, to avoid
  /// colliding with onboarding where FarmCard is also used).
  void _registerAssistantFields() {
    if (!widget.assistantEnabled) return;
    final loc = AppLocalizations.of(context);
    final registry = AssistantFieldRegistry.instance;
    void registerDropdown(String field, String label, String current,
        List<String> options, void Function(String) apply) {
      registry.registerField(
          'add_farm',
          AssistantFieldEntry(
            field: field,
            label: label,
            suggestions: options.join(', '),
            read: () => current,
            set: (v) {
              for (final o in options) {
                if (o.toLowerCase() == v.trim().toLowerCase()) {
                  apply(o);
                  return true;
                }
              }
              return false;
            },
          ));
    }

    registry.registerField(
        'add_farm',
        AssistantFieldEntry(
          field: 'farm_name',
          label: loc.farmName,
          read: () => _nameController.text.trim(),
          set: (v) {
            if (v.trim().isEmpty) return false;
            _nameController.text = v.trim();
            _emitData();
            return true;
          },
        ));
    registry.registerField(
        'add_farm',
        AssistantFieldEntry(
          field: 'farm_size',
          label: loc.farmSize,
          read: () => _sizeController.text.trim(),
          set: (v) {
            final clean = v.trim();
            if (clean.isEmpty || int.tryParse(clean.split(' ').first) == null) {
              return false;
            }
            _sizeController.text = clean.split(' ').first;
            _emitData();
            return true;
          },
        ));
    registerDropdown('farm_size_unit', 'Size unit', _sizeUnit, _sizeUnits, (o) {
      setState(() => _sizeUnit = o);
      _emitData();
    });
    registerDropdown(
        'irrigation_type', 'Irrigation type', _irrigationType, _irrigationTypes,
        (o) {
      setState(() => _irrigationType = o);
      _emitData();
    });
    registerDropdown(
        'water_source', 'Water source', _waterSource, _waterSources, (o) {
      setState(() => _waterSource = o);
      _emitData();
    });
    registerDropdown('soil_type', 'Soil type', _soilType, _soilTypes, (o) {
      setState(() => _soilType = o);
      _emitData();
    });
    registerDropdown('water_availability', 'Water availability',
        _waterAvailability, _waterLevels, (o) {
      setState(() => _waterAvailability = o);
      _emitData();
    });
    registerDropdown(
        'farming_method', 'Farming method', _farmingMethod, _farmingMethods,
        (o) {
      setState(() => _farmingMethod = o);
      _emitData();
    });
    registry.registerField(
        'add_farm',
        AssistantFieldEntry(
          field: 'farm_location',
          label: loc.farmLocation,
          read: () => _locationController.text.trim(),
          set: (v) {
            if (v.trim().isEmpty) return false;
            _locationController.text = v.trim();
            _searchLocation(v.trim());
            _emitData();
            return true;
          },
        ));
    registry.registerField(
        'add_farm',
        AssistantFieldEntry(
          field: 'location_village',
          label: loc.village,
          read: () => _assistantLocation['village'] ?? '',
          set: (v) => _setLocationPart('village', v),
        ));
    registry.registerField(
        'add_farm',
        AssistantFieldEntry(
          field: 'location_district',
          label: loc.district,
          read: () => _assistantLocation['district'] ?? '',
          set: (v) => _setLocationPart('district', v),
        ));
    registry.registerField(
        'add_farm',
        AssistantFieldEntry(
          field: 'location_state',
          label: loc.state,
          read: () => _assistantLocation['state'] ?? '',
          set: (v) => _setLocationPart('state', v),
        ));
  }

  /// Builds a location query from Assistant-provided parts and runs the same
  /// India-only address search used by the form.
  bool _setLocationPart(String key, String value) {
    final clean = value.trim();
    if (clean.isEmpty) return false;

    _assistantLocation = {..._assistantLocation, key: clean};

    if (key == 'state') {
      final match = IndiaLocationCatalog.states.where(
        (state) => state.toLowerCase() == clean.toLowerCase(),
      );
      if (match.isEmpty) return false;
      _selectState(match.first);
      return true;
    }

    if (key == 'district') {
      if (_selectedState == null) return false;
      _selectDistrict(clean);
      return true;
    }

    if (key == 'village') {
      if (_selectedState == null || _selectedDistrict == null) return false;
      _locationController.text = clean;
      _searchLocation(clean);
      return true;
    }

    return false;
  }

  void _unregisterAssistantFields() {
    if (!widget.assistantEnabled) return;
    final registry = AssistantFieldRegistry.instance;
    for (final f in [
      'farm_name',
      'farm_size',
      'farm_size_unit',
      'irrigation_type',
      'water_source',
      'soil_type',
      'water_availability',
      'farming_method',
      'farm_location',
      'location_village',
      'location_district',
      'location_state',
    ]) {
      registry.unregisterField('add_farm', f);
    }
  }

  @override
  void dispose() {
    _unregisterAssistantFields();
    _nameController.dispose();
    _sizeController.dispose();
    _locationController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  void _emitData() {
    widget.onDataChanged(FarmProfile(
      farmId: _farmId,
      index: widget.farmIndex,
      farmName: _nameController.text.trim(),
      farmSize: _sizeController.text.trim(),
      farmSizeUnit: _sizeUnit,
      farmLocation: _farmLocation,
      irrigationType: _irrigationType,
      waterSource: _waterSource,
      soilType: _soilType,
      waterAvailability: _waterAvailability,
      farmingMethod: _farmingMethod,
      soilAiResult: _soilAiResult,
    ));
  }

  int get _filledFields {
    var c = 0;
    if (_nameController.text.trim().isNotEmpty) c++;
    if (_sizeController.text.trim().isNotEmpty) c++;
    if (_farmLocation != null && _farmLocation!.isVerified) c++;
    if (_irrigationType.isNotEmpty) c++;
    if (_waterSource.isNotEmpty) c++;
    if (_soilType.isNotEmpty) c++;
    if (_waterAvailability.isNotEmpty) c++;
    return c;
  }

  Future<void> _loadDistricts(String state) async {
    if (state.trim().isEmpty) return;
    if (mounted) {
      setState(() => _isLoadingDistricts = true);
    }
    final districts = await IndiaLocationCatalog.districtsForState(state);
    if (!mounted || _selectedState != state) return;
    setState(() {
      _districtOptions = districts;
      _isLoadingDistricts = false;
    });
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
      _locationSuggestions = [];
      _locationController.clear();
      _farmLocation = null;
      _isLoadingDistricts = true;
    });
    _emitData();
    await _loadDistricts(state);
  }

  Future<void> _selectDistrict(String district) async {
    final state = _selectedState;
    if (state == null) return;

    setState(() {
      _selectedDistrict = district;
      _districtController.text = district;
      _districtSuggestions = const [];
      _locationSuggestions = [];
    });

    final resolved = await _locationService.resolveIndianDistrict(
      state: state,
      district: district,
    );
    if (!mounted ||
        _selectedState != state ||
        _selectedDistrict != district) {
      return;
    }

    setState(() {
      _farmLocation = resolved ??
          AddressData(
            fullAddress: '$district, $state, India',
            district: district,
            state: state,
            country: 'India',
            isVerified: true,
          );
      _locationController.text = _farmLocation!.fullAddress;
    });
    _emitData();
  }

  Future<void> _searchLocation(String query) async {
    if ((_selectedState ?? '').isEmpty ||
        (_selectedDistrict ?? '').isEmpty ||
        query.trim().length < 2) {
      if (mounted) {
        setState(() {
          _locationSuggestions = [];
          _isSearchingLocation = false;
        });
      }
      return;
    }

    setState(() => _isSearchingLocation = true);
    final results = await _locationService.searchIndianAddresses(
      query,
      state: _selectedState,
      district: _selectedDistrict,
    );
    if (!mounted) return;
    setState(() {
      _locationSuggestions = results;
      _isSearchingLocation = false;
    });
  }

  Future<void> _selectLocation(AddressSearchResult result) async {
    final state = (result.state ?? _selectedState ?? '').trim();
    final district =
        (result.district ?? _selectedDistrict ?? '').trim();

    setState(() {
      _locationController.text = result.displayText;
      _farmLocation = result.toAddressData();
      _locationSuggestions = [];
      if (state.isNotEmpty) {
        _selectedState = state;
        _stateController.text = state;
      }
      if (district.isNotEmpty) {
        _selectedDistrict = district;
        _districtController.text = district;
      }
    });
    _emitData();

    if (state.isNotEmpty) {
      final districts =
          await IndiaLocationCatalog.districtsForState(state);
      if (!mounted) return;
      setState(() => _districtOptions = districts);
    }
  }

  Future<void> _useCurrentLocation() async {
    final loc = AppLocalizations.of(context);
    final colors = VidhAIColorsX(context);
    setState(() => _isGettingCurrentLocation = true);

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.t('permission_denied_text')),
              backgroundColor: colors.danger,
            ),
          );
        }
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.t('permission_permanent')),
              backgroundColor: colors.danger,
              action: SnackBarAction(
                label: loc.t('settings'),
                textColor: Colors.white,
                onPressed: Geolocator.openAppSettings,
              ),
            ),
          );
        }
        return;
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.t('location_disabled')),
              backgroundColor: colors.danger,
              action: SnackBarAction(
                label: loc.t('settings'),
                textColor: Colors.white,
                onPressed: Geolocator.openLocationSettings,
              ),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final placemarks =
          await _locationService.getPlacemarksFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.locationDetectionFailed),
              backgroundColor: colors.danger,
            ),
          );
        }
        return;
      }

      final pm = placemarks.first;
      if (!_locationService.isIndiaCountry(
        pm.country,
        isoCode: pm.isoCountryCode,
      )) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.t('india_locations_only')),
              backgroundColor: colors.warning,
            ),
          );
        }
        return;
      }

      final state = (pm.administrativeArea ?? '').trim();
      final district =
          (pm.subAdministrativeArea ?? pm.locality ?? '').trim();

      final parts = <String>[
        if ((pm.street ?? '').trim().isNotEmpty) pm.street!.trim(),
        if ((pm.subLocality ?? '').trim().isNotEmpty)
          pm.subLocality!.trim(),
        if ((pm.locality ?? '').trim().isNotEmpty) pm.locality!.trim(),
        if (district.isNotEmpty && district != pm.locality) district,
        if (state.isNotEmpty) state,
        'India',
        if ((pm.postalCode ?? '').trim().isNotEmpty)
          pm.postalCode!.trim(),
      ];
      final fullAddress = parts.toSet().join(', ');

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
        _stateSuggestions = const [];
        _districtSuggestions = const [];
        _locationSuggestions = [];
        _farmLocation = AddressData(
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
        _locationController.text = fullAddress;
      });
      _emitData();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.locationDetectionFailed),
            backgroundColor: colors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGettingCurrentLocation = false);
      }
    }
  }

  void _showSoilScanDialog() {
    final loc = AppLocalizations.of(context);
    final colors = VidhAIColorsX(context);
    showModalBottomSheet(
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'AI Soil Scan',
                  style: TextStyle(
                      color: colors.onBackground,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                'Capture or upload a soil image for AI analysis.',
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.camera_alt, color: colors.brandDeep),
                title: Text(loc.takePhoto,
                    style: TextStyle(color: colors.onBackground)),
                onTap: () {
                  Navigator.pop(ctx);
                  _analyzeSoil('camera');
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: colors.brandDeep),
                title: Text(loc.t('choose_gallery'),
                    style: TextStyle(color: colors.onBackground)),
                onTap: () {
                  Navigator.pop(ctx);
                  _analyzeSoil('gallery');
                },
              ),
              if (_soilAiResult != null)
                ListTile(
                  leading: Icon(Icons.check_circle, color: colors.brandDeep),
                  title: Text(loc.t('view_prev_result'),
                      style: TextStyle(color: colors.onBackground)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSoilResult();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _analyzeSoil(String source) async {
    final loc = AppLocalizations.of(context);
    final colors = VidhAIColorsX(context);
    setState(() => _isAnalyzingSoil = true);

    _showAnalyzingDialog();

    try {
      await AiService.instance.loadConfig();

      final soilType = _soilType.isNotEmpty ? _soilType : 'Not specified';
      final locationStr =
          _farmLocation != null ? _farmLocation!.fullAddress : 'Not provided';
      final moisture =
          _waterAvailability.isNotEmpty ? _waterAvailability : 'Not measured';

      final additionalData = <String, dynamic>{};
      if (_irrigationType.isNotEmpty) {
        additionalData['irrigationType'] = _irrigationType;
      }
      if (_waterSource.isNotEmpty) {
        additionalData['waterSource'] = _waterSource;
      }
      if (_farmingMethod.isNotEmpty) {
        additionalData['farmingMethod'] = _farmingMethod;
      }
      if (_sizeController.text.trim().isNotEmpty) {
        additionalData['farmSize'] =
            '${_sizeController.text.trim()} $_sizeUnit';
      }

      final request = SoilAnalysisRequest(
        soilType: soilType,
        ph: '6.5',
        moisture: moisture,
        location: locationStr,
        additionalData: additionalData.isNotEmpty ? additionalData : null,
      );

      final response = await AiService.instance.getSoilAnalysis(request);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (response.success) {
        final json = response.jsonContent;
        if (json != null) {
          final conf = (json['confidence'] as num?)?.toDouble() ?? 0.0;
          setState(() {
            _soilAiResult = SoilAiResult(
              soilType: (json['soilType'] ?? soilType) as String,
              characteristics: (json['characteristics'] ?? '') as String,
              confidence: conf / (conf > 1 ? 100 : 1),
              suitability: (json['suitability'] ?? '') as String,
              observations: (json['observations'] ?? '') as String,
              analyzedAt: DateTime.now(),
            );
          });
        } else {
          setState(() {
            _soilAiResult = SoilAiResult(
              soilType: soilType,
              characteristics: response.content,
              confidence: 0.7,
              suitability: 'Refer to analysis above',
              observations: response.content,
              analyzedAt: DateTime.now(),
            );
          });
        }
        _showSoilResult();
      } else {
        setState(() {
          _isAnalyzingSoil = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${loc.t('ai_analysis_failed')} ${response.error ?? "Unknown error"}'),
              backgroundColor: colors.danger,
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() {
        _isAnalyzingSoil = false;
      });
      if (mounted) {
        final colors2 = VidhAIColorsX(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.t('soil_analysis_error')} $e'),
            backgroundColor: colors2.danger,
          ),
        );
      }
      return;
    }

    setState(() => _isAnalyzingSoil = false);
  }

  void _showAnalyzingDialog() {
    final colors = VidhAIColorsX(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            CircularProgressIndicator(color: colors.brandDeep, strokeWidth: 3),
            const SizedBox(height: 20),
            Text(
              'Analyzing Soil...',
              style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'VidhAI is analyzing your soil data.',
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showSoilResult() {
    if (_soilAiResult == null) return;
    final r = _soilAiResult!;
    final loc = AppLocalizations.of(context);
    final colors = VidhAIColorsX(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(loc.t('ai_soil_analysis'),
            style: TextStyle(color: colors.onBackground, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resultRow('Soil Type', r.soilType),
            _resultRow(
                'Confidence',
                r.confidence > 0
                    ? '${(r.confidence * 100).round()}%'
                    : 'Pending'),
            _resultRow('Characteristics', r.characteristics),
            _resultRow('Suitability', r.suitability),
            _resultRow('Observations', r.observations),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.close, style: TextStyle(color: colors.brandDeep)),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    final colors = VidhAIColorsX(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(color: colors.onBackground, fontSize: 14),
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
        ],
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
      hintStyle: TextStyle(color: colors.onSurfaceMuted.withValues(alpha: 0.6)),
      labelStyle: TextStyle(color: colors.onSurfaceMuted),
      prefixIcon: Icon(icon, color: colors.onSurfaceMuted, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
    );
  }

  Widget _sectionHeader(IconData icon, String label) {
    final colors = VidhAIColorsX(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 12),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: colors.brandDeep.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: colors.brandDeep, size: 15),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = VidhAIColorsX(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderColor),
        boxShadow: [
          BoxShadow(
            color: colors.brandDeep.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Card header: farm number + progress --
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.brandDeep,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text('${widget.farmIndex}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${loc.farmCard} ${widget.farmIndex}',
                          style: TextStyle(
                              color: colors.onBackground,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 1),
                      Text(
                        '${widget.farmIndex} ${loc.ofLabel} ${widget.totalFarms} • $_filledFields/7',
                        style: TextStyle(
                          color: colors.onSurfaceMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_filledFields == 7)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.brandDeep.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            color: colors.brandDeep, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          loc.complete,
                          style: TextStyle(
                            color: colors.brandDeep,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.borderColor),
                    ),
                    child: Text(
                      '$_filledFields/7',
                      style: TextStyle(
                        color: colors.onSurfaceMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, thickness: 1),
            ),

            // -- Basic Details --
            _sectionHeader(Icons.landscape_rounded, loc.farmInfo),

            _buildTextField(
              controller: _nameController,
              label: loc.farmName,
              icon: Icons.agriculture_rounded,
              onChanged: (_) => _emitData(),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? loc.requiredField : null,
            ),
            const SizedBox(height: 12),

            // Size + unit — stacks on narrow screens to avoid overflow.
            LayoutBuilder(
              builder: (context, constraints) {
                final sizeField = _buildTextField(
                  controller: _sizeController,
                  label: loc.farmSize,
                  icon: Icons.straighten_rounded,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _emitData(),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? loc.requiredField
                      : null,
                );

                if (constraints.maxWidth < 360) {
                  return Column(
                    children: [
                      sizeField,
                      const SizedBox(height: 10),
                      _buildUnitDropdown(),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: sizeField),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: _buildUnitDropdown()),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            _buildLocationField(loc),
            const SizedBox(height: 8),

            // -- Soil & Water --
            _sectionHeader(Icons.water_drop_rounded, loc.soilAndWater),

            _buildDropdown(
              value: _irrigationType.isEmpty ? null : _irrigationType,
              label: loc.irrigationType,
              icon: Icons.water_drop_outlined,
              items: _irrigationTypes,
              onChanged: (v) {
                setState(() => _irrigationType = v ?? '');
                _emitData();
              },
              validator: (v) =>
                  v == null || v.isEmpty ? loc.requiredField : null,
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              value: _waterSource.isEmpty ? null : _waterSource,
              label: loc.waterSource,
              icon: Icons.water_outlined,
              items: _waterSources,
              onChanged: (v) {
                setState(() => _waterSource = v ?? '');
                _emitData();
              },
              validator: (v) =>
                  v == null || v.isEmpty ? loc.requiredField : null,
            ),
            const SizedBox(height: 12),
            _buildWaterAvailability(loc),
            const SizedBox(height: 12),
            _buildSoilSection(loc),
            const SizedBox(height: 8),

            // -- Farming Method --
            _sectionHeader(Icons.agriculture_rounded, loc.farmingMethod),

            _buildDropdown(
              value: _farmingMethod.isEmpty ? null : _farmingMethod,
              label: loc.farmingMethod,
              icon: Icons.eco_outlined,
              items: _farmingMethods,
              onChanged: (v) {
                setState(() => _farmingMethod = v ?? '');
                _emitData();
              },
              validator: (v) => null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    final colors = VidhAIColorsX(context);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: colors.onBackground, fontSize: 15),
      onChanged: onChanged,
      validator: validator,
      decoration: _inputDecoration(
        label: label,
        icon: icon,
      ),
    );
  }

  Widget _buildUnitDropdown() {
    final colors = VidhAIColorsX(context);
    return DropdownButtonFormField<String>(
      initialValue: _sizeUnit,
      style: TextStyle(color: colors.onBackground, fontSize: 14),
      dropdownColor: colors.surface,
      decoration: _inputDecoration(
        label: 'Unit',
        icon: Icons.square_foot_rounded,
      ),
      items: _sizeUnits
          .map((u) => DropdownMenuItem(
              value: u,
              child: Text(
                u,
                style: TextStyle(fontSize: 14, color: colors.onBackground),
              )))
          .toList(),
      onChanged: (v) {
        setState(() => _sizeUnit = v ?? 'Acre');
        _emitData();
      },
    );
  }

  Widget _buildWaterAvailability(AppLocalizations loc) {
    final colors = VidhAIColorsX(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.water_drop_outlined,
              color: colors.onSurfaceMuted, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(loc.waterAvailability,
                  style: TextStyle(
                      color: colors.onSurfaceMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500))),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _waterLevels.map((level) {
            final isSelected = _waterAvailability == level;
            final color = _waterLevelColor(level);
            return GestureDetector(
              onTap: () {
                setState(() => _waterAvailability = level);
                _emitData();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.2)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : colors.borderColor,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(level,
                    style: TextStyle(
                      color: isSelected ? color : colors.onSurfaceMuted,
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    )),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _waterLevelColor(String level) {
    final colors = VidhAIColorsX(context);
    switch (level) {
      case 'High':
        return colors.info;
      case 'Medium':
        return colors.brandDeep;
      case 'Low':
        return colors.warning;
      case 'Very Low':
        return const Color(0xFFFF5722);
      case 'No Water':
        return colors.danger;
      default:
        return colors.brandDeep;
    }
  }

  Widget _buildSoilSection(AppLocalizations loc) {
    final colors = VidhAIColorsX(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.terrain_rounded, color: colors.onSurfaceMuted, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(loc.soilType,
                  style: TextStyle(
                      color: colors.onSurfaceMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500))),
          GestureDetector(
            onTap: _isAnalyzingSoil ? null : _showSoilScanDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isAnalyzingSoil
                    ? colors.warning.withValues(alpha: 0.15)
                    : colors.brandDeep.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _isAnalyzingSoil
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: colors.warning))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt_rounded,
                            color: colors.brandDeep, size: 15),
                        const SizedBox(width: 4),
                        Text(
                          loc.aiSoilScan,
                          style:
                              TextStyle(color: colors.brandDeep, fontSize: 12),
                        ),
                      ],
                    ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _soilType.isEmpty ? null : _soilType,
          style: TextStyle(color: colors.onBackground, fontSize: 15),
          dropdownColor: colors.surface,
          decoration: _inputDecoration(
            label: loc.t('manual_select'),
            icon: Icons.terrain_rounded,
          ),
          items: _soilTypes
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) {
            setState(() => _soilType = v ?? '');
            _emitData();
          },
        ),
        if (_soilAiResult != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showSoilResult,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.brandDeep.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: colors.brandDeep.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: colors.brandDeep, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                    'AI Result: ${_soilAiResult!.soilType}',
                    style: TextStyle(color: colors.onBackground, fontSize: 13),
                  )),
                  Icon(directionalIcon(context, Icons.chevron_right),
                      color: colors.onSurfaceMuted, size: 16),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationField(AppLocalizations loc) {
    final colors = VidhAIColorsX(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                loc.farmLocation,
                style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: colors.brandDeep.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '🇮🇳 India',
                style: TextStyle(
                  color: colors.brandDeep,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isGettingCurrentLocation ? null : _useCurrentLocation,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: 13,
                horizontal: 12,
              ),
              side: BorderSide(
                color: colors.brandDeep.withValues(alpha: 0.35),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: _isGettingCurrentLocation
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
                    size: 17,
                    color: colors.brandDeep,
                  ),
            label: Text(
              _isGettingCurrentLocation
                  ? loc.t('getting_location')
                  : loc.t('use_current_location'),
              style: TextStyle(
                color: colors.brandDeep,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // State search. Suggestions appear from the first typed letter.
        TextFormField(
          controller: _stateController,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: colors.onBackground, fontSize: 14),
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
              _locationController.clear();
              _locationSuggestions = [];
              _farmLocation = null;
              _stateSuggestions =
                  IndiaLocationCatalog.searchStates(value).take(8).toList();
            });
            _emitData();
          },
          validator: (_) =>
              _selectedState == null ? loc.requiredField : null,
        ),
        _buildStringSuggestions(
          values: _stateSuggestions,
          onTap: _selectState,
        ),
        const SizedBox(height: 12),

        // District list is loaded only for the selected state and filtered
        // locally so one typed letter is enough to show recommendations.
        TextFormField(
          controller: _districtController,
          enabled: _selectedState != null && !_isLoadingDistricts,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: colors.onBackground, fontSize: 14),
          decoration: _inputDecoration(
            label: loc.district,
            icon: Icons.location_city_outlined,
            suffixIcon: _isLoadingDistricts
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
                _districtSuggestions = _districtOptions.take(8).toList();
              });
            }
          },
          onChanged: (value) {
            setState(() {
              _selectedDistrict = null;
              _locationController.clear();
              _locationSuggestions = [];
              _farmLocation = null;
              _districtSuggestions =
                  IndiaLocationCatalog.filterDistricts(
                _districtOptions,
                value,
              ).take(8).toList();
            });
            _emitData();
          },
          validator: (_) =>
              _selectedDistrict == null ? loc.requiredField : null,
        ),
        _buildStringSuggestions(
          values: _districtSuggestions,
          onTap: _selectDistrict,
        ),
        const SizedBox(height: 12),

        TextFormField(
          controller: _locationController,
          enabled: _selectedState != null && _selectedDistrict != null,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: colors.onBackground, fontSize: 14),
          onChanged: (value) {
            _farmLocation = null;
            _searchLocation(value);
            _emitData();
          },
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return loc.requiredField;
            }
            if (_farmLocation == null || !_farmLocation!.isVerified) {
              return loc.selectFromSuggestions;
            }
            if (!_locationService.isIndiaCountry(_farmLocation!.country)) {
              return loc.t('india_locations_only');
            }
            return null;
          },
          decoration: _inputDecoration(
            label: loc.farmLocation,
            icon: Icons.place_outlined,
            suffixIcon: _isSearchingLocation
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
                : _farmLocation != null && _farmLocation!.isVerified
                    ? Padding(
                        padding:
                            const EdgeInsetsDirectional.only(end: 12),
                        child: Icon(
                          Icons.verified_rounded,
                          color: colors.brandDeep,
                          size: 20,
                        ),
                      )
                    : null,
          ),
        ),
        if (_locationSuggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 210),
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.borderColor),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _locationSuggestions.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: colors.borderColor),
              itemBuilder: (context, index) {
                final suggestion = _locationSuggestions[index];
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
                  onTap: () => _selectLocation(suggestion),
                );
              },
            ),
          ),
        ],
        if (_farmLocation != null && _farmLocation!.isVerified) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: colors.brandDeep.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.brandDeep.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: colors.brandDeep,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _farmLocation!.fullAddress,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurfaceMuted,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStringSuggestions({
    required List<String> values,
    required Future<void> Function(String) onTap,
  }) {
    if (values.isEmpty) return const SizedBox.shrink();
    final colors = VidhAIColorsX(context);

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
            leading: Icon(
              Icons.location_on_outlined,
              color: colors.brandDeep,
              size: 18,
            ),
            title: Text(
              value,
              style: TextStyle(
                color: colors.onBackground,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () => onTap(value),
          );
        },
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
    required String? Function(String?) validator,
  }) {
    final colors = VidhAIColorsX(context);
    return DropdownButtonFormField<String>(
      initialValue: value,
      style: TextStyle(color: colors.onBackground, fontSize: 15),
      dropdownColor: colors.surface,
      decoration: _inputDecoration(
        label: label,
        icon: icon,
      ),
      items:
          items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}
