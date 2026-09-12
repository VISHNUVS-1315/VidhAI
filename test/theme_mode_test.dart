import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/core/theme/theme_controller.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUp(() {
    final c = ThemeController.instance;
    c.load();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await ThemeController.instance.load();
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeController>.value(
        value: ThemeController.instance,
        child: Builder(
          builder: (context) {
            final themeController = context.watch<ThemeController>();
            return MaterialApp(
              theme: FreshLeafTheme.lightTheme(),
              darkTheme: FreshLeafTheme.darkTheme(),
              themeMode: themeController.mode,
              home: const Scaffold(body: Center(child: Text('x'))),
            );
          },
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Dark mode applies when the controller is switched',
      (tester) async {
    await pumpApp(tester);

    Brightness brightnessOf() =>
        Theme.of(tester.element(find.byType(Scaffold))).brightness;

    expect(brightnessOf(), Brightness.light);

    ThemeController.instance.setMode(ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(brightnessOf(), Brightness.dark);
    final ctx = tester.element(find.byType(Scaffold));
    expect(
        Theme.of(ctx).scaffoldBackgroundColor, FreshLeafColors.darkBackground);
  });

  test('Dark mode persists and restores on reload', () async {
    final prefs = await SharedPreferences.getInstance();

    ThemeController.instance.setMode(ThemeMode.system);
    await ThemeController.instance.load();
    expect(ThemeController.instance.mode, ThemeMode.system);

    await ThemeController.instance.setMode(ThemeMode.dark);
    expect(prefs.getString('vidhai_theme_mode'), 'dark');

    await ThemeController.instance.load();
    expect(ThemeController.instance.mode, ThemeMode.dark);
  });
}
