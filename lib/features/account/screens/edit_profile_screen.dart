import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/services/voice_service.dart';
import 'package:vidhai/services/location_service.dart';
import 'package:vidhai/data/models/user_profile.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final DataService _dataService = DataService();
  final VoiceService _voiceService = VoiceService();
  final LocationService _locationService = LocationService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  String _gender = '';
  DateTime? _dateOfBirth;
  int _age = 0;
  AddressData? _address;
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isListening = false;

  static const Color _bgColor = Color(0xFF0A0F1A);
  static const Color _cardColor = Color(0xFF111827);
  static const Color _accent = Color(0xFF4CAF50);
  static const Color _danger = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _dataService.loadCachedProfile();
    if (mounted && profile != null) {
      setState(() {
        _profile = profile;
        _nameController.text = profile.displayName;
        _emailController.text = profile.email;
        _gender = profile.gender;
        _dateOfBirth = profile.dateOfBirth;
        _age = profile.age;
        _ageController.text = _age > 0 ? '$_age' : '';
        _address = profile.address;
        if (profile.address != null) {
          _addressController.text = profile.address!.fullAddress;
        }
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int calculatedAge = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      calculatedAge--;
    }
    return calculatedAge;
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _accent,
              surface: _cardColor,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
        _age = _calculateAge(picked);
        _ageController.text = _age > 0 ? '$_age' : '';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Location permission denied'),
                backgroundColor: _danger,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
          return;
        }
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location services are disabled'),
              backgroundColor: _danger,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
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
        final fullAddress = parts.isNotEmpty ? parts.join(', ') : '';

        setState(() {
          _addressController.text = fullAddress;
          _address = AddressData(
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
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location detected successfully'),
            backgroundColor: _accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to get current location'),
            backgroundColor: _danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _startVoiceInput() async {
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() => _isListening = false);
      return;
    }

    final initialized = await _voiceService.initialize();
    if (!initialized || !_voiceService.isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Voice input not available'),
            backgroundColor: _danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isListening = true);
    await _voiceService.startListening(
      localeId: 'en_US',
      onResult: (text, confidence) {
        setState(() {
          _nameController.text = text;
          _nameController.selection = TextSelection.fromPosition(
            TextPosition(offset: _nameController.text.length),
          );
        });
      },
      onListeningComplete: () {
        if (mounted) setState(() => _isListening = false);
      },
    );
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Name cannot be empty'),
          backgroundColor: _danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final updated = UserProfile(
      uid: _profile?.uid ?? '',
      email: _profile?.email ?? _emailController.text,
      displayName: _nameController.text.trim(),
      gender: _gender,
      dateOfBirth: _dateOfBirth,
      age: _age,
      address: _address,
      avatarUrl: _profile?.avatarUrl,
      role: _profile?.role ?? 'farmer',
      isEmailVerified: _profile?.isEmailVerified ?? false,
    );

    await _dataService.saveProfile(updated);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile saved successfully'),
          backgroundColor: _accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  String _getInitial() {
    final name = _nameController.text;
    if (name.isNotEmpty) return name[0].toUpperCase();
    final email = _emailController.text;
    if (email.isNotEmpty) return email[0].toUpperCase();
    return 'U';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: _accent,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: _cardColor,
                        child: Text(
                          _getInitial(),
                          style: const TextStyle(
                            color: _accent,
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: _accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _buildLabel('Name'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _nameController,
                  hint: 'Enter your name',
                  suffix: IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? _accent : Colors.white.withValues(alpha: 0.5),
                    ),
                    onPressed: _startVoiceInput,
                  ),
                ),
                const SizedBox(height: 20),
                _buildLabel('Email'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _emailController,
                  hint: 'Email',
                  readOnly: true,
                  suffix: _profile?.isEmailVerified == true
                      ? const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Icon(Icons.verified, color: _accent, size: 20),
                        )
                      : null,
                ),
                const SizedBox(height: 20),
                _buildLabel('Gender'),
                const SizedBox(height: 8),
                _buildGenderDropdown(),
                const SizedBox(height: 20),
                _buildLabel('Date of Birth'),
                const SizedBox(height: 8),
                _buildDateField(),
                const SizedBox(height: 20),
                _buildLabel('Age'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _ageController,
                  hint: 'Age (auto-calculated)',
                  readOnly: true,
                ),
                const SizedBox(height: 20),
                _buildLabel('Current Address'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _addressController,
                  hint: 'Enter your address',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.my_location, color: _accent, size: 20),
                    label: const Text(
                      'Use Current Location',
                      style: TextStyle(
                        color: _accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _accent.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool readOnly = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        filled: true,
        fillColor: _cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accent, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: suffix,
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _gender.isNotEmpty ? _gender : null,
          hint: Text(
            'Select gender',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          ),
          isExpanded: true,
          dropdownColor: _cardColor,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          items: const [
            DropdownMenuItem(value: 'Male', child: Text('Male')),
            DropdownMenuItem(value: 'Female', child: Text('Female')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (value) {
            setState(() => _gender = value ?? '');
          },
        ),
      ),
    );
  }

  Widget _buildDateField() {
    final displayText = _dateOfBirth != null
        ? '${_dateOfBirth!.day.toString().padLeft(2, '0')}/${_dateOfBirth!.month.toString().padLeft(2, '0')}/${_dateOfBirth!.year}'
        : '';

    return GestureDetector(
      onTap: _pickDateOfBirth,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayText.isNotEmpty ? displayText : 'Select date of birth',
                style: TextStyle(
                  color: displayText.isNotEmpty
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                  fontSize: 15,
                ),
              ),
            ),
            Icon(
              Icons.calendar_today,
              color: Colors.white.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
