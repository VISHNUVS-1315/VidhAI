import 'package:vidhai/locale/locale.dart';

/// A specific plant part a farmer can photograph for pest detection.
enum PlantPart {
  wholePlant('whole_plant'),
  leaf('leaf'),
  stem('stem'),
  root('root'),
  flower('flower'),
  fruit('fruit'),
  seed('seed'),
  other('other');

  const PlantPart(this.code);

  /// Stable storage/API code (never localized).
  final String code;

  static PlantPart? fromCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final p in PlantPart.values) {
      if (p.code == code) return p;
    }
    return null;
  }

  /// Localized label for this part.
  String label(AppLocalizations loc) => plantPartLabel(loc, code);
}

/// Localized label for a plant-part code (defensive: unknown → 'Other').
String plantPartLabel(AppLocalizations loc, String code) {
  switch (code) {
    case 'whole_plant':
      return loc.pestPartWholePlant;
    case 'leaf':
      return loc.pestPartLeaf;
    case 'stem':
      return loc.pestPartStem;
    case 'root':
      return loc.pestPartRoot;
    case 'flower':
      return loc.pestPartFlower;
    case 'fruit':
      return loc.pestPartFruit;
    case 'seed':
      return loc.pestPartSeed;
    default:
      return loc.pestPartOther;
  }
}

/// One farmer-supplied photo in a multi-photo pest-detection case.
///
/// Every image keeps its own plant part, farmer observation and order. The
/// image itself is carried as decoded bytes (so the preview survives on all
/// platforms); [imagePath] is kept when a real device file is available.
class PestPhotoInput {
  final String id;
  final PlantPart? plantPart;
  final String? imagePath;
  final List<int> imageBytes;
  final String mimeType;
  final String observation;
  final DateTime timestamp;

  const PestPhotoInput({
    required this.id,
    this.plantPart,
    this.imagePath,
    required this.imageBytes,
    this.mimeType = 'image/jpeg',
    this.observation = '',
    required this.timestamp,
  });

  bool get hasImage => imageBytes.isNotEmpty;

  PestPhotoInput copyWith({
    PlantPart? part,
    bool clearPart = false,
    String? imagePath,
    List<int>? imageBytes,
    String? mimeType,
    String? observation,
  }) =>
      PestPhotoInput(
        id: id,
        plantPart: clearPart ? null : (part ?? plantPart),
        imagePath: imagePath ?? this.imagePath,
        imageBytes: imageBytes ?? this.imageBytes,
        mimeType: mimeType ?? this.mimeType,
        observation: observation ?? this.observation,
        timestamp: timestamp,
      );

  /// Builds a [WorkspacePhoto] for persistence into the Workspace.
  WorkspacePhoto toWorkspacePhoto(String ref) => WorkspacePhoto(
        plantPartCode: plantPart?.code ?? '',
        imageRef: ref,
        observation: observation.trim(),
        order: -1,
      );
}

/// A per-photo entry stored inside a Workspace pest-detection case. Keeps the
/// association between the image, its plant part and the farmer observation.
class WorkspacePhoto {
  final String plantPartCode;
  final String imageRef;
  final String observation;
  final int order;

  const WorkspacePhoto({
    required this.plantPartCode,
    required this.imageRef,
    required this.observation,
    required this.order,
  });

  Map<String, dynamic> toMap() => {
        'plantPartCode': plantPartCode,
        'imageRef': imageRef,
        'observation': observation,
        'order': order,
      };

  factory WorkspacePhoto.fromMap(Map<String, dynamic> m) => WorkspacePhoto(
        plantPartCode: m['plantPartCode'] ?? '',
        imageRef: m['imageRef'] ?? '',
        observation: m['observation'] ?? '',
        order: (m['order'] as num?)?.toInt() ?? 0,
      );
}
