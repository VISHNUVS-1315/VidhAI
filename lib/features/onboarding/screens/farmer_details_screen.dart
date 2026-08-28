import 'package:flutter/material.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/features/onboarding/widgets/farm_card.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/locale/locale.dart';

class FarmerDetailsScreen extends StatefulWidget {
  const FarmerDetailsScreen({super.key});

  @override
  State<FarmerDetailsScreen> createState() => _FarmerDetailsScreenState();
}

class _FarmerDetailsScreenState extends State<FarmerDetailsScreen> {
  int _numberOfFarms = 0;
  final Map<int, FarmProfile> _farmData = {};
  bool _isLoading = false;

  void _incrementFarms() {
    setState(() => _numberOfFarms++);
  }

  void _decrementFarms() {
    if (_numberOfFarms <= 0) return;

    if (_numberOfFarms == 1) {
      setState(() {
        _numberOfFarms = 0;
        _farmData.remove(1);
      });
      return;
    }

    final loc = AppLocalizations.of(context);
    final farmsWithData = <int>[];
    for (var i = 1; i <= _numberOfFarms; i++) {
      final farm = _farmData[i];
      if (farm != null && farm.isComplete) {
        farmsWithData.add(i);
      }
    }

    final newCount = _numberOfFarms - 1;
    final farmsToRemove = <int>[];
    for (var i = newCount + 1; i <= _numberOfFarms; i++) {
      farmsToRemove.add(i);
    }

    final hasDataToRemove = farmsToRemove.any((i) =>
        _farmData.containsKey(i) &&
        _farmData[i] != null &&
        _farmData[i]!.farmName.isNotEmpty);

    if (hasDataToRemove) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A2332),
          title: Text(
            loc.confirmDeleteFarm,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Text(
            'Farm ${farmsToRemove.join(', ')} data will be removed.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.cancel,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _applyDecrement(newCount, farmsToRemove);
              },
              child:
                  const Text('OK', style: TextStyle(color: Color(0xFF4CAF50))),
            ),
          ],
        ),
      );
    } else {
      _applyDecrement(newCount, farmsToRemove);
    }
  }

  void _applyDecrement(int newCount, List<int> farmsToRemove) {
    for (final i in farmsToRemove) {
      _farmData.remove(i);
    }
    setState(() => _numberOfFarms = newCount);
  }

  void _onFarmDataChanged(int index, FarmProfile data) {
    debugPrint(
        'FarmCard [$index] data changed: name=${data.farmName}, size=${data.farmSize}, complete=${data.isComplete}');
    _farmData[index] = data;
  }

  bool _validateAllFarms() {
    debugPrint(
        'Validating farms: count=$_numberOfFarms, farmData keys=${_farmData.keys.toList()}');
    for (var i = 1; i <= _numberOfFarms; i++) {
      final farm = _farmData[i];
      if (farm == null) {
        debugPrint('Farm $i: NULL - not yet filled');
        return false;
      }
      if (!farm.isComplete) {
        debugPrint(
            'Farm $i: INCOMPLETE - name=${farm.farmName}, size=${farm.farmSize}, loc=${farm.farmLocation != null}, irr=${farm.irrigationType}, ws=${farm.waterSource}, soil=${farm.soilType}, wa=${farm.waterAvailability}');
        return false;
      }
    }
    debugPrint('All $_numberOfFarms farms are COMPLETE');
    return true;
  }

  Future<void> _submitFarmData() async {
    debugPrint('[FarmSave] Button pressed');
    if (!_validateAllFarms()) {
      debugPrint('[FarmSave] Validation FAILED — showing field error');
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(loc.requiredField),
        backgroundColor: const Color(0xFFEF4444),
      ));
      return;
    }
    debugPrint('[FarmSave] Validation PASSED');

    setState(() => _isLoading = true);
    debugPrint('[FarmSave] Loading state set');

    final farms = <Map<String, dynamic>>[];
    for (var i = 1; i <= _numberOfFarms; i++) {
      final map = _farmData[i]!.toMap();
      farms.add(map);
      debugPrint(
          '[FarmSave] Farm $i model created: name=${map['farmName']}, size=${map['farmSize']}, location=${map['farmLocation'] != null}');
    }
    debugPrint('[FarmSave] All ${farms.length} farm models created');

    try {
      debugPrint('[FarmSave] Creating FarmProfile objects from maps...');
      final profileFarms = <FarmProfile>[];
      for (final m in farms) {
        try {
          profileFarms.add(FarmProfile.fromMap(Map<String, dynamic>.from(m)));
          debugPrint('[FarmSave]   FarmProfile.fromMap OK: ${m['farmName']}');
        } catch (e, st) {
          debugPrint('[FarmSave]   FarmProfile.fromMap FAILED: $e');
          debugPrint('[FarmSave]   Stack: $st');
          rethrow;
        }
      }
      debugPrint(
          '[FarmSave] FarmProfile objects created: ${profileFarms.length}');

      debugPrint('[FarmSave] Calling DataService().saveFarms()...');
      try {
        await DataService().saveFarms(profileFarms);
        debugPrint('[FarmSave] DataService().saveFarms() COMPLETED');
      } catch (e, st) {
        debugPrint('[FarmSave] DataService().saveFarms() FAILED: $e');
        debugPrint('[FarmSave] Stack: $st');
        rethrow;
      }

      debugPrint(
          '[FarmSave] Calling DataService().setOnboardingComplete(true)...');
      try {
        await DataService().setOnboardingComplete(true);
        debugPrint('[FarmSave] setOnboardingComplete(true) COMPLETED');
      } catch (e, st) {
        debugPrint('[FarmSave] setOnboardingComplete FAILED: $e');
        debugPrint('[FarmSave] Stack: $st');
      }

      debugPrint('[FarmSave] Checking mounted: $mounted');
      if (mounted) {
        debugPrint('[FarmSave] NAVIGATING to /main_shell');
        Navigator.of(context).pushReplacementNamed('/main_shell');
        debugPrint('[FarmSave] Navigator.pushReplacementNamed called');
      } else {
        debugPrint('[FarmSave] Widget NOT mounted — cannot navigate');
      }
    } catch (e, st) {
      debugPrint('[FarmSave] TOP-LEVEL EXCEPTION: $e');
      debugPrint('[FarmSave] Stack: $st');
      if (mounted) {
        debugPrint('[FarmSave] Forcing onboarding complete despite error');
        try {
          await DataService().setOnboardingComplete(true);
        } catch (_) {}
        if (mounted) {
          debugPrint('[FarmSave] Force navigating to /main_shell');
          Navigator.of(context).pushReplacementNamed('/main_shell');
        }
      }
    }
  }

  void _goBack() {
    Navigator.of(context).pushReplacementNamed('/personal_details');
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
            loc.farmDetails,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 8),
            _buildFarmCountSelector(loc),
            if (_numberOfFarms > 0) ...[
              const SizedBox(height: 24),
              ...List.generate(_numberOfFarms, (i) {
                final farmIndex = i + 1;
                return FarmCard(
                  key: ValueKey('farm_$farmIndex'),
                  farmIndex: farmIndex,
                  totalFarms: _numberOfFarms,
                  initialData: _farmData[farmIndex],
                  onDataChanged: (data) => _onFarmDataChanged(farmIndex, data),
                );
              }),
            ],
            const SizedBox(height: 16),
            if (_numberOfFarms > 0) _buildSubmitButton(loc),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmCountSelector(AppLocalizations loc) {
    return Card(
      color: const Color(0xFF111827),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.agriculture_rounded,
                      color: Color(0xFF4CAF50), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    loc.selectNumberOfFarms,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2332),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStepperButton(
                      icon: Icons.remove_rounded,
                      onTap: _decrementFarms,
                    ),
                    Container(
                      width: 80,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_numberOfFarms',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            loc.numberOfFarms,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStepperButton(
                      icon: Icons.add_rounded,
                      onTap: _incrementFarms,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF4CAF50),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildSubmitButton(AppLocalizations loc) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitFarmData,
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
                loc.completeProfileForm,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
