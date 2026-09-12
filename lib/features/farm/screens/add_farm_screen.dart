import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/features/onboarding/widgets/farm_card.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/features/assistant/assistant_button.dart';
import 'package:vidhai/features/assistant/assistant_field_registry.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';

class AddFarmScreen extends StatefulWidget {
  final FarmProfile? initialFarm;

  const AddFarmScreen({super.key, this.initialFarm});

  @override
  State<AddFarmScreen> createState() => _AddFarmScreenState();
}

class _AddFarmScreenState extends State<AddFarmScreen> {
  FarmProfile? _farmProfile;
  bool _isSaving = false;

  bool get _isEditing => widget.initialFarm != null;

  @override
  void initState() {
    super.initState();
    AssistantFieldRegistry.instance.registerAction(
        'add_farm',
        AssistantActionEntry(
          action: 'submit_farm',
          label: 'Save the farm',
          requiresConfirmation: true,
          confirmLabelKey: 'save',
          cancelLabelKey: 'review',
          run: (args) async {
            if (!mounted) return {'error': 'Screen not active.'};
            final ok = await _saveFarm();
            return ok
                ? {'saved': true}
                : {
                    'error':
                        'Farm could not be saved. Check the required fields.'
                  };
          },
        ));
  }

  @override
  void dispose() {
    AssistantFieldRegistry.instance.unregisterAction('add_farm', 'submit_farm');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(directionalIcon(context, Icons.arrow_back_ios_rounded),
              color: colors.onBackground, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? loc.editFarm : loc.addNewFarm,
          style: TextStyle(
            color: colors.onBackground,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          const VidhAIAssistantButton(
              screen: 'add_farm', size: 36, iconSize: 18),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          FarmCard(
            farmIndex: (widget.initialFarm?.index ?? 0) + 1,
            totalFarms: 1,
            initialData: widget.initialFarm,
            assistantEnabled: true,
            onDataChanged: (profile) {
              setState(() {
                _farmProfile = profile;
              });
            },
          ),
        ],
      ),
      bottomSheet: Container(
        color: colors.bg,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveFarm,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.brandDeep,
              foregroundColor: Colors.white,
              disabledBackgroundColor: colors.brandDeep.withValues(alpha: 0.5),
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
                : Text(
                    loc.saveFarm,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<bool> _saveFarm() async {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    if (_farmProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.pleaseFillFarmDetails),
          backgroundColor: colors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return false;
    }

    if (_farmProfile!.farmName.isEmpty ||
        _farmProfile!.farmSize.isEmpty ||
        _farmProfile!.farmLocation == null ||
        !_farmProfile!.farmLocation!.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.pleaseFillFarmRequired),
          backgroundColor: colors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return false;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final dataService = DataService();
      final existingFarms = await dataService.loadFarms();
      final newFarm = FarmProfile(
        farmId: _farmProfile!.farmId,
        index: _isEditing ? widget.initialFarm!.index : existingFarms.length,
        farmName: _farmProfile!.farmName,
        farmSize: _farmProfile!.farmSize,
        farmSizeUnit: _farmProfile!.farmSizeUnit,
        farmLocation: _farmProfile!.farmLocation,
        irrigationType: _farmProfile!.irrigationType,
        waterSource: _farmProfile!.waterSource,
        soilType: _farmProfile!.soilType,
        waterAvailability: _farmProfile!.waterAvailability,
        farmingMethod: _farmProfile!.farmingMethod,
        soilAiResult: _farmProfile!.soilAiResult,
        isActive: _isEditing ? widget.initialFarm!.isActive : true,
        createdAt: _isEditing ? widget.initialFarm!.createdAt : null,
      );

      if (_isEditing) {
        await dataService.updateFarm(newFarm.farmId, newFarm);
      } else {
        await dataService.addFarm(newFarm);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_farmProfile!.farmName} ${loc.savedSuccessfully}'),
            backgroundColor: colors.brandDeep,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        Navigator.pop(context, true);
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.errorSavingFarm} $e'),
            backgroundColor: colors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
