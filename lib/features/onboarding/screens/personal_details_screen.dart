import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:vidhai/core/bloc/auth_bloc.dart';
import 'package:vidhai/core/bloc/auth_event.dart';
import 'package:vidhai/core/bloc/auth_state.dart';
import 'package:vidhai/data/models/user_profile.dart';
import 'package:vidhai/services/voice_service.dart';
import 'package:vidhai/services/location_service.dart';
import 'package:vidhai/locale/locale.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _voiceService = VoiceService();
  final _locationService = LocationService();

  String _selectedGender = '';
  DateTime? _dateOfBirth;
  int _age = 0;
  AddressData? _verifiedAddress;
  List<AddressSearchResult> _locationSuggestions = [];
  bool _isSearchingLocation = false;
  bool _isLoading = false;
  bool _isListening = false;
  VoiceField _listeningField = VoiceField.none;
  File? _avatarFile;
  String? _domain;

  static const _genderValues = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadDomain();
    _voiceService.initialize();
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
    _nameController.dispose();
    _addressController.dispose();
    _voiceService.stopListening();
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
    final source = await showModalBottomSheet<ImageSource>(
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
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF4CAF50)),
                title: Text(loc.takePhoto,
                    style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading:
                    const Icon(Icons.photo_library, color: Color(0xFF4CAF50)),
                title: Text(loc.chooseFromGallery,
                    style: const TextStyle(color: Colors.white)),
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

  Future<void> _startVoiceInput(VoiceField field) async {
    final loc = AppLocalizations.of(context);

    if (_isListening) {
      await _voiceService.stopListening();
      setState(() {
        _isListening = false;
        _listeningField = VoiceField.none;
      });
      return;
    }

    final hasPermission = await _voiceService.initialize();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.permissionDenied),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isListening = true;
      _listeningField = field;
    });

    final langCode = Localizations.localeOf(context).languageCode;
    final localeId = VoiceService.getLocaleForLanguage(langCode);

    await _voiceService.startListening(
      localeId: localeId,
      onResult: (text, confidence) {
        _applyVoiceResult(text, field, confidence);
      },
      onListeningComplete: () {
        if (mounted) {
          setState(() {
            _isListening = false;
            _listeningField = VoiceField.none;
          });
        }
      },
    );
  }

  void _applyVoiceResult(String text, VoiceField field, double confidence) {
    if (confidence < 0.5 && field == VoiceField.name) {
      // Low confidence for name — show retry prompt
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Low confidence (${(confidence * 100).toInt()}%). Please try speaking again.',
          ),
          backgroundColor: const Color(0xFFFF9800),
          action: SnackBarAction(
            label: 'Use anyway',
            textColor: Colors.white,
            onPressed: () {
              final value = VoiceService.extractValue(text, field);
              if (value.isNotEmpty && field == VoiceField.name) {
                _nameController.text = value;
              }
            },
          ),
          duration: const Duration(seconds: 3),
        ));
      }
      return;
    }

    switch (field) {
      case VoiceField.name:
        final value = VoiceService.extractValue(text, VoiceField.name);
        if (value.isNotEmpty) _nameController.text = value;
        break;
      case VoiceField.gender:
        final value = VoiceService.extractValue(text, VoiceField.gender);
        if (value.isNotEmpty &&
            _genderValues.any((g) => g.toLowerCase() == value.toLowerCase())) {
          setState(() => _selectedGender = value);
        }
        break;
      case VoiceField.dateOfBirth:
        final value = VoiceService.extractValue(text, VoiceField.dateOfBirth);
        _parseAndSetDOB(value);
        break;
      case VoiceField.age:
        final value = VoiceService.extractValue(text, VoiceField.age);
        final ageNum = int.tryParse(value);
        if (ageNum != null && ageNum > 0 && ageNum < 120) {
          setState(() {
            _age = ageNum;
            _dateOfBirth = DateTime(DateTime.now().year - ageNum, 1, 1);
          });
        }
        break;
      case VoiceField.address:
        final value = VoiceService.extractValue(text, VoiceField.address);
        if (value.isNotEmpty) {
          _addressController.text = value;
          _searchLocation(value);
        }
        break;
      default:
        break;
    }
  }

  void _parseAndSetDOB(String text) {
    final formats = [
      DateFormat('d MMMM yyyy'),
      DateFormat('dd MMMM yyyy'),
      DateFormat('d MMM yyyy'),
      DateFormat('dd MMM yyyy'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('d/MM/yyyy'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('d-MM-yyyy'),
    ];
    for (final fmt in formats) {
      try {
        final parsed = fmt.parse(text);
        setState(() => _dateOfBirth = parsed);
        _calculateAge();
        return;
      } catch (_) {}
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

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
      prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.45)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF1A2332),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      errorStyle: const TextStyle(color: Color(0xFFEF4444)),
    );
  }

  Widget _buildVoiceButton(VoiceField field) {
    final isActive = _isListening && _listeningField == field;
    return GestureDetector(
      onTap: () => _startVoiceInput(field),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFEF4444).withValues(alpha: 0.2)
              : const Color(0xFF4CAF50).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          isActive ? Icons.mic : Icons.mic_none_rounded,
          color: isActive ? const Color(0xFFEF4444) : const Color(0xFF4CAF50),
          size: 18,
        ),
      ),
    );
  }

  void _goBack() {
    Navigator.of(context).pushReplacementNamed('/domain_selection');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0F1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A0F1A),
          elevation: 0,
          leading: IconButton(
            icon:
                const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: _goBack,
          ),
          title: Text(
            loc.personalDetails,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          actions: [
            _buildGlobalVoiceButton(loc),
            const SizedBox(width: 8),
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
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(state.errorMessage ?? 'Error'),
                backgroundColor: const Color(0xFFEF4444),
              ));
            }
          },
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 8),
                _buildAvatarSection(loc),
                const SizedBox(height: 24),
                _buildNameField(loc),
                const SizedBox(height: 16),
                _buildGenderField(loc),
                const SizedBox(height: 16),
                _buildDOBField(loc),
                const SizedBox(height: 16),
                _buildAgeField(loc),
                const SizedBox(height: 16),
                _buildAddressField(loc),
                const SizedBox(height: 32),
                _buildSubmitButton(loc),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalVoiceButton(AppLocalizations loc) {
    final isActive = _isListening && _listeningField == VoiceField.none;
    return GestureDetector(
      onTap: () async {
        if (_isListening) {
          await _voiceService.stopListening();
          setState(() {
            _isListening = false;
            _listeningField = VoiceField.none;
          });
          return;
        }
        final hasPermission = await _voiceService.initialize();
        if (!hasPermission) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(loc.permissionDenied),
              backgroundColor: const Color(0xFFEF4444),
            ));
          }
          return;
        }
        if (!mounted) return;
        setState(() {
          _isListening = true;
          _listeningField = VoiceField.none;
        });
        final langCode = Localizations.localeOf(context).languageCode;
        await _voiceService.startListening(
          localeId: VoiceService.getLocaleForLanguage(langCode),
          onResult: (text, confidence) {
            final field = VoiceService.classifySpeech(text);
            if (field != VoiceField.none) {
              _applyVoiceResult(text, field, confidence);
            }
          },
          onListeningComplete: () {
            if (mounted) {
              setState(() {
                _isListening = false;
                _listeningField = VoiceField.none;
              });
            }
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFEF4444).withValues(alpha: 0.2)
              : const Color(0xFF4CAF50).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.mic : Icons.mic_none_rounded,
              color:
                  isActive ? const Color(0xFFEF4444) : const Color(0xFF4CAF50),
              size: 18,
            ),
            const SizedBox(width: 4),
            Text(
              isActive ? loc.listening : loc.voiceInput,
              style: TextStyle(
                color: isActive
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF4CAF50),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection(AppLocalizations loc) {
    return Center(
      child: GestureDetector(
        onTap: _pickAvatar,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 56,
              backgroundColor: const Color(0xFF1A2332),
              backgroundImage:
                  _avatarFile != null ? FileImage(_avatarFile!) : null,
              child: _avatarFile == null
                  ? Icon(
                      _domain == 'farmer'
                          ? Icons.agriculture_rounded
                          : Icons.shopping_cart_rounded,
                      size: 50,
                      color: _domain == 'farmer'
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFF9800),
                    )
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.camera_alt, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField(AppLocalizations loc) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: _inputDecoration(
                label: loc.fullName, icon: Icons.person_outline_rounded),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return loc.requiredField;
              if (v.trim().length < 2) return loc.requiredField;
              return null;
            },
          ),
        ),
        const SizedBox(width: 8),
        _buildVoiceButton(VoiceField.name),
      ],
    );
  }

  Widget _buildGenderField(AppLocalizations loc) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _selectedGender.isEmpty ? null : _selectedGender,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            dropdownColor: const Color(0xFF1A2332),
            decoration:
                _inputDecoration(label: loc.gender, icon: Icons.wc_outlined),
            items: _genderValues
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) => setState(() => _selectedGender = v ?? ''),
            validator: (v) => v == null || v.isEmpty ? loc.requiredField : null,
          ),
        ),
        const SizedBox(width: 8),
        _buildVoiceButton(VoiceField.gender),
      ],
    );
  }

  Widget _buildDOBField(AppLocalizations loc) {
    final displayText = _dateOfBirth != null
        ? DateFormat('dd MMMM yyyy').format(_dateOfBirth!)
        : '';

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _pickDate,
            child: AbsorbPointer(
              child: TextFormField(
                controller: TextEditingController(text: displayText),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: _inputDecoration(
                  label: loc.dateOfBirth,
                  icon: Icons.cake_outlined,
                  suffixIcon: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.calendar_today,
                        color: Color(0xFF4CAF50), size: 18),
                  ),
                ),
                validator: (v) =>
                    _dateOfBirth == null ? loc.requiredField : null,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildVoiceButton(VoiceField.dateOfBirth),
      ],
    );
  }

  Widget _buildAgeField(AppLocalizations loc) {
    return TextFormField(
      controller: TextEditingController(text: _age > 0 ? '$_age' : ''),
      readOnly: true,
      style: TextStyle(
        color: _age > 0 ? Colors.white : Colors.white38,
        fontSize: 15,
      ),
      decoration: _inputDecoration(
        label: loc.ageCalculated,
        icon: Icons.numbers_rounded,
      ),
    );
  }

  Widget _buildAddressField(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _addressController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                onChanged: _searchLocation,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return loc.requiredField;
                  if (_verifiedAddress == null ||
                      !_verifiedAddress!.isVerified) {
                    return loc.selectFromSuggestions;
                  }
                  return null;
                },
                decoration: _inputDecoration(
                  label: loc.searchAddress,
                  icon: Icons.location_on_outlined,
                  suffixIcon: _isSearchingLocation
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                        )
                      : _verifiedAddress != null && _verifiedAddress!.isVerified
                          ? const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(Icons.verified,
                                  color: Color(0xFF4CAF50), size: 20),
                            )
                          : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildVoiceButton(VoiceField.address),
          ],
        ),
        if (_locationSuggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2332),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _locationSuggestions.length,
              itemBuilder: (context, i) {
                final s = _locationSuggestions[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on_outlined,
                      color: Color(0xFF4CAF50), size: 20),
                  title: Text(s.displayText,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13)),
                  onTap: () => _selectLocation(s),
                );
              },
            ),
          ),
        if (_verifiedAddress != null && _verifiedAddress!.isVerified) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.verified, color: Color(0xFF4CAF50), size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${_verifiedAddress!.city ?? ''} ${_verifiedAddress!.state ?? ''} ${_verifiedAddress!.country ?? ''}'
                      .trim(),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSubmitButton(AppLocalizations loc) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              const Color(0xFF4CAF50).withValues(alpha: 0.5),
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
