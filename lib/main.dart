import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:vidhai/core/bloc/auth_bloc.dart';
import 'package:vidhai/core/config/app_config.dart';
import 'package:vidhai/core/theme/app_theme.dart';
import 'package:vidhai/data/repositories/auth_repository.dart';
import 'package:vidhai/firebase_options.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/features/auth/screens/splash_screen.dart';
import 'package:vidhai/features/auth/screens/language_selection_screen.dart';
import 'package:vidhai/features/auth/screens/domain_selection_screen.dart';

import 'package:vidhai/features/onboarding/screens/personal_details_screen.dart';
import 'package:vidhai/features/onboarding/screens/farmer_details_screen.dart';
import 'package:vidhai/features/home/main_shell_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:vidhai/services/notification_service.dart';
import 'package:vidhai/services/ai/ai_service.dart';
import 'package:vidhai/services/ai/ai_config.dart';
import 'package:vidhai/features/notifications/screens/notification_center_screen.dart';
import 'package:vidhai/features/farm/screens/farm_details_screen.dart';
import 'package:vidhai/features/farm/screens/add_farm_screen.dart';
import 'package:vidhai/features/farm/screens/crop_setup_screen.dart';
import 'package:vidhai/features/recommendations/screens/crop_recommendation_screen.dart';
import 'package:vidhai/features/recommendations/screens/recommendation_loading_screen.dart';
import 'package:vidhai/features/farm_records/screens/expenses_screen.dart';
import 'package:vidhai/features/farm_records/screens/pesticide_screen.dart';
import 'package:vidhai/features/farm_records/screens/fertilizer_screen.dart';
import 'package:vidhai/features/farm_records/screens/disease_screen.dart';
import 'package:vidhai/features/farm_records/screens/farm_history_screen.dart';
import 'package:vidhai/features/account/screens/edit_profile_screen.dart';
import 'package:vidhai/features/account/screens/language_settings_screen.dart';
import 'package:vidhai/features/tools/screens/pest_detection_screen.dart';
import 'package:vidhai/features/tools/screens/fertilizer_guide_screen.dart';
import 'package:vidhai/features/tools/screens/market_prices_screen.dart';
import 'package:vidhai/features/tools/screens/crop_search_screen.dart';
import 'package:vidhai/features/schemes/screens/government_schemes_screen.dart';

late final SharedPreferences sharedPreferences;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await NotificationService().initialize();
  
  // Force mock mode for demo (no valid Gemini API key)
  AiService.instance.configure(const AIConfig(
    provider: AIProvider.mock,
  ));
  
  sharedPreferences = await SharedPreferences.getInstance();
  final savedLanguage = await AppLocalizations.loadSavedLanguage();
  runApp(VidhAIApp(initialLanguage: savedLanguage));
}

class VidhAIApp extends StatelessWidget {
  final String initialLanguage;

  const VidhAIApp({required this.initialLanguage, super.key});

  @override
  Widget build(BuildContext context) {
    final authRepository = AuthRepository();
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepository),
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc(authRepository: authRepository),
        ),
      ],
      child: AppLocalizationsProvider(
        initialLanguageCode: initialLanguage,
        child: Builder(
          builder: (context) {
            return MaterialApp(
              title: 'VidhAI',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.dark,
              initialRoute: '/splash',
              onGenerateRoute: (settings) {
                switch (settings.name) {
                  case '/splash':
                    return MaterialPageRoute(
                        builder: (_) => const SplashScreen());
                  case '/language_selection':
                    return MaterialPageRoute(
                        builder: (_) => const LanguageSelectionScreen());
                  case '/domain_selection':
                    return MaterialPageRoute(
                        builder: (_) => const DomainSelectionScreen());
                  case '/personal_details':
                    return MaterialPageRoute(
                        builder: (_) => const PersonalDetailsScreen());
                  case '/farmer_details':
                    return MaterialPageRoute(
                        builder: (_) => const FarmerDetailsScreen());
                  case '/main_shell':
                    return MaterialPageRoute(
                        builder: (_) => const MainShellScreen());
                  case '/notification_center':
                    return MaterialPageRoute(builder: (_) => const NotificationCenterScreen());
                  case '/farm_details':
                    final farmId = settings.arguments as String? ?? '';
                    return MaterialPageRoute(builder: (_) => FarmDetailsScreen(farmId: farmId));
                  case '/add_farm':
                    return MaterialPageRoute(builder: (_) => const AddFarmScreen());
                  case '/crop_setup':
                    final farmId = settings.arguments as String? ?? '';
                    return MaterialPageRoute(builder: (_) => CropSetupScreen(farmId: farmId));
                  case '/crop_recommendation':
                    return MaterialPageRoute(builder: (_) => const CropRecommendationScreen());
                  case '/recommendation_loading':
                    final args = settings.arguments as Map<String, dynamic>?;
                    return MaterialPageRoute(builder: (_) => RecommendationLoadingScreen(
                      farmId: args?['farmId'] as String?,
                      questionnaire: args?['questionnaire'],
                    ));
                  case '/expenses':
                    final farmId = settings.arguments as String? ?? '';
                    return MaterialPageRoute(builder: (_) => ExpensesScreen(farmId: farmId));
                  case '/pesticides':
                    final farmId = settings.arguments as String? ?? '';
                    return MaterialPageRoute(builder: (_) => PesticideScreen(farmId: farmId));
                  case '/fertilizers':
                    final farmId = settings.arguments as String? ?? '';
                    return MaterialPageRoute(builder: (_) => FertilizerScreen(farmId: farmId));
                  case '/diseases':
                    final farmId = settings.arguments as String? ?? '';
                    return MaterialPageRoute(builder: (_) => DiseaseScreen(farmId: farmId));
                  case '/farm_history':
                    final farmId = settings.arguments as String? ?? '';
                    return MaterialPageRoute(builder: (_) => FarmHistoryScreen(farmId: farmId));
                  case '/farmer_home':
                    return MaterialPageRoute(
                        builder: (_) => const MainShellScreen());
                  case '/consumer_home':
                    return MaterialPageRoute(
                        builder: (_) => const MainShellScreen());
                  case '/edit-profile':
                    return MaterialPageRoute(builder: (_) => const EditProfileScreen());
                  case '/language-settings':
                    return MaterialPageRoute(builder: (_) => const LanguageSettingsScreen());
                  case '/pest-detection':
                    return MaterialPageRoute(builder: (_) => const PestDetectionScreen());
                  case '/fertilizer-guide':
                    return MaterialPageRoute(builder: (_) => const FertilizerGuideScreen());
                  case '/market-prices':
                    return MaterialPageRoute(builder: (_) => const MarketPricesScreen());
                  case '/crop-search':
                    return MaterialPageRoute(builder: (_) => const CropSearchScreen());
                  case '/government-schemes':
                    return MaterialPageRoute(builder: (_) => const GovernmentSchemesScreen());
                  default:
                    return MaterialPageRoute(
                        builder: (_) => const SplashScreen());
                }
              },
              debugShowCheckedModeBanner: false,
            );
          },
        ),
      ),
    );
  }
}
