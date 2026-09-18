import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/features/onboarding/widgets/farm_card.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';
import 'package:vidhai/features/assistant/assistant_button.dart';

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
    if (_numberOfFarms >= 10) return;
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
    final colors = VidhAIColorsX(context);
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
          backgroundColor: colors.surface,
          title: Text(
            loc.confirmDeleteFarm,
            style: TextStyle(color: colors.onBackground, fontSize: 16),
          ),
          content: Text(
            'Farm ${farmsToRemove.join(', ')} data will be removed.',
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.cancel,
                  style: TextStyle(color: colors.onSurfaceMuted)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _applyDecrement(newCount, farmsToRemove);
              },
              child: Text(loc.ok, style: TextStyle(color: colors.brandDeep)),
            ),
          ],
        ),
      );
    } else {
      _applyDecrement(newCount, farmsToRemove);
    }
  }

  void _quickSelect(int count) {
    if (count <= 0) {
      setState(() {
        _numberOfFarms = 0;
        _farmData.clear();
      });
      return;
    }
    if (count >= _numberOfFarms) {
      setState(() => _numberOfFarms = count.clamp(0, 10));
      return;
    }
    _decrementTo(count);
  }

  void _decrementTo(int target) {
    final loc = AppLocalizations.of(context);
    final colors = VidhAIColorsX(context);
    final farmsToRemove = <int>[];
    for (var i = target + 1; i <= _numberOfFarms; i++) {
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
          backgroundColor: colors.surface,
          title: Text(
            loc.confirmDeleteFarm,
            style: TextStyle(color: colors.onBackground, fontSize: 16),
          ),
          content: Text(
            'Farm ${farmsToRemove.join(', ')} data will be removed.',
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.cancel,
                  style: TextStyle(color: colors.onSurfaceMuted)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _applyDecrement(target, farmsToRemove);
              },
              child: Text(loc.ok, style: TextStyle(color: colors.brandDeep)),
            ),
          ],
        ),
      );
    } else {
      _applyDecrement(target, farmsToRemove);
    }
  }

  void _applyDecrement(int newCount, List<int> farmsToRemove) {
    for (final i in farmsToRemove) {
      _farmData.remove(i);
    }
    setState(() => _numberOfFarms = newCount);
  }

  int get _completedFarms => _farmData.values.where((f) => f.isComplete).length;

  void _onFarmDataChanged(int index, FarmProfile data) {
    _farmData[index] = data;
    if (mounted) setState(() {});
  }

  bool _validateAllFarms() {
    for (var i = 1; i <= _numberOfFarms; i++) {
      final farm = _farmData[i];
      if (farm == null || !farm.isComplete) return false;
    }
    return true;
  }

  Future<void> _submitFarmData() async {
    if (!_validateAllFarms()) {
      final loc = AppLocalizations.of(context);
      final colors = VidhAIColorsX(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${loc.requiredField} - ${loc.pleaseFillFarmDetails}'),
        backgroundColor: colors.danger,
      ));
      return;
    }

    setState(() => _isLoading = true);

    final farms = <Map<String, dynamic>>[];
    for (var i = 1; i <= _numberOfFarms; i++) {
      farms.add(_farmData[i]!.toMap());
    }

    try {
      final profileFarms = <FarmProfile>[];
      for (final m in farms) {
        profileFarms.add(FarmProfile.fromMap(Map<String, dynamic>.from(m)));
      }

      await DataService().saveFarms(profileFarms);
      try {
        await DataService().setOnboardingComplete(true);
      } catch (_) {}

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/main_shell');
      }
    } catch (e, st) {
      debugPrint('[FarmSave] TOP-LEVEL EXCEPTION: $e');
      debugPrint('[FarmSave] Stack: $st');
      if (mounted) {
        try {
          await DataService().setOnboardingComplete(true);
        } catch (_) {}
        if (mounted) {
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
            loc.farmDetails,
            style: TextStyle(
              color: colors.onBackground,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: false,
          actions: const [
            VidhAIAssistantButton(
              screen: 'farmer_details',
              size: 38,
              iconSize: 19,
            ),
            SizedBox(width: 10),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const SizedBox(height: 4),
            _buildHero(loc, colors),
            const SizedBox(height: 20),
            _buildCountSelector(loc, colors),
            if (_numberOfFarms > 0) ...[
              const SizedBox(height: 24),
              _buildProgressHeader(loc, colors),
              const SizedBox(height: 12),
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
              const SizedBox(height: 16),
              _buildSubmitButton(loc),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHero(AppLocalizations loc, VidhAIColorsX colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.brandDeep.withValues(alpha: 0.15),
            colors.brandDeep.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.brandDeep.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colors.brandDeep,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colors.brandDeep.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.agriculture_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.selectNumberOfFarms,
                  style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loc.numberOfFarms,
                  style: TextStyle(
                    color: colors.onSurfaceMuted,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountSelector(AppLocalizations loc, VidhAIColorsX colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStepperButton(
                icon: Icons.remove_rounded,
                onTap: _numberOfFarms == 0 ? null : _decrementFarms,
              ),
              Column(
                children: [
                  Text(
                    '$_numberOfFarms',
                    style: TextStyle(
                      color: colors.brandDeep,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    loc.numberOfFarms,
                    style: TextStyle(
                      color: colors.onSurfaceMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              _buildStepperButton(
                icon: Icons.add_rounded,
                onTap: _numberOfFarms >= 10 ? null : _incrementFarms,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.farmsNumberHelper,
                style: TextStyle(
                  color: colors.onSurfaceMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final chipWidth =
                  constraints.maxWidth < 330 ? 48.0 : 52.0;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var n = 1; n <= 5; n++)
                    SizedBox(
                      width: chipWidth,
                      child: _buildQuickChip(
                        colors: colors,
                        count: n,
                        selected: _numberOfFarms == n,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip({
    required VidhAIColorsX colors,
    required int count,
    required bool selected,
  }) {
    return GestureDetector(
      onTap: () => _quickSelect(count),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        decoration: BoxDecoration(
          color: selected ? colors.brandDeep : colors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.brandDeep : colors.borderColor,
            width: 1.2,
          ),
        ),
        child: Center(
          child: Text(
            '$count',
            style: TextStyle(
              color: selected ? Colors.white : colors.onSurfaceMuted,
              fontSize: 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressHeader(AppLocalizations loc, VidhAIColorsX colors) {
    final done = _completedFarms;
    final progress = _numberOfFarms == 0 ? 0.0 : done / _numberOfFarms;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              loc.yourFarms,
              style: TextStyle(
                color: colors.onBackground,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '$done/$_numberOfFarms',
              style: TextStyle(
                color: done == _numberOfFarms
                    ? colors.brandDeep
                    : colors.onSurfaceMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: colors.borderColor,
            valueColor: AlwaysStoppedAnimation<Color>(colors.brandDeep),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(_numberOfFarms, (i) {
            final idx = i + 1;
            final farm = _farmData[idx];
            final isDone = farm?.isComplete ?? false;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDone
                    ? colors.brandDeep.withValues(alpha: 0.12)
                    : colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDone ? colors.brandDeep : colors.borderColor,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDone ? Icons.check_circle : Icons.circle_outlined,
                    color: isDone ? colors.brandDeep : colors.onSurfaceMuted,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${loc.farmCard} $idx',
                    style: TextStyle(
                      color: isDone ? colors.brandDeep : colors.onSurfaceMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final colors = VidhAIColorsX(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: onTap == null
              ? colors.surfaceMuted
              : colors.brandDeep.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: onTap == null
                ? colors.borderColor
                : colors.brandDeep.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(
          icon,
          color: onTap == null ? colors.onSurfaceMuted : colors.brandDeep,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildSubmitButton(AppLocalizations loc) {
    final colors = VidhAIColorsX(context);
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitFarmData,
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
                loc.completeProfileForm,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
