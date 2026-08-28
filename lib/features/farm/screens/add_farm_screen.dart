import 'package:flutter/material.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/features/onboarding/widgets/farm_card.dart';

class AddFarmScreen extends StatefulWidget {
  const AddFarmScreen({super.key});

  @override
  State<AddFarmScreen> createState() => _AddFarmScreenState();
}

class _AddFarmScreenState extends State<AddFarmScreen> {
  FarmProfile? _farmProfile;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add New Farm',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          FarmCard(
            farmIndex: 1,
            totalFarms: 1,
            onDataChanged: (profile) {
              setState(() {
                _farmProfile = profile;
              });
            },
          ),
        ],
      ),
      bottomSheet: Container(
        color: const Color(0xFF0A0F1A),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveFarm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    'Save Farm',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveFarm() async {
    if (_farmProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill in the farm details'),
          backgroundColor: const Color(0xFFFF9800),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (_farmProfile!.farmName.isEmpty ||
        _farmProfile!.farmSize.isEmpty ||
        _farmProfile!.farmLocation == null ||
        !_farmProfile!.farmLocation!.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Please fill in farm name, size, and select a verified location'),
          backgroundColor: const Color(0xFFFF9800),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final dataService = DataService();
      final existingFarms = await dataService.loadFarms();
      final newFarm = FarmProfile(
        farmId: dataService.generateId(),
        index: existingFarms.length,
        farmName: _farmProfile!.farmName,
        farmSize: _farmProfile!.farmSize,
        farmSizeUnit: _farmProfile!.farmSizeUnit,
        farmLocation: _farmProfile!.farmLocation,
        irrigationType: _farmProfile!.irrigationType,
        waterSource: _farmProfile!.waterSource,
        soilType: _farmProfile!.soilType,
        waterAvailability: _farmProfile!.waterAvailability,
        farmingMethod: _farmProfile!.farmingMethod,
      );

      await dataService.addFarm(newFarm);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_farmProfile!.farmName} saved successfully!'),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving farm: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
