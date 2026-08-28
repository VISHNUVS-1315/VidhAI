import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/data/models/user_profile.dart';
import 'package:vidhai/services/ai/ai_service.dart';
import 'package:vidhai/services/location_service.dart';
import 'package:vidhai/services/voice_service.dart';
import 'package:vidhai/locale/locale.dart';

class FarmCard extends StatefulWidget {
  final int farmIndex;
  final int totalFarms;
  final FarmProfile? initialData;
  final ValueChanged<FarmProfile> onDataChanged;

  const FarmCard({
    super.key,
    required this.farmIndex,
    required this.totalFarms,
    this.initialData,
    required this.onDataChanged,
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

  static const _sizeUnits = ['Acre', 'Hectare', 'Cent', 'Bigha'];
  static const _irrigationTypes = [
    'Drip', 'Sprinkler', 'Flood', 'Rainfed', 'Manual', 'Other',
  ];
  static const _waterSources = [
    'Well', 'Borewell', 'River', 'Canal', 'Rainwater',
    'Pond', 'Municipal', 'Other',
  ];
  static const _soilTypes = [
    'Clay', 'Sandy', 'Loamy', 'Silt', 'Peat', 'Chalk',
    'Saline', 'Black (Regur)', 'Red', 'Laterite',
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
  void dispose() {
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
    setState(() => _isGettingCurrentLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied'),
                backgroundColor: Color(0xFFEF4444),
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
              content: const Text('Location permission permanently denied. Enable in Settings.'),
              backgroundColor: const Color(0xFFEF4444),
              action: SnackBarAction(
                label: 'Settings', textColor: Colors.white,
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
              content: const Text('Location services disabled. Enable GPS.'),
              backgroundColor: const Color(0xFFEF4444),
              action: SnackBarAction(
                label: 'Settings', textColor: Colors.white,
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
          accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15),
        ),
      );
      final placemarks = await _locationService.getPlacemarksFromCoordinates(
        position.latitude, position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        final parts = <String>[
          if (pm.street != null && pm.street!.isNotEmpty) pm.street!,
          if (pm.subLocality != null && pm.subLocality!.isNotEmpty) pm.subLocality!,
          if (pm.locality != null && pm.locality!.isNotEmpty) pm.locality!,
          if (pm.administrativeArea != null && pm.administrativeArea!.isNotEmpty) pm.administrativeArea!,
          if (pm.country != null && pm.country!.isNotEmpty) pm.country!,
          if (pm.postalCode != null && pm.postalCode!.isNotEmpty) pm.postalCode!,
        ];
        final fullAddress = parts.isNotEmpty ? parts.join(', ') : 'Current Location';
        _farmLocation = AddressData(
          fullAddress: fullAddress,
          latitude: position.latitude, longitude: position.longitude,
          city: pm.locality, district: pm.subAdministrativeArea,
          state: pm.administrativeArea, country: pm.country,
          pincode: pm.postalCode, isVerified: true,
        );
        _locationController.text = fullAddress;
      } else {
        _farmLocation = AddressData(
          fullAddress: '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
          latitude: position.latitude, longitude: position.longitude, isVerified: true,
        );
        _locationController.text = _farmLocation!.fullAddress;
      }
      _emitData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingCurrentLocation = false);
    }
  }

  Future<void> _startVoiceInput(VoiceField field) async {
    if (_voiceService.isListening) {
      await _voiceService.stopListening();
      setState(() { _isListeningName = false; _isListeningSize = false; _isListeningWater = false; });
      return;
    }
    final hasPermission = await _voiceService.initialize();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied'), backgroundColor: Color(0xFFEF4444)),
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
      localeId: 'en_US',
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
          final mapped = VoiceService.extractValue(text, VoiceField.farmingMethod);
          setState(() => _farmingMethod = mapped);
          _emitData();
        }
      },
      onListeningComplete: () {
        if (mounted) setState(() { _isListeningName = false; _isListeningSize = false; _isListeningWater = false; });
      },
    );
  }

  void _showSoilScanDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2332),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'AI Soil Scan',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                'Capture or upload a soil image for AI analysis.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF4CAF50)),
                title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _analyzeSoil('camera');
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF4CAF50)),
                title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _analyzeSoil('gallery');
                },
              ),
              if (_soilAiResult != null)
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
                  title: const Text('View Previous Result', style: TextStyle(color: Colors.white)),
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
    setState(() => _isAnalyzingSoil = true);

    _showAnalyzingDialog();

    try {
      await AiService.instance.loadConfig();

      final soilType = _soilType.isNotEmpty ? _soilType : 'Not specified';
      final locationStr = _farmLocation != null
          ? _farmLocation!.fullAddress
          : 'Not provided';
      final moisture = _waterAvailability.isNotEmpty ? _waterAvailability : 'Not measured';

      final additionalData = <String, dynamic>{};
      if (_irrigationType.isNotEmpty) additionalData['irrigationType'] = _irrigationType;
      if (_waterSource.isNotEmpty) additionalData['waterSource'] = _waterSource;
      if (_farmingMethod.isNotEmpty) additionalData['farmingMethod'] = _farmingMethod;
      if (_sizeController.text.trim().isNotEmpty) {
        additionalData['farmSize'] = '${_sizeController.text.trim()} $_sizeUnit';
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
              content: Text('AI analysis failed: ${response.error ?? "Unknown error"}'),
              backgroundColor: const Color(0xFFEF4444),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Soil analysis error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
      return;
    }

    setState(() => _isAnalyzingSoil = false);
  }

  void _showAnalyzingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const CircularProgressIndicator(color: Color(0xFF4CAF50), strokeWidth: 3),
            const SizedBox(height: 20),
            const Text(
              'Analyzing Soil...',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'VidhAI is analyzing your soil data.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        title: const Text('AI Soil Analysis', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resultRow('Soil Type', r.soilType),
            _resultRow('Confidence', r.confidence > 0 ? '${(r.confidence * 100).round()}%' : 'Pending'),
            _resultRow('Characteristics', r.characteristics),
            _resultRow('Suitability', r.suitability),
            _resultRow('Observations', r.observations),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF4CAF50))),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Card(
      color: const Color(0xFF111827),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('${widget.farmIndex}',
                          style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('${loc.farmCard} ${widget.farmIndex}',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildFieldWithVoice(
                controller: _nameController, label: loc.farmName,
                icon: Icons.landscape_rounded, onChanged: (_) => _emitData(),
                validator: (v) => v == null || v.trim().isEmpty ? loc.requiredField : null,
                isListening: _isListeningName,
                onVoiceTap: () => _startVoiceInput(VoiceField.farmName),
              ),
              const SizedBox(height: 12),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Expanded(flex: 3, child: _buildFieldWithVoice(
                  controller: _sizeController, label: loc.farmSize,
                  icon: Icons.straighten_rounded, keyboardType: TextInputType.number,
                  onChanged: (_) => _emitData(),
                  validator: (v) => v == null || v.trim().isEmpty ? loc.requiredField : null,
                  isListening: _isListeningSize,
                  onVoiceTap: () => _startVoiceInput(VoiceField.farmSize),
                )),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _buildUnitDropdown()),
              ]),
              const SizedBox(height: 12),
              _buildLocationField(loc),
              const SizedBox(height: 12),
              _buildDropdown(
                value: _irrigationType.isEmpty ? null : _irrigationType,
                label: loc.irrigationType, icon: Icons.water_drop_outlined,
                items: _irrigationTypes,
                onChanged: (v) { setState(() => _irrigationType = v ?? ''); _emitData(); },
                validator: (v) => v == null || v.isEmpty ? loc.requiredField : null,
              ),
              const SizedBox(height: 12),
              _buildDropdown(
                value: _waterSource.isEmpty ? null : _waterSource,
                label: loc.waterSource, icon: Icons.water_outlined,
                items: _waterSources,
                onChanged: (v) { setState(() => _waterSource = v ?? ''); _emitData(); },
                validator: (v) => v == null || v.isEmpty ? loc.requiredField : null,
              ),
              const SizedBox(height: 12),
              _buildWaterAvailability(loc),
              const SizedBox(height: 12),
              _buildSoilSection(loc),
              const SizedBox(height: 12),
              _buildDropdown(
                value: _farmingMethod.isEmpty ? null : _farmingMethod,
                label: 'Farming Method', icon: Icons.agriculture_rounded,
                items: _farmingMethods,
                onChanged: (v) { setState(() => _farmingMethod = v ?? ''); _emitData(); },
                validator: (v) => null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldWithVoice({
    required TextEditingController controller, required String label,
    required IconData icon, TextInputType? keyboardType,
    String? Function(String?)? validator, void Function(String)? onChanged,
    required bool isListening, required VoidCallback onVoiceTap,
  }) {
    return Row(children: [
      Expanded(child: _buildField(
        controller: controller, label: label, icon: icon,
        keyboardType: keyboardType, validator: validator, onChanged: onChanged,
      )),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: onVoiceTap,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: isListening ? const Color(0xFFEF4444).withValues(alpha: 0.2) : const Color(0xFF4CAF50).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(isListening ? Icons.mic : Icons.mic_none_rounded,
              color: isListening ? const Color(0xFFEF4444) : const Color(0xFF4CAF50), size: 20),
        ),
      ),
    ]);
  }

  Widget _buildField({
    required TextEditingController controller, required String label,
    required IconData icon, TextInputType? keyboardType,
    String? Function(String?)? validator, void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller, keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      onChanged: onChanged, validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.45)),
        filled: true, fillColor: const Color(0xFF1A2332),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444))),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
        errorStyle: const TextStyle(color: Color(0xFFEF4444)),
      ),
    );
  }

  Widget _buildUnitDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _sizeUnit, style: const TextStyle(color: Colors.white, fontSize: 15),
      dropdownColor: const Color(0xFF1A2332),
      decoration: InputDecoration(
        filled: true, fillColor: const Color(0xFF1A2332),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5)),
      ),
      items: _sizeUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
      onChanged: (v) { setState(() => _sizeUnit = v ?? 'Acre'); _emitData(); },
    );
  }

  Widget _buildWaterAvailability(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.water_drop_outlined, color: Colors.white.withValues(alpha: 0.45), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(loc.waterAvailability,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14, fontWeight: FontWeight.w500))),
          GestureDetector(
            onTap: () => _startVoiceInput(VoiceField.waterAvailability),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _isListeningWater
                    ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                    : const Color(0xFF4CAF50).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_isListeningWater ? Icons.mic : Icons.mic_none_rounded,
                  color: _isListeningWater ? const Color(0xFFEF4444) : const Color(0xFF4CAF50), size: 16),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _waterLevels.map((level) {
            final isSelected = _waterAvailability == level;
            final color = _waterLevelColor(level);
            return GestureDetector(
              onTap: () { setState(() => _waterAvailability = level); _emitData(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.2) : const Color(0xFF1A2332),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? color : Colors.white.withValues(alpha: 0.08),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(level,
                    style: TextStyle(
                      color: isSelected ? color : Colors.white.withValues(alpha: 0.6),
                      fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    )),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _waterLevelColor(String level) {
    switch (level) {
      case 'High': return const Color(0xFF2196F3);
      case 'Medium': return const Color(0xFF4CAF50);
      case 'Low': return const Color(0xFFFF9800);
      case 'Very Low': return const Color(0xFFFF5722);
      case 'No Water': return const Color(0xFFEF4444);
      default: return const Color(0xFF4CAF50);
    }
  }

  Widget _buildSoilSection(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.terrain_rounded, color: Colors.white.withValues(alpha: 0.45), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(loc.soilType,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14, fontWeight: FontWeight.w500))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _soilType.isEmpty ? null : _soilType,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              dropdownColor: const Color(0xFF1A2332),
              decoration: InputDecoration(
                labelText: 'Manual Select', labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
                prefixIcon: Icon(Icons.terrain_rounded, color: Colors.white.withValues(alpha: 0.45)),
                filled: true, fillColor: const Color(0xFF1A2332),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5)),
              ),
              items: _soilTypes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) { setState(() => _soilType = v ?? ''); _emitData(); },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isAnalyzingSoil ? null : _showSoilScanDialog,
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _isAnalyzingSoil
                    ? const Color(0xFFFF9800).withValues(alpha: 0.15)
                    : const Color(0xFF4CAF50).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isAnalyzingSoil
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF9800)),
                    )
                  : const Icon(Icons.camera_alt_rounded, color: Color(0xFF4CAF50), size: 20),
            ),
          ),
        ]),
        if (_soilAiResult != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showSoilResult,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2332),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF4CAF50), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'AI Result: ${_soilAiResult!.soilType}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  )),
                  Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3), size: 16),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationField(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _locationController, style: const TextStyle(color: Colors.white, fontSize: 15),
          onChanged: _searchLocation,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return loc.requiredField;
            if (_farmLocation == null || !_farmLocation!.isVerified) return loc.selectFromSuggestions;
            return null;
          },
          decoration: InputDecoration(
            labelText: loc.farmLocation,
            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
            prefixIcon: Icon(Icons.location_on_outlined, color: Colors.white.withValues(alpha: 0.45)),
            suffixIcon: _isSearchingLocation || _isGettingCurrentLocation
                ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4CAF50))))
                : _farmLocation != null && _farmLocation!.isVerified
                    ? const Icon(Icons.verified, color: Color(0xFF4CAF50), size: 20) : null,
            filled: true, fillColor: const Color(0xFF1A2332),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444))),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
            errorStyle: const TextStyle(color: Color(0xFFEF4444)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isGettingCurrentLocation ? null : _useCurrentLocation,
            icon: _isGettingCurrentLocation
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4CAF50)))
                : const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF4CAF50)),
            label: Text(_isGettingCurrentLocation ? 'Getting location...' : 'Use Current Location',
                style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 13)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              side: BorderSide(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        if (_locationSuggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2332), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: ListView.builder(
              shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _locationSuggestions.length,
              itemBuilder: (context, i) {
                final s = _locationSuggestions[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on_outlined, color: Color(0xFF4CAF50), size: 20),
                  title: Text(s.displayText, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  onTap: () => _selectLocation(s),
                );
              },
            ),
          ),
        if (_farmLocation != null && _farmLocation!.isVerified) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.verified, color: Color(0xFF4CAF50), size: 14),
            const SizedBox(width: 4),
            Expanded(child: Text(
              '${_farmLocation!.city ?? ''} ${_farmLocation!.state ?? ''} ${_farmLocation!.country ?? ''}'.trim(),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
            )),
          ]),
        ],
      ],
    );
  }

  Widget _buildDropdown({
    required String? value, required String label, required IconData icon,
    required List<String> items, required void Function(String?) onChanged,
    required String? Function(String?) validator,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value, style: const TextStyle(color: Colors.white, fontSize: 15),
      dropdownColor: const Color(0xFF1A2332),
      decoration: InputDecoration(
        labelText: label, labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.45)),
        filled: true, fillColor: const Color(0xFF1A2332),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444))),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
        errorStyle: const TextStyle(color: Color(0xFFEF4444)),
      ),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged, validator: validator,
    );
  }
}
