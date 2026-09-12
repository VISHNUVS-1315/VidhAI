import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/data/models/pest_analysis.dart';
import 'package:vidhai/data/models/workspace_note.dart';
import 'package:vidhai/services/workspace_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('workspaceDayGroup', () {
    final now = DateTime(2026, 9, 9, 14, 30);

    test('same day is today', () {
      expect(workspaceDayGroup(now, DateTime(2026, 9, 9, 1, 0)),
          WorkspaceDayGroup.today);
      expect(workspaceDayGroup(now, DateTime(2026, 9, 9, 23, 59)),
          WorkspaceDayGroup.today);
    });

    test('future date counts as today', () {
      expect(workspaceDayGroup(now, DateTime(2026, 9, 10)),
          WorkspaceDayGroup.today);
    });

    test('one calendar day ago is yesterday', () {
      expect(workspaceDayGroup(now, DateTime(2026, 9, 8, 23, 59)),
          WorkspaceDayGroup.yesterday);
      expect(
          workspaceDayGroup(now, DateTime(2026, 9, 7, 0, 0)), // 2 days
          WorkspaceDayGroup.older);
    });

    test('older than yesterday is older', () {
      expect(workspaceDayGroup(now, DateTime(2026, 9, 7, 12, 0)),
          WorkspaceDayGroup.older);
      expect(workspaceDayGroup(now, DateTime(2026, 8, 1)),
          WorkspaceDayGroup.older);
    });
  });

  group('WorkspaceNote serialization', () {
    test('manual note round-trips through map', () {
      final note = WorkspaceNote(
        id: 'n1',
        type: WorkspaceNoteType.manual,
        title: 'Irrigation',
        body: 'Watered the north field.',
        farmId: 'f1',
        farmName: 'My farm',
        crop: 'Rice',
        createdAt: DateTime(2026, 9, 9, 8, 0),
        updatedAt: DateTime(2026, 9, 9, 9, 0),
      );
      final restored = WorkspaceNote.fromMap(note.toMap());
      expect(restored.id, 'n1');
      expect(restored.type, WorkspaceNoteType.manual);
      expect(restored.title, 'Irrigation');
      expect(restored.body, 'Watered the north field.');
      expect(restored.farmId, 'f1');
      expect(restored.farmName, 'My farm');
      expect(restored.crop, 'Rice');
      expect(restored.createdAt, DateTime(2026, 9, 9, 8, 0));
    });

    test('pest note round-trips with full snapshot', () {
      final note = WorkspaceNote(
        id: 'p1',
        type: WorkspaceNoteType.pest,
        title: 'Leaf blight',
        farmId: '',
        farmName: '',
        crop: 'Tomato',
        createdAt: DateTime(2026, 9, 8, 10, 0),
        updatedAt: DateTime(2026, 9, 8, 10, 0),
        isHealthy: false,
        issue: 'Leaf blight',
        severity: 'high',
        confidence: 0.82,
        symptoms: const ['brown spots', 'yellowing'],
        causes: const ['fungus'],
        remedy: const RemedyAdvice(
          input: 'Copper spray',
          inputType: 'chemical',
          action: 'Spray affected leaves every 7 days.',
          frequency: 'every 7 days',
          duration: 'for 2 weeks',
          reason: 'Stops fungal spread.',
        ),
        prevention: const ['dry leaves off', 'good airflow'],
        farmingMethod: 'organic',
        imageRefs: const ['img1'],
      );
      final restored = WorkspaceNote.fromMap(note.toMap());
      expect(restored.type, WorkspaceNoteType.pest);
      expect(restored.confidence, 0.82);
      expect(restored.symptoms, ['brown spots', 'yellowing']);
      expect(restored.remedy.input, 'Copper spray');
      expect(restored.remedy.action, contains('Spray affected leaves'));
      expect(restored.prevention, ['dry leaves off', 'good airflow']);
      expect(restored.farmingMethod, 'organic');
      expect(restored.imageRefs, ['img1']);
    });

    test('fromAnalysis builds a pest note from a record', () {
      final record = PestAnalysisRecord(
        id: 'r1',
        farmId: 'f2',
        farmName: 'Half acre',
        crop: 'Wheat',
        isHealthy: false,
        issue: 'Aphids',
        severity: 'medium',
        confidence: 0.9,
        symptoms: const ['curled leaves'],
        causes: const ['aphids'],
        remedy: const RemedyAdvice(
            input: 'Neem oil',
            inputType: 'organic',
            action: 'Spray diluted neem oil.'),
        prevention: const ['ant check'],
        farmingMethod: 'organic',
        createdAt: DateTime(2026, 9, 9, 12, 0),
      );
      final note = WorkspaceNote.fromAnalysis(record);
      expect(note.type, WorkspaceNoteType.pest);
      expect(note.title, 'Aphids');
      expect(note.farmId, 'f2');
      expect(note.farmName, 'Half acre');
      expect(note.crop, 'Wheat');
      expect(note.createdAt, record.createdAt);
      expect(note.remedy.input, 'Neem oil');
    });
  });

  group('WorkspaceService', () {
    test('save then loadAll returns the note (offline local-first)', () async {
      final service = WorkspaceService.instance;
      final note = WorkspaceNote(
        id: 'n1',
        type: WorkspaceNoteType.manual,
        title: 'Soil watch',
        body: 'Checked moisture levels.',
        createdAt: DateTime(2026, 9, 9, 8, 0),
        updatedAt: DateTime(2026, 9, 9, 8, 0),
      );
      await service.save(note);
      final loaded = await service.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.first.id, 'n1');
      expect(loaded.first.title, 'Soil watch');
    });

    test('upsert replaces a note with the same id', () async {
      final service = WorkspaceService.instance;
      final original = WorkspaceNote(
        id: 'n1',
        type: WorkspaceNoteType.manual,
        title: 'Version 1',
        createdAt: DateTime(2026, 9, 9, 8, 0),
        updatedAt: DateTime(2026, 9, 9, 8, 0),
      );
      await service.save(original);
      final updated = original.copyWith(
          title: 'Version 2', updatedAt: DateTime(2026, 9, 9, 10, 0));
      await service.save(updated);
      final loaded = await service.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.first.title, 'Version 2');
    });

    test('notes come back newest first', () async {
      final service = WorkspaceService.instance;
      await service.save(WorkspaceNote(
        id: 'old',
        type: WorkspaceNoteType.manual,
        title: 'Old',
        createdAt: DateTime(2026, 9, 5, 8, 0),
        updatedAt: DateTime(2026, 9, 5, 8, 0),
      ));
      await service.save(WorkspaceNote(
        id: 'new',
        type: WorkspaceNoteType.manual,
        title: 'New',
        createdAt: DateTime(2026, 9, 9, 8, 0),
        updatedAt: DateTime(2026, 9, 9, 8, 0),
      ));
      final loaded = await service.loadAll();
      expect(loaded.map((n) => n.id).toList(), ['new', 'old']);
    });

    test('data is written to SharedPreferences local cache', () async {
      final service = WorkspaceService.instance;
      await service.save(WorkspaceNote(
        id: 'persist',
        type: WorkspaceNoteType.manual,
        title: 'Persistent',
        body: 'Still here.',
        farmId: 'f9',
        farmName: 'Backyard',
        crop: 'Maize',
        createdAt: DateTime(2026, 9, 9, 8, 0),
        updatedAt: DateTime(2026, 9, 9, 8, 0),
      ));

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('workspace_notes');
      expect(raw, isNotNull);
      expect(raw, contains('Persistent'));
      expect(raw, contains('Backyard'));
      expect(raw, contains('Maize'));
    });

    test('delete removes only the matching note', () async {
      final service = WorkspaceService.instance;
      await service.save(WorkspaceNote(
        id: 'keep',
        type: WorkspaceNoteType.manual,
        title: 'Keep me',
        createdAt: DateTime(2026, 9, 9, 8, 0),
        updatedAt: DateTime(2026, 9, 9, 8, 0),
      ));
      await service.save(WorkspaceNote(
        id: 'remove',
        type: WorkspaceNoteType.manual,
        title: 'Remove me',
        createdAt: DateTime(2026, 9, 9, 9, 0),
        updatedAt: DateTime(2026, 9, 9, 9, 0),
      ));
      await service.delete('remove');
      final loaded = await service.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.first.id, 'keep');
    });

    test('loadAll with no saved notes returns empty', () async {
      final loaded = await WorkspaceService.instance.loadAll();
      expect(loaded, isEmpty);
    });
  });
}
