import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/data/models/market_price_models.dart';
import 'package:vidhai/features/community/data/community_repository.dart';
import 'package:vidhai/features/community/models/community_models.dart';
import 'package:vidhai/features/community/services/community_controller.dart';
import 'package:vidhai/features/community/services/community_notification_service.dart';
import 'package:vidhai/features/community/services/price_risk_service.dart';
import 'package:vidhai/features/community/services/price_suggestion_service.dart';
import 'package:vidhai/features/community/widgets/community_shared.dart';
import 'package:vidhai/locale/locale.dart';

/// Type-driven create/edit screen for Experience, Harvest Soon and Demand.
///
/// Price figures always come from the AGMARKNET-backed suggestion service and
/// are never edited by the user invisibly: the farmer can override, but the
/// market reference and buyer-acceptance risk are always shown.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key, required this.type, this.editing});

  final CommunityPostType type;
  final CommunityPost? editing;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final CommunityRepository _repo = CommunityRepository.instance;
  final CommunityController _controller = CommunityController.instance;

  final _titleCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _cropNameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  List<FarmProfile> _farms = const [];
  bool _loadingFarms = true;
  FarmProfile? _farm;
  List<CropRecord> _crops = const [];
  CropRecord? _crop;

  DateTime? _harvestDate;
  DateTime? _requiredDate;

  XFile? _image;
  String _existingImageUrl = '';

  bool _saving = false;

  PriceSuggestionResult? _suggestion;
  bool _loadingPrice = false;

  CommunityPostType get _type => widget.type;
  bool get _isEdit => widget.editing != null;

  String get _cropName {
    if (_crop != null) return _crop!.cropName;
    return _cropNameCtrl.text.trim();
  }

  double? get _asking => double.tryParse(_priceCtrl.text.trim());

  PriceRiskResult get _risk =>
      PriceRiskService.evaluate(_asking, _suggestion?.referencePerKg);

  @override
  void initState() {
    super.initState();
    _priceCtrl.addListener(_onPriceChanged);
    _cropNameCtrl.addListener(_onCropTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _controller.ensureLoaded();
      await _loadFarms();
      _refreshPriceSuggestion();
    });

    final editing = widget.editing;
    if (editing != null) {
      _titleCtrl.text = editing.title;
      _experienceCtrl.text = editing.experienceText;
      _quantityCtrl.text = editing.quantityKg == null
          ? ''
          : _num(editing.quantityKg!);
      _priceCtrl.text = (editing.isHarvest
              ? editing.askingPricePerKg
              : editing.targetPricePerKg) ==
          null
          ? ''
          : _num(editing.isHarvest
              ? editing.askingPricePerKg!
              : editing.targetPricePerKg!);
      _cropNameCtrl.text = editing.cropName;
      _descriptionCtrl.text = editing.description;
      _harvestDate = editing.harvestDate;
      _requiredDate = editing.requiredDate;
      _existingImageUrl = editing.imageUrl;
    }
  }

  @override
  void dispose() {
    _priceCtrl.removeListener(_onPriceChanged);
    _cropNameCtrl.removeListener(_onCropTextChanged);
    _titleCtrl.dispose();
    _experienceCtrl.dispose();
    _quantityCtrl.dispose();
    _priceCtrl.dispose();
    _cropNameCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _onPriceChanged() => setState(() {});
  void _onCropTextChanged() {
    if (_crop == null) _refreshPriceSuggestion();
  }

  Future<void> _loadFarms() async {
    final farms = await _repo.getUserFarms();
    if (!mounted) return;
    setState(() {
      _farms = farms;
      _loadingFarms = false;
    });

    final editing = widget.editing;
    if (editing != null && editing.farmId.isNotEmpty) {
      final match = farms.where((f) => f.farmId == editing.farmId);
      if (match.isNotEmpty) {
        _farm = match.first;
        await _loadCrops(_farm!, preselectCropId: editing.cropId);
      }
    }
  }

  Future<void> _loadCrops(FarmProfile farm, {String? preselectCropId}) async {
    final crops = await _repo.getActiveCrops(farm.farmId);
    if (!mounted) return;
    setState(() {
      _crops = crops;
      _crop = null;
      if (preselectCropId != null && preselectCropId.isNotEmpty) {
        final match = crops.where((c) => c.id == preselectCropId);
        if (match.isNotEmpty) _crop = match.first;
      }
      if (_crop == null && crops.length == 1 && _cropNameCtrl.text.isEmpty) {
        _crop = crops.first;
      }
    });
    _refreshPriceSuggestion();
  }

  Future<void> _refreshPriceSuggestion() async {
    if (_type != CommunityPostType.harvest) return;
    final crop = _cropName;
    if (crop.isEmpty || _controller.selectedState.isEmpty) {
      if (mounted) setState(() => _suggestion = null);
      return;
    }
    setState(() => _loadingPrice = true);
    final language = Localizations.localeOf(context).languageCode;
    try {
      final result = await PriceSuggestionService.instance.suggest(
        state: _controller.selectedState,
        district: _controller.selectedDistrict,
        commodity: crop,
        language: language,
      );
      if (!mounted) return;
      setState(() {
        _suggestion = result;
        _loadingPrice = false;
      });
      if (_priceCtrl.text.trim().isEmpty &&
          result.referencePerKg != null &&
          !_isEdit) {
        final suggested = PriceRiskService.suggestedAsking(result.referencePerKg);
        if (suggested != null) _priceCtrl.text = _num(suggested);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestion = null;
        _loadingPrice = false;
      });
    }
  }

  void _onFarmChanged(FarmProfile? farm) {
    setState(() {
      _farm = farm;
      _crops = const [];
      _crop = null;
    });
    if (farm != null) _loadCrops(farm);
    _refreshPriceSuggestion();
  }

  void _onCropChanged(CropRecord? crop) {
    setState(() => _crop = crop);
    _refreshPriceSuggestion();
  }

  Future<void> _pickDate({required bool harvest}) async {
    final now = DateTime.now();
    final initial = harvest
        ? (_harvestDate ?? now.add(const Duration(days: 14)))
        : (_requiredDate ?? now.add(const Duration(days: 7)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    setState(() {
      if (harvest) {
        _harvestDate = picked;
      } else {
        _requiredDate = picked;
      }
    });
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await _repo.pickAndCompressImage(source);
    if (file != null && mounted) setState(() => _image = file);
  }

  String? _validate(AppLocalizations loc) {
    switch (_type) {
      case CommunityPostType.experience:
        if (_experienceCtrl.text.trim().isEmpty) {
          return loc.communityRequireExperience;
        }
      case CommunityPostType.harvest:
        if (_cropName.isEmpty) return loc.communityRequireCrop;
        final qty = double.tryParse(_quantityCtrl.text.trim());
        if (qty == null || qty <= 0) return loc.communityRequireQuantity;
        if (_harvestDate == null) return loc.communityRequireHarvestDate;
        if (_asking == null || _asking! <= 0) {
          return loc.communityRequireQuantity;
        }
      case CommunityPostType.demand:
        if (_cropName.isEmpty) return loc.communityRequireCrop;
        final qty = double.tryParse(_quantityCtrl.text.trim());
        if (qty == null || qty <= 0) return loc.communityRequireQuantity;
        if (_requiredDate == null) return loc.communityRequireHarvestDate;
        if (_asking == null || _asking! <= 0) {
          return loc.communityRequireQuantity;
        }
    }
    return null;
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context);
    final error = _validate(loc);
    if (error != null) {
      _snack(error, isError: true);
      return;
    }
    setState(() => _saving = true);

    final quantity = double.tryParse(_quantityCtrl.text.trim());
    final state = _controller.selectedState;
    final district = _controller.selectedDistrict;
    final ref = _suggestion?.referencePerKg;
    final band = PriceRiskService.suggestedBand(ref);

    try {
      String? postId;
      if (_isEdit) {
        postId = widget.editing!.id;
        await _repo.updatePost(postId, _buildUpdateMap(
          state: state,
          district: district,
          quantity: quantity,
          reference: ref,
          band: band,
        ));
        if (_image != null) {
          final url = await _repo.uploadImage(postId: postId, imageFile: _image!);
          if (url != null) await _repo.updatePost(postId, {'imageUrl': url});
        }
      } else {
        postId = await _repo.createPost(
          type: _type,
          state: state,
          district: district,
          farmId: _farm?.farmId ?? '',
          farmName: _farm?.farmName ?? '',
          cropId: _crop?.id ?? '',
          cropName: _cropName,
          description: _descriptionCtrl.text.trim(),
          title: _titleCtrl.text.trim(),
          experienceText: _experienceCtrl.text.trim(),
          quantityKg: quantity,
          harvestDate: _type == CommunityPostType.harvest ? _harvestDate : null,
          askingPricePerKg:
              _type == CommunityPostType.harvest ? _asking : null,
          marketReferencePerKg:
              _type == CommunityPostType.harvest ? ref : null,
          suggestedMinPrice:
              _type == CommunityPostType.harvest ? band.$1 : null,
          suggestedMaxPrice:
              _type == CommunityPostType.harvest ? band.$2 : null,
          priceRiskLevel:
              _type == CommunityPostType.harvest && !_risk.unknown
                  ? _risk.level.name
                  : null,
          requiredDate:
              _type == CommunityPostType.demand ? _requiredDate : null,
          targetPricePerKg:
              _type == CommunityPostType.demand ? _asking : null,
        );
        if (postId == null) throw Exception('create failed');
        if (_image != null) {
          final url = await _repo.uploadImage(postId: postId, imageFile: _image!);
          if (url != null) {
            await _repo.updatePost(postId, {'imageUrl': url});
          }
        }
        if (_type != CommunityPostType.experience) {
          await CommunityNotificationService.instance.notifyPostCreated(postId);
        }
      }

      if (!mounted) return;
      if (_isEdit) _snack(loc.communityPostUpdated);
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(loc.communityWaitingConnection, isError: true);
    }
  }

  Map<String, dynamic> _buildUpdateMap({
    required String state,
    required String district,
    required double? quantity,
    required double? reference,
    required (double?, double?) band,
  }) {
    return {
      'state': state,
      'district': district,
      'farmId': _farm?.farmId ?? '',
      'farmName': _farm?.farmName ?? '',
      'cropId': _crop?.id ?? '',
      'cropName': _cropName,
      'description': _descriptionCtrl.text.trim(),
      'title': _titleCtrl.text.trim(),
      'experienceText': _experienceCtrl.text.trim(),
      'quantityKg': quantity,
      'harvestDate': _type == CommunityPostType.harvest && _harvestDate != null
          ? Timestamp.fromDate(_harvestDate!)
          : null,
      'askingPricePerKg':
          _type == CommunityPostType.harvest ? _asking : null,
      'marketReferencePerKg':
          _type == CommunityPostType.harvest ? reference : null,
      'suggestedMinPrice': _type == CommunityPostType.harvest ? band.$1 : null,
      'suggestedMaxPrice': _type == CommunityPostType.harvest ? band.$2 : null,
      'priceRiskLevel': _type == CommunityPostType.harvest && !_risk.unknown
          ? _risk.level.name
          : null,
      'requiredDate': _type == CommunityPostType.demand && _requiredDate != null
          ? Timestamp.fromDate(_requiredDate!)
          : null,
      'targetPricePerKg': _type == CommunityPostType.demand ? _asking : null,
    };
  }

  void _snack(String message, {bool isError = false}) {
    final colors = FreshLeafColorsX(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colors.error : colors.brandDeep,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isEdit ? loc.communityEditTitle : loc.communityCreateTitle,
          style: TextStyle(
            color: colors.onBackground,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            _typeHeader(colors, loc),
            const SizedBox(height: 16),
            if (_type == CommunityPostType.experience)
              ..._experienceFields(colors, loc)
            else
              ..._tradeFields(colors, loc),
            const SizedBox(height: 14),
            _farmCropFields(colors, loc),
            const SizedBox(height: 14),
            _imagePicker(colors, loc),
            const SizedBox(height: 14),
            _descriptionField(colors, loc),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEdit ? loc.communityPostUpdated : loc.communityPostNow,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeHeader(FreshLeafColorsX colors, AppLocalizations loc) {
    final String desc;
    final IconData icon;
    switch (_type) {
      case CommunityPostType.experience:
        desc = loc.communityExperienceDesc;
        icon = Icons.lightbulb_outline;
      case CommunityPostType.harvest:
        desc = loc.communityHarvestDesc;
        icon = Icons.agriculture_outlined;
      case CommunityPostType.demand:
        desc = loc.communityDemandDesc;
        icon = Icons.shopping_basket_outlined;
    }
    final color = postTypeColor(context, _type);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  postTypeLabel(loc, _type),
                  style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    color: colors.onSurfaceMuted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _experienceFields(FreshLeafColorsX colors, AppLocalizations loc) {
    return [
      _label(loc.communityExperienceTitleLbl, colors),
      TextField(
        controller: _titleCtrl,
        textCapitalization: TextCapitalization.sentences,
        decoration: _dec(colors, loc.communityExperienceTitleLbl),
      ),
      const SizedBox(height: 14),
      _label(loc.communityDescription, colors),
      TextField(
        controller: _experienceCtrl,
        maxLines: 5,
        minLines: 3,
        textCapitalization: TextCapitalization.sentences,
        decoration: _dec(colors, loc.communityExperienceTextHint),
      ),
    ];
  }

  List<Widget> _tradeFields(FreshLeafColorsX colors, AppLocalizations loc) {
    return [
      if (_type == CommunityPostType.harvest) ...[
        _label(loc.communityQuantityLabel, colors),
        TextField(
          controller: _quantityCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: _dec(colors, loc.communityQuantityHint),
        ),
        const SizedBox(height: 14),
        _label(loc.communityHarvestDateLabel, colors),
        _dateField(
          colors,
          value: _harvestDate,
          hint: loc.communitySelectHarvestDate,
          onTap: () => _pickDate(harvest: true),
        ),
        const SizedBox(height: 14),
        _priceField(colors, loc),
        const SizedBox(height: 14),
        _suggestionCard(colors, loc),
      ] else ...[
        _label(loc.communityQuantityLabel, colors),
        TextField(
          controller: _quantityCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: _dec(colors, loc.communityQuantityHint),
        ),
        const SizedBox(height: 14),
        _label(loc.communityRequiredDateLabel, colors),
        _dateField(
          colors,
          value: _requiredDate,
          hint: loc.communitySelectDate,
          onTap: () => _pickDate(harvest: false),
        ),
        const SizedBox(height: 14),
        _label(loc.communityTargetPriceLabel, colors),
        TextField(
          controller: _priceCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: _dec(colors, '₹/${loc.communityKgUnit}'),
        ),
      ],
    ];
  }

  Widget _priceField(FreshLeafColorsX colors, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(loc.communityPriceLabel, colors),
        TextField(
          controller: _priceCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: _dec(colors, '₹/${loc.communityKgUnit}'),
        ),
      ],
    );
  }

  Widget _suggestionCard(FreshLeafColorsX colors, AppLocalizations loc) {
    if (_loadingPrice) {
      return _infoBox(
        colors,
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              loc.communityPriceLoading,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final suggestion = _suggestion;
    if (suggestion == null || suggestion.isEmpty) {
      return _infoBox(
        colors,
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: colors.onSurfaceMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loc.communityNoMarketData,
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final ref = suggestion.referencePerKg;
    final (min, max) = PriceRiskService.suggestedBand(ref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          colors,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${loc.communityMarketPriceLabel}: '
                      '${MarketFormat.inr(ref, decimals: 1)}/${loc.communityKgUnit}',
                      style: TextStyle(
                        color: colors.onBackground,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (suggestion.usedStateFallback)
                    Text(
                      loc.communityStateFallback(_controller.selectedState),
                      style: TextStyle(
                        color: colors.onSurfaceMuted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              if (min != null && max != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${loc.communitySuggestedLabel}: '
                  '${MarketFormat.inr(min, decimals: 1)} – '
                  '${MarketFormat.inr(max, decimals: 1)}',
                  style: TextStyle(
                    color: colors.onSurfaceMuted,
                    fontSize: 12.5,
                  ),
                ),
              ],
              if (suggestion.marketName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '${suggestion.marketName} · ${loc.communityMarketSource}',
                  style: TextStyle(
                    color: colors.onSurfaceMuted,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              PriceRiskBar(risk: _risk),
            ],
          ),
        ),
      ],
    );
  }

  Widget _farmCropFields(FreshLeafColorsX colors, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(loc.communityFarmOptional, colors),
        if (_loadingFarms)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else if (_farms.isEmpty)
          _infoBox(
            colors,
            child: Text(
              loc.communitySelectFarm,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
            ),
          )
        else
          DropdownButtonFormField<FarmProfile>(
            key: ValueKey('farm_${_farm?.farmId ?? ''}'),
            initialValue: _farm,
            isExpanded: true,
            decoration: _dec(colors, loc.communitySelectFarm),
            items: _farms
                .map(
                  (f) => DropdownMenuItem(
                    value: f,
                    child: Text(
                      f.farmName.isEmpty ? f.farmId : f.farmName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _onFarmChanged,
          ),
        const SizedBox(height: 14),
        _label(
          _type == CommunityPostType.experience
              ? loc.communityCropOptional
              : loc.communityCropName,
          colors,
        ),
        if (_crops.isNotEmpty)
          DropdownButtonFormField<CropRecord>(
            key: ValueKey('crop_${_crop?.id ?? _crops.length}'),
            initialValue: _crop,
            isExpanded: true,
            decoration: _dec(colors, loc.communityCropName),
            items: _crops
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(
                      c.variety.isEmpty
                          ? c.cropName
                          : '${c.cropName} · ${c.variety}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _onCropChanged,
          )
        else
          TextField(
            controller: _cropNameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: _dec(colors, loc.communityCropName),
          ),
      ],
    );
  }

  Widget _imagePicker(FreshLeafColorsX colors, AppLocalizations loc) {
    final hasImage = _image != null || _existingImageUrl.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(loc.communityAddPhoto, colors),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _pickImage,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.borderColor),
              image: hasImage
                  ? DecorationImage(
                      image: _image != null
                          ? FileImage(File(_image!.path))
                          : NetworkImage(_existingImageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: hasImage
                ? null
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined,
                          color: colors.onSurfaceMuted),
                      const SizedBox(height: 6),
                      Text(
                        loc.communityAddPhoto,
                        style: TextStyle(
                          color: colors.onSurfaceMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _descriptionField(FreshLeafColorsX colors, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(loc.communityDescription, colors),
        TextField(
          controller: _descriptionCtrl,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: _dec(colors, loc.communityDescription),
        ),
      ],
    );
  }

  Widget _label(String text, FreshLeafColorsX colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        text,
        style: TextStyle(
          color: colors.onBackground,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  InputDecoration _dec(FreshLeafColorsX colors, String hint) {
    return InputDecoration(
      hintText: hint,
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
        borderSide: BorderSide(color: colors.brand, width: 1.5),
      ),
    );
  }

  Widget _dateField(
    FreshLeafColorsX colors, {
    required DateTime? value,
    required String hint,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: _dec(colors, hint),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value == null ? hint : communityDate(context, value),
                style: TextStyle(
                  color: value == null
                      ? colors.onSurfaceMuted
                      : colors.onBackground,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.calendar_today_outlined,
                size: 18, color: colors.onSurfaceMuted),
          ],
        ),
      ),
    );
  }

  Widget _infoBox(FreshLeafColorsX colors, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderColor),
      ),
      child: child,
    );
  }

  String _num(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }
}
