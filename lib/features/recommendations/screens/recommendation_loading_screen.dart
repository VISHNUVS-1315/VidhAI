import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/services/ai/ai_context_builder.dart';
import 'package:vidhai/services/crop_backend_service.dart';
import 'package:vidhai/services/data_service.dart';

/// Performs the real AI crop analysis before opening the recommendation page.
///
/// This screen deliberately does not fall back to the deterministic/local crop
/// engine. A recommendation shown after this screen is therefore a response
/// from `/crop/ai-recommend` for the farmer's current inputs and farm context,
/// not a placeholder or a generic cached shortlist.
class RecommendationLoadingScreen extends StatefulWidget {
  final String? farmId;
  final CropSetupQuestionnaire? questionnaire;

  const RecommendationLoadingScreen({
    super.key,
    this.farmId,
    this.questionnaire,
  });

  @override
  State<RecommendationLoadingScreen> createState() =>
      _RecommendationLoadingScreenState();
}

class _RecommendationLoadingScreenState
    extends State<RecommendationLoadingScreen> {
  Timer? _textTimer;
  int _currentTextIndex = 0;
  bool _running = false;
  String? _error;

  VidhAIColorsX get colors => VidhAIColorsX(context);

  @override
  void initState() {
    super.initState();
    _textTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (!mounted || !_running) return;
      setState(() => _currentTextIndex = (_currentTextIndex + 1) % 5);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _analyse());
  }

  @override
  void dispose() {
    _textTimer?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _buildAiInput(
    CropSetupQuestionnaire questionnaire,
    String language,
  ) {
    final input = Map<String, dynamic>.from(questionnaire.toMap());
    input['language'] = language;
    return input;
  }

  Map<String, dynamic> _buildFlatAiContext(
    AiContextSnapshot snapshot,
    CropSetupQuestionnaire questionnaire,
  ) {
    final context = <String, dynamic>{
      ...snapshot.farmMap,
      'season': snapshot.season,
      'month': snapshot.now.month,
      'weather': snapshot.weather,
      'market': snapshot.marketContext,
      'cropHistory': snapshot.cropHistory
          .take(8)
          .map((crop) => <String, dynamic>{
                'crop': crop.cropName,
                'category': crop.category,
                'status': crop.status,
                'plantingDate':
                    crop.plantingDate.toIso8601String().substring(0, 10),
                if (crop.endDate != null)
                  'endDate': crop.endDate!.toIso8601String().substring(0, 10),
              })
          .toList(),
    };

    // Farmer-entered/confirmed values must win over a stale saved profile.
    if (questionnaire.soilType.trim().isNotEmpty) {
      context['soilType'] = questionnaire.soilType.trim();
    }
    if (questionnaire.irrigationSystem.trim().isNotEmpty) {
      context['irrigationType'] = questionnaire.irrigationSystem.trim();
    }
    if (questionnaire.waterSource.trim().isNotEmpty) {
      context['waterSource'] = questionnaire.waterSource.trim();
    }
    if (questionnaire.waterAvailability.trim().isNotEmpty) {
      context['waterAvailability'] = questionnaire.waterAvailability.trim();
    }
    if (questionnaire.currentSeason.trim().isNotEmpty) {
      context['season'] = questionnaire.currentSeason.trim();
    }
    if (questionnaire.farmLocation.trim().isNotEmpty) {
      context['farmerProvidedLocation'] = questionnaire.farmLocation.trim();
    }
    if (questionnaire.farmSize.trim().isNotEmpty) {
      context['farmerProvidedFarmSize'] = questionnaire.farmSize.trim();
    }
    if (questionnaire.lastCrop.trim().isNotEmpty) {
      context['farmerProvidedLastCrop'] = questionnaire.lastCrop.trim();
    }

    return context;
  }

  Future<void> _analyse() async {
    if (_running) return;

    final questionnaire = widget.questionnaire;
    final farmId = widget.farmId?.trim() ?? '';
    if (questionnaire == null || farmId.isEmpty) {
      setState(() => _error = 'invalid_input');
      return;
    }

    setState(() {
      _running = true;
      _error = null;
      _currentTextIndex = 0;
    });

    try {
      final dataService = DataService();
      final farms = await dataService.loadFarms();
      FarmProfile? farm;
      for (final item in farms) {
        if (item.farmId == farmId) {
          farm = item;
          break;
        }
      }
      if (farm == null) {
        throw StateError('farm_not_found');
      }

      final language = await dataService.getSelectedLanguage();
      final snapshot = await AIContextBuilder().build(
        farm: farm,
        languageCode: language,
      );

      final results = await CropBackendService.instance.fetchAIRecommendations(
        context: _buildFlatAiContext(snapshot, questionnaire),
        input: _buildAiInput(questionnaire, language),
      );

      if (!mounted) return;
      if (results == null || results.isEmpty) {
        setState(() {
          _running = false;
          _error = 'ai_unavailable';
        });
        return;
      }

      Navigator.of(context).pushReplacementNamed(
        '/crop_recommendation',
        arguments: {
          'farm': farm,
          'farmId': farmId,
          'questionnaire': questionnaire,
          'preloadedResults': results,
          'wasOnline': true,
        },
      );
    } catch (e) {
      debugPrint('[RecommendationLoadingScreen] live AI analysis failed: $e');
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = 'ai_unavailable';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final loadingTexts = <String>[
      loc.t('rec_loading_soil'),
      loc.t('rec_loading_weather'),
      loc.t('rec_loading_market'),
      loc.t('rec_loading_crops'),
      loc.t('loading_text_4'),
    ];

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: _error == null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: colors.brandDeep.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 42,
                          color: colors.brandDeep,
                        ),
                      ),
                      const SizedBox(height: 26),
                      Text(
                        loc.t('rec_loading_heading'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onBackground,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          loadingTexts[_currentTextIndex],
                          key: ValueKey(_currentTextIndex),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.brandDeep,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: colors.brandDeep,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        loc.t('cp_ai_note'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurfaceMuted,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  )
                : _buildError(loc),
          ),
        ),
      ),
    );
  }

  Widget _buildError(AppLocalizations loc) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: colors.warning.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.cloud_off_rounded,
            color: colors.warning,
            size: 34,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          loc.t('ai_recommendation_failed'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onBackground,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Live AI did not return a recommendation. No generic crop result was substituted.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onSurfaceMuted,
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _analyse,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(loc.retry),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.brandDeep,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            loc.cancel,
            style: TextStyle(color: colors.onSurfaceMuted),
          ),
        ),
      ],
    );
  }
}
