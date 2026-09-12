import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/user_profile.dart';

const List<String> kCropStages = [
  'Seedling',
  'Vegetative',
  'Flowering',
  'Fruiting',
  'Maturity',
  'Harvest Ready',
];

class CropStageInfo {
  final String? stage;
  final double? progress;

  const CropStageInfo(this.stage, this.progress);
}

CropStageInfo computeCropStage(CropRecord crop) {
  final status = crop.status.toLowerCase();
  if (status == 'harvested') return const CropStageInfo('Harvested', null);
  if (status == 'failed') return const CropStageInfo('Failed', null);

  double? totalDays;
  final expected = crop.expectedHarvestDate;
  if (expected != null) {
    totalDays = expected.difference(crop.plantingDate).inDays.toDouble();
  } else {
    totalDays = _durationToDays(crop.duration);
  }
  if (totalDays == null || totalDays <= 0) {
    return const CropStageInfo(null, null);
  }

  final elapsed =
      DateTime.now().difference(crop.plantingDate).inDays.toDouble();
  final progress = ((elapsed <= 0 ? 0 : elapsed) / totalDays).clamp(0.0, 1.0);
  return CropStageInfo(_stageForProgress(progress), progress);
}

String _stageForProgress(double p) {
  if (p < 0.15) return 'Seedling';
  if (p < 0.45) return 'Vegetative';
  if (p < 0.65) return 'Flowering';
  if (p < 0.85) return 'Fruiting';
  if (p < 0.97) return 'Maturity';
  return 'Harvest Ready';
}

String? extractDistrict(AddressData? addr) {
  if (addr == null) return null;
  final direct = addr.district?.trim();
  if (direct != null && direct.isNotEmpty) return direct;
  final parts = _addressParts(addr);
  if (parts.length < 3) return null;
  if (parts.length == 3) return parts[0];
  return parts[parts.length - 3];
}

String? extractPlace(AddressData? addr) {
  if (addr == null) return null;
  final city = addr.city?.trim();
  if (city != null && city.isNotEmpty) return city;
  final parts = _addressParts(addr);
  if (parts.isEmpty) return null;
  final district = extractDistrict(addr);
  if (parts.length >= 3 || parts[0] != district) return parts[0];
  return null;
}

String? extractStateValue(AddressData? addr) {
  if (addr == null) return null;
  final state = addr.state?.trim();
  if (state != null && state.isNotEmpty) return state;
  final parts = _addressParts(addr);
  if (parts.length < 2) return null;
  return parts[parts.length - 2];
}

List<String> _addressParts(AddressData addr) {
  final fullAddress = addr.fullAddress.trim();
  if (fullAddress.isEmpty) return const [];
  return fullAddress
      .split(',')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
}

String districtLabel(String? district, String districtWord) {
  if (district == null || district.isEmpty) return districtWord;
  final d = district.trim();
  if (d.toLowerCase().endsWith(districtWord.toLowerCase())) return d;
  return '$d $districtWord';
}

double? _durationToDays(String duration) {
  if (duration.isEmpty) return null;
  final lower = duration.toLowerCase();
  final match = RegExp(r'(\d+(?:[.-]\d+)?)').firstMatch(lower);
  if (match == null) return null;
  final n = double.parse(match.group(1)!);
  if (lower.contains('month')) return n * 30;
  if (lower.contains('year')) return n * 365;
  if (lower.contains('week')) return n * 7;
  return n;
}
