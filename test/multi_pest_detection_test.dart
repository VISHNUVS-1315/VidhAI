import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:vidhai/data/models/pest_analysis.dart';
import 'package:vidhai/data/models/pest_photo_input.dart';
import 'package:vidhai/data/models/workspace_note.dart';
import 'package:vidhai/features/tools/screens/multi_pest_detection_screen.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/services/pest_analysis_service.dart';
import 'package:vidhai/services/workspace_service.dart';

/// Smallest valid 1x1 transparent PNG.
final Uint8List _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
  'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

final Uint8List _unsupportedBytes = Uint8List.fromList(
    const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 255, 254]);

class _CapturedAnalyze {
  List<PestPhotoInput>? photos;
  String crop = '';
  String farmingMethod = '';
  String? language;
  String farmId = '';
  String farmName = '';
  int calls = 0;
}

class _FakePicker extends ImagePicker {
  final XFile? file;
  _FakePicker(this.file);

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async =>
      file;
}

class _FlakySaver {
  final List<WorkspaceNote> saved = [];
  int calls = 0;
  int failFirstN = 0;

  Future<void> call(WorkspaceNote note) async {
    calls++;
    if (calls <= failFirstN) throw Exception('simulated offline');
    saved.add(note);
  }
}

PestAnalysisRecord _record({List<String> imageRefs = const ['ref1', 'ref2']}) =>
    PestAnalysisRecord(
      id: 'analysis_1',
      farmId: '',
      farmName: '',
      crop: 'chilli',
      isHealthy: false,
      issue: 'Aphids',
      issueType: 'pest',
      severity: 'medium',
      confidence: 0.82,
      affectedParts: const ['leaf', 'stem'],
      symptoms: const ['curled leaves', 'sticky sap'],
      causes: const ['aphid infestation'],
      remedy: const RemedyAdvice(
        input: 'Neem oil',
        inputType: 'organic',
        action: 'Spray diluted neem oil on affected parts.',
      ),
      prevention: const ['regular scouting', 'ant control'],
      imageRefs: imageRefs,
      farmingMethod: 'organic',
      createdAt: DateTime(2026, 9, 10, 10, 0),
    );

