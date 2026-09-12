import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/features/farm/screens/farm_details_screen.dart';
import 'package:vidhai/features/farm/screens/add_farm_screen.dart';
import 'package:vidhai/features/farm/crop_stage.dart';
import 'package:vidhai/features/assistant/assistant_button.dart';
import 'package:vidhai/features/assistant/assistant_field_registry.dart';
import 'package:vidhai/locale/locale.dart';

class FarmScreen extends StatefulWidget {
  const FarmScreen({super.key});

  @override
  State<FarmScreen> createState() => _FarmScreenState();
}

class _FarmScreenState extends State<FarmScreen> with WidgetsBindingObserver {
  List<FarmProfile> _farms = [];
  final Map<String, CropRecord> _primaryCrops = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _registerAssistantActions();
    _loadFarms();
  }

  @override
  void dispose() {
    AssistantFieldRegistry.instance.unregisterAction('farm', 'delete_farm');
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _registerAssistantActions() {
    AssistantFieldRegistry.instance.registerAction(
        'farm',
        AssistantActionEntry(
          action: 'delete_farm',
          label: 'Delete the selected farm',
          destructive: true,
          run: (args) async {
            if (!mounted) return {'error': 'Farm screen is not active.'};
            final farmId = (args['farmId'] ?? '').toString();
            if (farmId.isEmpty) {
              return {'error': 'Please pass the farmId of the farm to delete.'};
            }
            FarmProfile? target;
            for (final f in _farms) {
              if (f.farmId == farmId) {
                target = f;
                break;
              }
            }
            if (target == null) {
              return {'error': 'No farm with that id exists.'};
            }
            final name = target.farmName;
            await _deleteFarm(target);
            return {'deleted': name};
          },
        ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadFarms();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFarms();
  }

  Future<void> _loadFarms() async {
    try {
      final farms = await DataService().loadFarms();
      if (!mounted) return;
      setState(() {
        _farms = farms;
        _isLoading = false;
      });
      _loadCropsForFarms();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _farms = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCropsForFarms() async {
    for (final farm in _farms) {
      try {
        final crops = await DataService().loadCrops(farm.farmId);
        if (!mounted) return;
        CropRecord? primary;
        for (final crop in crops) {
          if (crop.status == 'active') {
            primary = crop;
            break;
          }
        }
        primary ??= crops.isNotEmpty ? crops.first : null;
        if (primary != null && mounted) {
          setState(() {
            _primaryCrops[farm.farmId] = primary!;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _openAddFarm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddFarmScreen()),
    );
    _loadFarms();
  }

  Future<void> _openEditFarm(FarmProfile farm) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddFarmScreen(initialFarm: farm)),
    );
    _loadFarms();
  }

  Future<void> _openFarmDetails(FarmProfile farm) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FarmDetailsScreen(farmId: farm.farmId)),
    );
    _loadFarms();
  }

  Future<void> _confirmDelete(FarmProfile farm) async {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final name = farm.farmName.isNotEmpty ? farm.farmName : loc.farm;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          loc.deleteFarm,
          style: TextStyle(
            color: colors.onBackground,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          loc.deleteFarmConfirm(name),
          style: TextStyle(color: colors.onBackground, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              loc.cancel,
              style: TextStyle(color: colors.onSurfaceMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              loc.delete,
              style: TextStyle(
                color: colors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) _deleteFarm(farm);
  }

  Future<void> _deleteFarm(FarmProfile farm) async {
    final loc = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _farms.removeWhere((f) => f.farmId == farm.farmId);
      _primaryCrops.remove(farm.farmId);
    });
    try {
      await DataService().deleteFarm(farm.farmId);
      messenger.showSnackBar(
        SnackBar(
          content: Text(loc.farmDeleted),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(loc.deleteFarmFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadFarms();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'VidhAI',
          style: TextStyle(
            color: colors.brandDeep,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          const VidhAIAssistantButton(screen: 'farm'),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: colors.brandDeep))
                  : _farms.isEmpty
                      ? _buildEmptyState(context)
                      : _buildFarmList(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          Text(
            loc.myFarm,
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _openAddFarm,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: colors.brandDeep,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, color: Colors.white, size: 17),
                  const SizedBox(width: 4),
                  Text(
                    loc.addFarm,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: colors.brandDeep.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.landscape_rounded,
                color: colors.brandDeep,
                size: 42,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              loc.noFarmsYet,
              style: TextStyle(
                color: colors.onBackground,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              loc.tapAddFarmToCreate,
              style: TextStyle(
                color: colors.onSurfaceMuted,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _openAddFarm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.brandDeep,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      loc.addFarm,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildFarmList(BuildContext context) {
    final colors = VidhAIColorsX(context);
    return RefreshIndicator(
      onRefresh: _loadFarms,
      color: colors.brandDeep,
      backgroundColor: colors.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          ...List.generate(
            _farms.length,
            (index) => _buildFarmCard(context, _farms[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmCard(BuildContext context, FarmProfile farm) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final crop = _primaryCrops[farm.farmId];
    final cropName = crop?.cropName ?? '';
    final hasCrop = cropName.isNotEmpty;
    final district = districtLabel(
      extractDistrict(farm.farmLocation),
      loc.district,
    );
    final stageInfo = crop != null ? computeCropStage(crop) : null;
    final stage = stageInfo?.stage;

    final farmName = farm.farmName;
    final title =
        farmName.isNotEmpty ? farmName : (hasCrop ? cropName : loc.farm);
    final showCropLine = farmName.isNotEmpty && hasCrop;

    return GestureDetector(
      onTap: () => _openFarmDetails(farm),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: farmName.isNotEmpty
                              ? colors.onBackground
                              : colors.onSurfaceMuted,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showCropLine) ...[
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Icon(
                              Icons.eco_rounded,
                              color: colors.brandDeep,
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                cropName,
                                style: TextStyle(
                                  color: colors.brandDeep,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: colors.onSurfaceMuted,
                    size: 20,
                  ),
                  color: colors.surface,
                  onSelected: (value) {
                    if (value == 'edit') _openEditFarm(farm);
                    if (value == 'delete') _confirmDelete(farm);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              color: colors.brandDeep, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            loc.editFarm,
                            style: TextStyle(color: colors.onBackground),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              color: colors.danger, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            loc.deleteFarm,
                            style: TextStyle(color: colors.danger),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: colors.onSurfaceMuted,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    district,
                    style: TextStyle(
                      color: colors.onSurfaceMuted,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(
                height: 1, color: colors.borderColor.withValues(alpha: 0.7)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  loc.stage,
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                ),
                const Spacer(),
                if (stage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.brandDeep.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.spa_rounded,
                            color: colors.brandDeep, size: 12),
                        const SizedBox(width: 5),
                        Text(
                          stage,
                          style: TextStyle(
                            color: colors.brandDeep,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    loc.notSet,
                    style:
                        TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
