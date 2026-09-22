import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/data/models/user_profile.dart';
import 'package:vidhai/services/ai/ai_service.dart';
import 'package:vidhai/services/location_service.dart';
import 'package:vidhai/services/voice_service.dart';
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
  List<AddressSearchResult> _locationSuggestions = [];
  bool _isListeningName = false;
  bool _isListeningSize = false;
  bool _isListeningWater = false;
  late final String _farmId;

  final VoiceService _voiceService = VoiceService();
  final LocationService _locationService = LocationService();
  Map<String, String> _voiceLocation = {};

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
    _sizeUnit = d?.farmSizeUnit ?? 'Acre';
    _irrigationType = d?.irrigationType ?? '';
    _waterSource = d?.waterSource ?? '';
    _soilType = d?.soilType ?? '';
    _waterAvailability = d?.waterAvailability ?? '';
    _farmingMethod = d?.farmingMethod ?? '';
    _farmLocation = d?.farmLocation;
    _soilAiResult = d?.soilAiResult;
    _voiceService.initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerAssistantFields();
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
          read: () => _voiceLocation['village'] ?? '',
          set: (v) => _setLocationPart('village', v),
        ));
    registry.registerField(
        'add_farm',
        AssistantFieldEntry(
          field: 'location_district',
          label: loc.district,
          read: () => _voiceLocation['district'] ?? '',
          set: (v) => _setLocationPart('district', v),
        ));
    registry.registerField(
        'add_farm',
        AssistantFieldEntry(
          field: 'location_state',
          label: loc.state,
          read: () => _voiceLocation['state'] ?? '',
          set: (v) => _setLocationPart('state', v),
        ));
  }

  /// Builds the location query from voice-provided parts (village, district,
  /// state) and runs the same real address search the screen uses.
  bool _setLocationPart(String key, String value) {
    final clean = value.trim();
    if (clean.isEmpty) return false;
    final next = {..._voiceLocation, key: clean};
    _voiceLocation = next;
    final query = ['village', 'district', 'state']
        .map((k) => next[k] ?? '')
        .where((s) => s.isNotEmpty)
        .join(', ');
    if (query.isNotEmpty) {
      _locationController.text = query;
      _searchLocation(query);
    }
    _emitData();
    return true;
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
    _voiceService.stopListening();
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
    _locationController.text = result.displayText;
    _farmLocation = result.toAddressData();
    setState(() => _locationSuggestions = []);
    _emitData();
  }

  Future<void> _useCurrentLocation() async {
    final loc = AppLocalizations.of(context);
    final colors = VidhAIColorsX(context);
    setState(() => _isGettingCurrentLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(loc.t('permission_denied_text')),
                backgroundColor: colors.danger,
              ),
            );
          }
          setState(() => _isGettingCurrentLocation = false);
          return;
        }
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
                onPressed: () => Geolocator.openAppSettings(),
              ),
            ),
          );
        }
        setState(() => _isGettingCurrentLocation = false);
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
                onPressed: () => Geolocator.openLocationSettings(),
              ),
            ),
          );
        }
        setState(() => _isGettingCurrentLocation = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final placemarks = await _locationService.getPlacemarksFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        final parts = <String>[
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
        final fullAddress =
            parts.isNotEmpty ? parts.join(', ') : 'Current Location';
        _farmLocation = AddressData(
          fullAddress: fullAddress,
          latitude: position.latitude,
          longitude: position.longitude,
          city: pm.locality,
          district: pm.subAdministrativeArea,
          state: pm.administrativeArea,
          country: pm.country,
          pincode: pm.postalCode,
          isVerified: true,
        );
        _locationController.text = fullAddress;
      } else {
        _farmLocation = AddressData(
          fullAddress:
              '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
          latitude: position.latitude,
          longitude: position.longitude,
          isVerified: true,
        );
        _locationController.text = _farmLocation!.fullAddress;
      }
      _emitData();
    } catch (e) {
      if (mounted) {
        final colors2 = VidhAIColorsX(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not get location: $e'),
              backgroundColor: colors2.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingCurrentLocation = false);
    }
  }

  Future<void> _startVoiceInput(VoiceField field) async {
    final loc = AppLocalizations.of(context);
    final colors = VidhAIColorsX(context);
    if (_voiceService.isListening) {
      await _voiceService.stopListening();
      setState(() {
        _isListeningName = false;
        _isListeningSize = false;
        _isListeningWater = false;
      });
      return;
    }
    final hasPermission = await _voiceService.initialize();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(loc.t('microphone_permission')),
              backgroundColor: colors.danger),
        );
      }
      return;
    }
    if (field == VoiceField.farmName) {
      setState(() => _isListeningName = true);
    } else if (field == VoiceField.farmSize) {
      setState(() => _isListeningSize = true);
    } else if (field == VoiceField.waterAvailability) {
      setState(() => _isListeningWater = true);
    }

    await _voiceService.startListening(
      localeId: VoiceService.getLocaleForLanguage(loc.languageCode),
      onResult: (text, confidence) {
        if (field == VoiceField.farmName) {
          _nameController.text = text.trim();
          _emitData();
        } else if (field == VoiceField.farmSize) {
          final numMatch = RegExp(r'(\d+)').firstMatch(text);
          if (numMatch != null) {
            _sizeController.text = numMatch.group(1)!;
          } else {
            _sizeController.text = text.trim();
          }
          _emitData();
        } else if (field == VoiceField.waterAvailability) {
          final mapped = VoiceService.mapWaterAvailability(text);
          if (mapped != null) {
            setState(() => _waterAvailability = mapped);
            _emitData();
          }
        } else if (field == VoiceField.farmingMethod) {
          final mapped =
              VoiceService.extractValue(text, VoiceField.farmingMethod);
          setState(() => _farmingMethod = mapped);
          _emitData();
        }
      },
      onListeningComplete: () {
        if (mounted) {
          setState(() {
            _isListeningName = false;
            _isListeningSize = false;
            _isListeningWater = false;
          });
        }
      },
    );
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

  Widget _voiceSuffix({
    required bool isListening,
    required VoidCallback onTap,
  }) {
    final colors = VidhAIColorsX(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: isListening
              ? colors.danger.withValues(alpha: 0.15)
              : colors.brandDeep.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          isListening ? Icons.mic : Icons.mic_none_rounded,
          color: isListening ? colors.danger : colors.brandDeep,
          size: 19,
        ),
      ),
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

            _buildTextFieldWithVoice(
              controller: _nameController,
              label: loc.farmName,
              icon: Icons.agriculture_rounded,
              onChanged: (_) => _emitData(),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? loc.requiredField : null,
              isListening: _isListeningName,
              onVoiceTap: () => _startVoiceInput(VoiceField.farmName),
            ),
            const SizedBox(height: 12),

            // Size + unit
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: _buildTextFieldWithVoice(
                    controller: _sizeController,
                    label: loc.farmSize,
                    icon: Icons.straighten_rounded,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _emitData(),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? loc.requiredField
                        : null,
                    isListening: _isListeningSize,
                    onVoiceTap: () => _startVoiceInput(VoiceField.farmSize),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: _buildUnitDropdown()),
              ],
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

  Widget _buildTextFieldWithVoice({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    required bool isListening,
    required VoidCallback onVoiceTap,
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
        suffixIcon: _voiceSuffix(
          isListening: isListening,
          onTap: onVoiceTap,
        ),
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
          _voiceSuffix(
            isListening: _isListeningWater,
            onTap: () => _startVoiceInput(VoiceField.waterAvailability),
          ),
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
        TextFormField(
          controller: _locationController,
          style: TextStyle(color: colors.onBackground, fontSize: 15),
          onChanged: _searchLocation,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return loc.requiredField;
            if (_farmLocation == null || !_farmLocation!.isVerified) {
              return loc.selectFromSuggestions;
            }
            return null;
          },
          decoration: _inputDecoration(
            label: loc.farmLocation,
            icon: Icons.location_on_outlined,
            suffixIcon: _isSearchingLocation || _isGettingCurrentLocation
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: colors.brandDeep)))
                : _farmLocation != null && _farmLocation!.isVerified
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(end: 12),
                        child: Icon(Icons.verified,
                            color: colors.brandDeep, size: 20),
                      )
                    : null,
          ),
        ),
        if (_locationSuggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
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
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isGettingCurrentLocation ? null : _useCurrentLocation,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              side: BorderSide(color: colors.brandDeep.withValues(alpha: 0.35)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: _isGettingCurrentLocation
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: colors.brandDeep))
                : Icon(Icons.my_location_rounded,
                    size: 16, color: colors.brandDeep),
            label: Text(
                _isGettingCurrentLocation
                    ? loc.t('getting_location')
                    : loc.t('use_current_location'),
                style: TextStyle(color: colors.brandDeep, fontSize: 13)),
          ),
        ),
        if (_farmLocation != null && _farmLocation!.isVerified) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.verified, color: colors.brandDeep, size: 14),
            const SizedBox(width: 4),
            Expanded(
                child: Text(
              '${_farmLocation!.city ?? ''} ${_farmLocation!.state ?? ''} ${_farmLocation!.country ?? ''}'
                  .trim(),
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
            )),
          ]),
        ],
      ],
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