Future<void> _pumpMonitor(
  WidgetTester tester, {
  required _CapturedAnalyze capture,
  ImagePicker? picker,
  WorkspaceSaver? saver,
  PestAnalysisRecord? record,
  bool fail = false,
}) async {
  tester.view.physicalSize = const Size(1200, 5600);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => flushSnackBars(tester));

  await tester.pumpWidget(
    AppLocalizationsProvider(
      initialLanguageCode: 'en',
      child: MaterialApp(
        home: MultiPestDetectionScreen(
          analyzeOverride: ({
            required List<PestPhotoInput> photos,
            required String crop,
            required String farmingMethod,
            String? language,
            String farmId = '',
            String farmName = '',
          }) async {
            capture.calls++;
            capture.photos = photos;
            capture.crop = crop;
            capture.farmingMethod = farmingMethod;
            capture.language = language;
            capture.farmId = farmId;
            capture.farmName = farmName;
            if (fail) throw Exception('vision backend down');
            return record ?? _record();
          },
          pickerOverride: picker,
          workspaceSaverOverride: saver,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> addSection(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('pest_add_another_part')));
  await tester.pumpAndSettle();
}

Future<void> pickImage(WidgetTester tester, {int index = 0}) async {
  await tester.tap(find.byKey(ValueKey('pest_part_upload_$index')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(AppLocalizations('en').chooseFromGallery));
  await tester.pumpAndSettle();
}

Future<void> selectPart(WidgetTester tester, String code,
    {int index = 0}) async {
  await tester.tap(find.byKey(ValueKey('pest_part_value_$index')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('part_item_$code')),
      warnIfMissed: false);
  await tester.pumpAndSettle();
}

Future<void> analyze(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('pest_analyze_button')));
  await tester.pumpAndSettle();
}

/// Lets any SnackBar timers fire so the test ends without pending timers.
Future<void> flushSnackBars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 20));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    TestFirebaseCoreHostApi.setUp(MockFirebaseApp());
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({});
  });

  group('buildMultiPhotoPrompt', () {
    test('lists every photo with its plant part and observation', () {
      final service = PestAnalysisService.instance;
      final now = DateTime(2026, 9, 10);
      final prompt = service.buildMultiPhotoPrompt(
        crop: 'tomato',
        farmingMethod: 'organic',
        photos: [
          PestPhotoInput(
              id: 'a',
              plantPart: PlantPart.leaf,
              imageBytes: _pngBytes,
              observation: 'brown spots',
              timestamp: now),
          PestPhotoInput(
              id: 'b',
              plantPart: PlantPart.stem,
              imageBytes: _pngBytes,
              observation: 'sticky stem',
              timestamp: now),
        ],
      );
      expect(prompt, contains('plant part = leaf'));
      expect(prompt, contains('farmer observation = "brown spots"'));
      expect(prompt, contains('plant part = stem'));
      expect(prompt, contains('farmer observation = "sticky stem"'));
      expect(prompt, contains('Photo 01:'));
      expect(prompt, contains('Photo 02:'));
      expect(prompt, contains('tomato'));
    });

    test('uses safe fallbacks for missing part and observation', () {
      final service = PestAnalysisService.instance;
      final prompt = service.buildMultiPhotoPrompt(
        crop: 'paddy',
        farmingMethod: '',
        photos: [
          PestPhotoInput(
              id: 'a', imageBytes: _pngBytes, timestamp: DateTime(2026, 9, 10)),
        ],
      );
      expect(prompt, contains('plant part = unspecified'));
      expect(prompt, contains('No observation given by the farmer.'));
    });
  });

  group('analyzeMultiPhotos validation', () {
    test('rejects empty photo list before any network call', () async {
      await expectLater(
        PestAnalysisService.instance.analyzeMultiPhotos(
          photos: [],
          crop: 'chilli',
          farmingMethod: '',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects photos without an image', () async {
      final now = DateTime(2026, 9, 10);
      await expectLater(
        PestAnalysisService.instance.analyzeMultiPhotos(
          photos: [
            PestPhotoInput(id: 'a', imageBytes: const [], timestamp: now),
          ],
          crop: 'chilli',
          farmingMethod: '',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('parsePestAnalysisJson + WorkspaceNote.fromPestCase', () {
    test('extracts affectedParts and keeps per-photo metadata', () {
      final record = parsePestAnalysisJson(jsonEncode({
        'crop': 'tomato',
        'condition': 'issue',
        'issue': 'Leaf blight',
        'type': 'disease',
        'symptoms': ['brown spots'],
        'severity': 'high',
        'confidence': 0.8,
        'causes': ['fungus'],
        'affectedParts': ['leaf', 'stem', 'fruit'],
        'remedy': {
          'input': '',
          'inputType': 'none',
          'action': '',
          'frequency': '',
          'duration': '',
          'reason': '',
        },
        'prevention': ['good airflow'],
        'imageQuality': 'good',
      }));
      expect(record, isNotNull);
      expect(record!.affectedParts, ['leaf', 'stem', 'fruit']);

      final note = WorkspaceNote.fromPestCase(
        record: record,
        photos: const [
          WorkspacePhoto(
              plantPartCode: 'leaf',
              imageRef: 'r1',
              observation: 'spots',
              order: 0),
          WorkspacePhoto(
              plantPartCode: 'fruit',
              imageRef: 'r2',
              observation: '',
              order: 1),
        ],
      );
      expect(note.source, 'pest_detection');
      expect(note.sessionId, record.id);
      expect(note.affectedParts, ['leaf', 'stem', 'fruit']);
      expect(note.photos, hasLength(2));
      expect(note.photos.first.plantPartCode, 'leaf');
      expect(note.photos.first.observation, 'spots');
      expect(note.photos.last.order, 1);

      final restored = WorkspaceNote.fromMap(note.toMap());
      expect(restored.photos, hasLength(2));
      expect(restored.photos.first.plantPartCode, 'leaf');
      expect(restored.photos.last.imageRef, 'r2');
      expect(restored.affectedParts, ['leaf', 'stem', 'fruit']);
      expect(restored.source, 'pest_detection');
    });
  });

  group('MultiPestDetectionScreen widget', () {
    final loc = AppLocalizations('en');

    testWidgets('empty state shows the intro and the add-part button',
        (tester) async {
      final capture = _CapturedAnalyze();
      await _pumpMonitor(tester, capture: capture, picker: _FakePicker(null));

      expect(find.text(loc.pestMultiIntro), findsOneWidget);
      expect(
          find.byKey(const ValueKey('pest_add_another_part')), findsOneWidget);
      expect(find.byKey(const ValueKey('pest_part_card_0')), findsNothing);
    });

    testWidgets('adding another part creates a second section', (tester) async {
      final capture = _CapturedAnalyze();
      await _pumpMonitor(tester, capture: capture, picker: _FakePicker(null));

      await addSection(tester);
      expect(find.byKey(const ValueKey('pest_part_card_0')), findsOneWidget);

      await addSection(tester);
      await addSection(tester);
      expect(find.byKey(const ValueKey('pest_part_card_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('pest_part_card_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('pest_part_card_2')), findsOneWidget);
    });

    testWidgets('uploading a gallery photo shows the preview', (tester) async {
      final capture = _CapturedAnalyze();
      await _pumpMonitor(
        tester,
        capture: capture,
        picker: _FakePicker(
          XFile.fromData(_pngBytes, name: 'photo.png'),
        ),
      );

      await addSection(tester);
      expect(find.byType(Image), findsNothing);
      await pickImage(tester);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('unsupported photo bytes are rejected with a warning',
        (tester) async {
      final capture = _CapturedAnalyze();
      await _pumpMonitor(
        tester,
        capture: capture,
        picker: _FakePicker(
          XFile.fromData(_unsupportedBytes, name: 'corrupt.png'),
        ),
      );

      await addSection(tester);
      await pickImage(tester);
      expect(find.text(loc.pestInvalidPhoto), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('plant part can be selected from the dropdown', (tester) async {
      final capture = _CapturedAnalyze();
      await _pumpMonitor(tester, capture: capture, picker: _FakePicker(null));

      await addSection(tester);
      await selectPart(tester, 'leaf');
      expect(find.text(loc.pestPartLeaf), findsOneWidget);
    });

    testWidgets('an existing part can be changed', (tester) async {
      final capture = _CapturedAnalyze();
      await _pumpMonitor(tester, capture: capture, picker: _FakePicker(null));

      await addSection(tester);
      await selectPart(tester, 'leaf');
      expect(find.text(loc.pestPartLeaf), findsOneWidget);

      await selectPart(tester, 'stem');
      expect(find.text(loc.pestPartLeaf), findsNothing);
      expect(find.text(loc.pestPartStem), findsOneWidget);
    });

    testWidgets('a section can be removed', (tester) async {
      final capture = _CapturedAnalyze();
      await _pumpMonitor(tester, capture: capture, picker: _FakePicker(null));

      await addSection(tester);
      await addSection(tester);
      expect(find.byKey(const ValueKey('pest_part_card_1')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('pest_remove_section_0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pest_part_card_1')), findsNothing);
      expect(find.byKey(const ValueKey('pest_part_card_0')), findsOneWidget);
    });

    testWidgets('observation is captured and forwarded to the analyzer',
        (tester) async {
      final capture = _CapturedAnalyze();
      await _pumpMonitor(
        tester,
        capture: capture,
        picker: _FakePicker(XFile.fromData(_pngBytes, name: 'p.png')),
      );

      await tester.enterText(find.byType(TextField).first, 'chilli');
      await addSection(tester);
      await pickImage(tester);
      await selectPart(tester, 'leaf');
      await tester.enterText(
        find.byKey(const ValueKey('pest_observation_field_0')),
        'small black spots',
      );
      await tester.pump();

      await analyze(tester);
      expect(capture.calls, 1);
      expect(capture.photos, isNotNull);
      expect(capture.photos, hasLength(1));
      expect(capture.photos!.first.plantPart, PlantPart.leaf);
      expect(capture.photos!.first.observation, 'small black spots');
      expect(capture.language, 'en');
    });

    testWidgets('analyze without a crop warns the farmer', (tester) async {
      final capture = _CapturedAnalyze();
      await _pumpMonitor(tester, capture: capture, picker: _FakePicker(null));

      await analyze(tester);
      expect(find.text(loc.pestCropRequired), findsOneWidget);
      expect(capture.calls, 0);
    });

    testWidgets('photos without a selected plant part are rejected',
        (tester) async {
      final capture = _CapturedAnalyze();
      await _pumpMonitor(
        tester,
        capture: capture,
        picker: _FakePicker(XFile.fromData(_pngBytes, name: 'p.png')),
      );

      await tester.enterText(find.byType(TextField).first, 'chilli');
      await addSection(tester);
      await pickImage(tester);
      await analyze(tester);
      expect(find.text(loc.pestNoPartValidation), findsOneWidget);
      expect(capture.calls, 0);
    });

    testWidgets('a selected part without a photo is rejected', (tester) async {
      final capture = _CapturedAnalyze();
      await _pumpMonitor(tester, capture: capture, picker: _FakePicker(null));

      await tester.enterText(find.byType(TextField).first, 'chilli');
      await addSection(tester);
      await selectPart(tester, 'leaf');
      await analyze(tester);
      expect(find.text(loc.pestNoPhotoValidation), findsOneWidget);
      expect(capture.calls, 0);
    });

    testWidgets(
        'successful combined analysis renders the slice result and photos',
        (tester) async {
      final capture = _CapturedAnalyze();
      await _pumpMonitor(
        tester,
        capture: capture,
        picker: _FakePicker(XFile.fromData(_pngBytes, name: 'p.png')),
      );

      await tester.enterText(find.byType(TextField).first, 'chilli');
      await addSection(tester);
      await pickImage(tester);
      await selectPart(tester, 'leaf');
      await tester.enterText(
        find.byKey(const ValueKey('pest_observation_field_0')),
        'curled leaves',
      );
      await tester.pump();
      await addSection(tester);
      await pickImage(tester, index: 1);
      await selectPart(tester, 'stem', index: 1);

      await analyze(tester);
      expect(capture.calls, 1);
      expect(capture.photos, hasLength(2));
      expect(capture.crop, 'chilli');

      expect(find.text(loc.pestIssueDetected), findsOneWidget);
      expect(find.text('Aphids'), findsOneWidget);
      expect(find.textContaining('82%'), findsOneWidget);
      expect(find.textContaining('Combined analysis of all'), findsOneWidget);
      expect(find.text(loc.pestPartLeaf), findsWidgets);
      expect(find.text(loc.pestPartStem), findsWidgets);
      expect(find.text('curled leaves'), findsWidgets);
    });

    testWidgets('analysis failure surfaces the error and shows no result',
        (tester) async {
      final capture = _CapturedAnalyze();
      await _pumpMonitor(
        tester,
        capture: capture,
        picker: _FakePicker(XFile.fromData(_pngBytes, name: 'p.png')),
        fail: true,
      );

      await tester.enterText(find.byType(TextField).first, 'chilli');
      await addSection(tester);
      await pickImage(tester);
      await selectPart(tester, 'leaf');

      await analyze(tester);
      expect(capture.calls, 1);
      expect(find.textContaining('Analysis failed:'), findsOneWidget);
      expect(find.textContaining('vision backend down'), findsOneWidget);
      expect(find.text(loc.pestIssueDetected), findsNothing);
      expect(find.byKey(const ValueKey('pest_analyze_again')), findsNothing);
    });

    testWidgets('analysis auto-saves to the Workspace and keeps image metadata',
        (tester) async {
      final capture = _CapturedAnalyze();
      await _pumpMonitor(
        tester,
        capture: capture,
        picker: _FakePicker(XFile.fromData(_pngBytes, name: 'p.png')),
      );

      await tester.enterText(find.byType(TextField).first, 'chilli');
      await addSection(tester);
      await pickImage(tester);
      await selectPart(tester, 'fruit');
      await tester.enterText(
        find.byKey(const ValueKey('pest_observation_field_0')),
        'spotted fruit',
      );
      await tester.pump();

      await analyze(tester);
      final notes = await WorkspaceService.instance.loadAll();
      expect(notes, hasLength(1));
      final note = notes.first;
      expect(note.type, WorkspaceNoteType.pest);
      expect(note.crop, 'chilli');
      expect(note.issue, 'Aphids');
      expect(note.source, 'pest_detection');
      expect(note.sessionId, 'analysis_1');
      expect(note.confidence, 0.82);
      expect(note.affectedParts, containsAll(['leaf', 'stem']));
      expect(note.photos, hasLength(1));
      expect(note.photos.first.plantPartCode, 'fruit');
      expect(note.photos.first.observation, 'spotted fruit');
      expect(note.photos.first.imageRef, 'ref1');
      expect(find.byKey(const ValueKey('pest_save_retry')), findsNothing);
    });

    testWidgets('workspace save failure shows a retry that eventually succeeds',
        (tester) async {
      final capture = _CapturedAnalyze();
      final saver = _FlakySaver()..failFirstN = 1;
      await _pumpMonitor(
        tester,
        capture: capture,
        picker: _FakePicker(XFile.fromData(_pngBytes, name: 'p.png')),
        saver: saver.call,
      );

      await tester.enterText(find.byType(TextField).first, 'chilli');
      await addSection(tester);
      await pickImage(tester);
      await selectPart(tester, 'leaf');

      await analyze(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(saver.calls, 1);
      expect(find.text(loc.pestWorkspaceSaveFailed), findsOneWidget);
      expect(find.byKey(const ValueKey('pest_save_retry')), findsOneWidget);
      expect(saver.saved, isEmpty);

      await tester.tap(find.byKey(const ValueKey('pest_save_retry')));
      await tester.pumpAndSettle();
      expect(saver.calls, 2);
      expect(saver.saved, hasLength(1));
      expect(saver.saved.first.photos, hasLength(1));
      expect(saver.saved.first.photos.first.plantPartCode, 'leaf');
      expect(find.byKey(const ValueKey('pest_save_retry')), findsNothing);
    });
  });
}
