import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'translations/en_strings.dart';
import 'translations/ta_strings.dart';
import 'translations/te_strings.dart';
import 'translations/kn_strings.dart';
import 'translations/ml_strings.dart';
import 'translations/hi_strings.dart';
import 'translations/bn_strings.dart';
import 'translations/mr_strings.dart';
import 'translations/gu_strings.dart';
import 'translations/pa_strings.dart';
import 'translations/or_strings.dart';
import 'translations/as_strings.dart';
import 'translations/ur_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized localization. Crash-free, single-dictionary design:
/// - [AppLocalizations.of] returns the selected language's strings.
/// - Language change is applied immediately via [AppLocalizationsProvider].
/// - [supportedLocales] / [localizationsDelegates] drive Flutter framework
///   strings, date/number formatting and text direction (Urdu = RTL).
class AppLocalizations {
  final String languageCode;

  AppLocalizations(this.languageCode);

  static const String _prefKey = 'selected_language';

  /// The exact language list exposed by the Language Selection screen.
  static const List<String> allLanguageCodes = [
    'en',
    'ta',
    'te',
    'kn',
    'ml',
    'hi',
    'bn',
    'mr',
    'gu',
    'pa',
    'or',
    'as',
    'ur',
  ];

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ta'),
    Locale('te'),
    Locale('kn'),
    Locale('ml'),
    Locale('hi'),
    Locale('bn'),
    Locale('mr'),
    Locale('gu'),
    Locale('pa'),
    Locale('or'),
    Locale('as'),
    Locale('ur'),
  ];

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  /// Raw per-language dictionary with NO English fallback, used by the
  /// development completeness checker. Returns null when the key is missing.
  static String? rawLookup(String languageCode, String key) =>
      _strings[languageCode]?[key];

  /// All keys present in a language (empty when the language has no map).
  static Set<String> rawKeys(String languageCode) =>
      (_strings[languageCode] ?? const {}).keys.toSet();

  static AppLocalizations of(BuildContext context) {
    final localizations =
        context.dependOnInheritedWidgetOfExactType<_AppLocalizationsScope>();
    if (localizations != null) {
      return localizations.localizations;
    }
    return AppLocalizations('en');
  }

  static Future<String> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey) ?? 'en';
  }

  static Future<void> saveLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, code);
  }

  String get appName =>
      _strings[languageCode]?['app_name'] ?? _strings['en']!['app_name']!;
  String get tagline =>
      _strings[languageCode]?['tagline'] ?? _strings['en']!['tagline']!;
  String get splashTitle =>
      _strings[languageCode]?['splash_title'] ??
      _strings['en']!['splash_title']!;
  String get splashTagline =>
      _strings[languageCode]?['splash_tagline'] ??
      _strings['en']!['splash_tagline']!;

  // Language selection
  String get selectLanguage =>
      _strings[languageCode]?['select_language'] ??
      _strings['en']!['select_language']!;
  String get languageSubtitle =>
      _strings[languageCode]?['language_subtitle'] ??
      _strings['en']!['language_subtitle']!;
  String get continueBtn =>
      _strings[languageCode]?['continue_btn'] ??
      _strings['en']!['continue_btn']!;
  String get noLanguagesFound =>
      _strings[languageCode]?['noLanguagesFound'] ??
      _strings['en']!['noLanguagesFound']!;

  // Domain selection
  String get chooseDomain =>
      _strings[languageCode]?['choose_domain'] ??
      _strings['en']!['choose_domain']!;
  String get farmerConsole =>
      _strings[languageCode]?['farmer_console'] ??
      _strings['en']!['farmer_console']!;
  String get consumerConsole =>
      _strings[languageCode]?['consumer_console'] ??
      _strings['en']!['consumer_console']!;
  String get farmerDescription =>
      _strings[languageCode]?['farmer_description'] ??
      _strings['en']!['farmer_description']!;
  String get consumerDescription =>
      _strings[languageCode]?['consumer_description'] ??
      _strings['en']!['consumer_description']!;

  // Farmer home
  String get farmerHome =>
      _strings[languageCode]?['farmer_home'] ?? _strings['en']!['farmer_home']!;
  String get welcomeBack =>
      _strings[languageCode]?['welcome_back'] ??
      _strings['en']!['welcome_back']!;
  String get quickActions =>
      _strings[languageCode]?['quick_actions'] ??
      _strings['en']!['quick_actions']!;
  String get aiQuickAction =>
      _strings[languageCode]?['ai_quick_action'] ??
      _strings['en']!['ai_quick_action']!;
  String get cropSupport =>
      _strings[languageCode]?['crop_support'] ??
      _strings['en']!['crop_support']!;
  String get pestDetection =>
      _strings[languageCode]?['pest_detection'] ??
      _strings['en']!['pest_detection']!;
  String get aiGuidance =>
      _strings[languageCode]?['ai_guidance'] ?? _strings['en']!['ai_guidance']!;
  String get marketInsights =>
      _strings[languageCode]?['market_insights'] ??
      _strings['en']!['market_insights']!;
  String get marketPrices =>
      _strings[languageCode]?['market_prices'] ??
      _strings['en']!['market_prices']!;
  String get demandForecast =>
      _strings[languageCode]?['demand_forecast'] ??
      _strings['en']!['demand_forecast']!;
  String get community =>
      _strings[languageCode]?['community'] ?? _strings['en']!['community']!;
  String get marketplace =>
      _strings[languageCode]?['marketplace'] ?? _strings['en']!['marketplace']!;
  String get yourFarm =>
      _strings[languageCode]?['your_farm'] ?? _strings['en']!['your_farm']!;
  String get farmInfo =>
      _strings[languageCode]?['farm_info'] ?? _strings['en']!['farm_info']!;
  String get profile =>
      _strings[languageCode]?['profile'] ?? _strings['en']!['profile']!;
  String get logout =>
      _strings[languageCode]?['logout'] ?? _strings['en']!['logout']!;

  // Consumer home
  String get consumerHome =>
      _strings[languageCode]?['consumer_home'] ??
      _strings['en']!['consumer_home']!;
  String get exploreProducts =>
      _strings[languageCode]?['explore_products'] ??
      _strings['en']!['explore_products']!;
  String get freshProduce =>
      _strings[languageCode]?['fresh_produce'] ??
      _strings['en']!['fresh_produce']!;
  String get localFarmers =>
      _strings[languageCode]?['local_farmers'] ??
      _strings['en']!['local_farmers']!;
  String get orderHistory =>
      _strings[languageCode]?['order_history'] ??
      _strings['en']!['order_history']!;

  // Onboarding
  String get completeProfile =>
      _strings[languageCode]?['complete_profile'] ??
      _strings['en']!['complete_profile']!;
  String get fullName =>
      _strings[languageCode]?['full_name'] ?? _strings['en']!['full_name']!;
  String get age => _strings[languageCode]?['age'] ?? _strings['en']!['age']!;
  String get gender =>
      _strings[languageCode]?['gender'] ?? _strings['en']!['gender']!;
  String get address =>
      _strings[languageCode]?['address'] ?? _strings['en']!['address']!;
  String get userRole =>
      _strings[languageCode]?['user_role'] ?? _strings['en']!['user_role']!;
  String get completeOnboarding =>
      _strings[languageCode]?['complete_onboarding'] ??
      _strings['en']!['complete_onboarding']!;

  // Auth
  String get email =>
      _strings[languageCode]?['email'] ?? _strings['en']!['email']!;
  String get password =>
      _strings[languageCode]?['password'] ?? _strings['en']!['password']!;
  String get login =>
      _strings[languageCode]?['login'] ?? _strings['en']!['login']!;
  String get createAccount =>
      _strings[languageCode]?['create_account'] ??
      _strings['en']!['create_account']!;

  String get networkError =>
      _strings[languageCode]?['network_error'] ??
      _strings['en']!['network_error']!;

  String get personalDetails =>
      _strings[languageCode]?['personal_details'] ??
      _strings['en']!['personal_details']!;

  // Profile
  String get profileAvatar =>
      _strings[languageCode]?['profile_avatar'] ??
      _strings['en']!['profile_avatar']!;
  String get changePhoto =>
      _strings[languageCode]?['change_photo'] ??
      _strings['en']!['change_photo']!;
  String get takePhoto =>
      _strings[languageCode]?['take_photo'] ?? _strings['en']!['take_photo']!;
  String get chooseFromGallery =>
      _strings[languageCode]?['choose_from_gallery'] ??
      _strings['en']!['choose_from_gallery']!;
  String get dateOfBirth =>
      _strings[languageCode]?['date_of_birth'] ??
      _strings['en']!['date_of_birth']!;
  String get selectDate =>
      _strings[languageCode]?['select_date'] ?? _strings['en']!['select_date']!;
  String get ageCalculated =>
      _strings[languageCode]?['age_calculated'] ??
      _strings['en']!['age_calculated']!;
  String get verifiedAddress =>
      _strings[languageCode]?['verified_address'] ??
      _strings['en']!['verified_address']!;
  String get searchAddress =>
      _strings[languageCode]?['search_address'] ??
      _strings['en']!['search_address']!;
  String get selectFromSuggestions =>
      _strings[languageCode]?['select_from_suggestions'] ??
      _strings['en']!['select_from_suggestions']!;
  String get requiredField =>
      _strings[languageCode]?['required_field'] ??
      _strings['en']!['required_field']!;
  String get voiceInput =>
      _strings[languageCode]?['voice_input'] ?? _strings['en']!['voice_input']!;
  String get listening =>
      _strings[languageCode]?['listening'] ?? _strings['en']!['listening']!;
  String get processing =>
      _strings[languageCode]?['processing'] ?? _strings['en']!['processing']!;
  String get permissionDenied =>
      _strings[languageCode]?['permission_denied'] ??
      _strings['en']!['permission_denied']!;
  String get speechNotAvailable =>
      _strings[languageCode]?['speech_not_available'] ??
      _strings['en']!['speech_not_available']!;
  String get numberOfFarms =>
      _strings[languageCode]?['number_of_farms'] ??
      _strings['en']!['number_of_farms']!;
  String get selectNumberOfFarms =>
      _strings[languageCode]?['select_number_of_farms'] ??
      _strings['en']!['select_number_of_farms']!;
  String get farmCard =>
      _strings[languageCode]?['farm_card'] ?? _strings['en']!['farm_card']!;
  String get yourFarms =>
      _strings[languageCode]?['your_farms'] ?? _strings['en']!['your_farms']!;
  String get farmsNumberHelper =>
      _strings[languageCode]?['farms_number_helper'] ??
      _strings['en']!['farms_number_helper']!;
  String get ofLabel =>
      _strings[languageCode]?['of_label'] ?? _strings['en']!['of_label']!;
  String get farmName =>
      _strings[languageCode]?['farm_name'] ?? _strings['en']!['farm_name']!;
  String get farmSize =>
      _strings[languageCode]?['farm_size'] ?? _strings['en']!['farm_size']!;
  String get farmLocation =>
      _strings[languageCode]?['farm_location'] ??
      _strings['en']!['farm_location']!;
  String get gettingLocation =>
      _strings[languageCode]?['getting_location'] ??
      _strings['en']!['getting_location']!;
  String get complete =>
      _strings[languageCode]?['complete'] ?? _strings['en']!['complete']!;
  String get soilAndWater =>
      _strings[languageCode]?['soil_and_water'] ??
      _strings['en']!['soil_and_water']!;
  String get location =>
      _strings[languageCode]?['location'] ?? _strings['en']!['location']!;
  String get irrigationType =>
      _strings[languageCode]?['irrigation_type'] ??
      _strings['en']!['irrigation_type']!;
  String get waterSource =>
      _strings[languageCode]?['water_source'] ??
      _strings['en']!['water_source']!;
  String get soilType =>
      _strings[languageCode]?['soil_type'] ?? _strings['en']!['soil_type']!;
  String get farmingPriority =>
      _strings[languageCode]?['farmingPriority'] ?? _strings['en']!['farmingPriority']!;
  String get farmingPriorityHint =>
      _strings[languageCode]?['farmingPriorityHint'] ?? _strings['en']!['farmingPriorityHint']!;
  String get farmingPriorityMaxProfit =>
      _strings[languageCode]?['farmingPriorityMaxProfit'] ?? _strings['en']!['farmingPriorityMaxProfit']!;
  String get farmingPriorityLowRisk =>
      _strings[languageCode]?['farmingPriorityLowRisk'] ?? _strings['en']!['farmingPriorityLowRisk']!;
  String get farmingPriorityQuickHarvest =>
      _strings[languageCode]?['farmingPriorityQuickHarvest'] ?? _strings['en']!['farmingPriorityQuickHarvest']!;
  String get farmingPriorityLowWater =>
      _strings[languageCode]?['farmingPriorityLowWater'] ?? _strings['en']!['farmingPriorityLowWater']!;
  String get farmingPriorityBalanced =>
      _strings[languageCode]?['farmingPriorityBalanced'] ?? _strings['en']!['farmingPriorityBalanced']!;
  String get farmerPreference =>
      _strings[languageCode]?['farmerPreference'] ?? _strings['en']!['farmerPreference']!;
  String get farmerPreferenceHint =>
      _strings[languageCode]?['farmerPreferenceHint'] ?? _strings['en']!['farmerPreferenceHint']!;
  String get autoCollectedContext =>
      _strings[languageCode]?['autoCollectedContext'] ?? _strings['en']!['autoCollectedContext']!;
  String get ctxWeatherMarket =>
      _strings[languageCode]?['ctxWeatherMarket'] ?? _strings['en']!['ctxWeatherMarket']!;
  String get aiSoilScan =>
      _strings[languageCode]?['ai_soil_scan'] ??
      _strings['en']!['ai_soil_scan']!;
  String get farmDetails =>
      _strings[languageCode]?['farm_details'] ??
      _strings['en']!['farm_details']!;
  String get confirmDeleteFarm =>
      _strings[languageCode]?['confirm_delete_farm'] ??
      _strings['en']!['confirm_delete_farm']!;
  String get yes => _strings[languageCode]?['yes'] ?? _strings['en']!['yes']!;
  String get no => _strings[languageCode]?['no'] ?? _strings['en']!['no']!;
  String get cancel =>
      _strings[languageCode]?['cancel'] ?? _strings['en']!['cancel']!;
  String get save =>
      _strings[languageCode]?['save'] ?? _strings['en']!['save']!;
  String get next =>
      _strings[languageCode]?['next'] ?? _strings['en']!['next']!;
  String get completeProfileForm =>
      _strings[languageCode]?['complete_profile_form'] ??
      _strings['en']!['complete_profile_form']!;
  String get addressSearchHint =>
      _strings[languageCode]?['address_search_hint'] ??
      _strings['en']!['address_search_hint']!;
  String get locationSearchError =>
      _strings[languageCode]?['location_search_error'] ??
      _strings['en']!['location_search_error']!;
  String get waterAvailability =>
      _strings[languageCode]?['water_availability'] ??
      _strings['en']!['water_availability']!;

  // Misc
  String get errorUnavailable =>
      _strings[languageCode]?['error_unavailable'] ??
      _strings['en']!['error_unavailable']!;
  String get selectOneLanguage =>
      _strings[languageCode]?['select_one_language'] ??
      _strings['en']!['select_one_language']!;

  // Tools screen
  String get smartFarmingUtilities =>
      _strings[languageCode]?['smart_farming_utilities'] ??
      _strings['en']!['smart_farming_utilities']!;
  String get pestDetectDesc =>
      _strings[languageCode]?['pest_detect_desc'] ??
      _strings['en']!['pest_detect_desc']!;
  String get fertilizerGuide =>
      _strings[languageCode]?['fertilizer_guide'] ??
      _strings['en']!['fertilizer_guide']!;
  String get fertilizerGuideDesc =>
      _strings[languageCode]?['fertilizer_guide_desc'] ??
      _strings['en']!['fertilizer_guide_desc']!;
  String get liveMandiPrices =>
      _strings[languageCode]?['live_mandi_prices'] ??
      _strings['en']!['live_mandi_prices']!;
  String get cropSearch =>
      _strings[languageCode]?['crop_search'] ?? _strings['en']!['crop_search']!;
  String get cropSearchDesc =>
      _strings[languageCode]?['crop_search_desc'] ??
      _strings['en']!['crop_search_desc']!;
  String get soilScanner =>
      _strings[languageCode]?['soil_scanner'] ??
      _strings['en']!['soil_scanner']!;
  String get soilScannerDesc =>
      _strings[languageCode]?['soil_scanner_desc'] ??
      _strings['en']!['soil_scanner_desc']!;
  String get aiAssistant =>
      _strings[languageCode]?['ai_assistant'] ??
      _strings['en']!['ai_assistant']!;

  String get aiChatTitle =>
      _strings[languageCode]?['ai_chat_title'] ??
      _strings['en']!['ai_chat_title']!;

  String get aiChatAssistantHeading =>
      _strings[languageCode]?['ai_chat_assistant_heading'] ??
      _strings['en']!['ai_chat_assistant_heading']!;
  String get askFarmingDesc =>
      _strings[languageCode]?['ask_farming_desc'] ??
      _strings['en']!['ask_farming_desc']!;
  String get govtSchemes =>
      _strings[languageCode]?['govt_schemes'] ??
      _strings['en']!['govt_schemes']!;
  String get govtSchemesDesc =>
      _strings[languageCode]?['govt_schemes_desc'] ??
      _strings['en']!['govt_schemes_desc']!;
  String get communityDesc =>
      _strings[languageCode]?['community_desc'] ??
      _strings['en']!['community_desc']!;

  // Weather screen
  String get weatherDataUnavailable =>
      _strings[languageCode]?['weather_data_unavailable'] ??
      _strings['en']!['weather_data_unavailable']!;
  String get hourlyForecastHeading =>
      _strings[languageCode]?['hourly_forecast_heading'] ??
      _strings['en']!['hourly_forecast_heading']!;
  String get dailyForecastHeading =>
      _strings[languageCode]?['daily_forecast_heading'] ??
      _strings['en']!['daily_forecast_heading']!;
  String get weatherLastUpdated =>
      _strings[languageCode]?['weather_last_updated'] ??
      _strings['en']!['weather_last_updated']!;
  String get weatherFeelsLike =>
      _strings[languageCode]?['weather_feels_like'] ??
      _strings['en']!['weather_feels_like']!;
  String get weatherHumidity =>
      _strings[languageCode]?['weather_humidity'] ??
      _strings['en']!['weather_humidity']!;
  String get weatherWind =>
      _strings[languageCode]?['weather_wind'] ??
      _strings['en']!['weather_wind']!;
  String get weatherDirection =>
      _strings[languageCode]?['weather_direction'] ??
      _strings['en']!['weather_direction']!;
  String get weatherPressure =>
      _strings[languageCode]?['weather_pressure'] ??
      _strings['en']!['weather_pressure']!;
  String get weatherGusts =>
      _strings[languageCode]?['weather_gusts'] ??
      _strings['en']!['weather_gusts']!;
  String get weatherRain =>
      _strings[languageCode]?['weather_rain'] ??
      _strings['en']!['weather_rain']!;
  String get weatherHourNow =>
      _strings[languageCode]?['weather_hour_now'] ??
      _strings['en']!['weather_hour_now']!;
  String get weatherDayToday =>
      _strings[languageCode]?['weather_day_today'] ??
      _strings['en']!['weather_day_today']!;
  String get weatherDayTomorrow =>
      _strings[languageCode]?['weather_day_tomorrow'] ??
      _strings['en']!['weather_day_tomorrow']!;
  String get weekdayMon =>
      _strings[languageCode]?['weekday_mon'] ?? _strings['en']!['weekday_mon']!;
  String get weekdayTue =>
      _strings[languageCode]?['weekday_tue'] ?? _strings['en']!['weekday_tue']!;
  String get weekdayWed =>
      _strings[languageCode]?['weekday_wed'] ?? _strings['en']!['weekday_wed']!;
  String get weekdayThu =>
      _strings[languageCode]?['weekday_thu'] ?? _strings['en']!['weekday_thu']!;
  String get weekdayFri =>
      _strings[languageCode]?['weekday_fri'] ?? _strings['en']!['weekday_fri']!;
  String get weekdaySat =>
      _strings[languageCode]?['weekday_sat'] ?? _strings['en']!['weekday_sat']!;
  String get weekdaySun =>
      _strings[languageCode]?['weekday_sun'] ?? _strings['en']!['weekday_sun']!;

  // Notification center
  String get notificationCenterTitle =>
      _strings[languageCode]?['notification_center_title'] ??
      _strings['en']!['notification_center_title']!;
  String get markAllAsRead =>
      _strings[languageCode]?['mark_all_as_read'] ??
      _strings['en']!['mark_all_as_read']!;
  String get noNotificationsYet =>
      _strings[languageCode]?['no_notifications_yet'] ??
      _strings['en']!['no_notifications_yet']!;
  String get notificationsEmptyHint =>
      _strings[languageCode]?['notifications_empty_hint'] ??
      _strings['en']!['notifications_empty_hint']!;
  String get timeAgoJustNow =>
      _strings[languageCode]?['time_ago_just_now'] ??
      _strings['en']!['time_ago_just_now']!;
  String get timeAgoM =>
      _strings[languageCode]?['time_ago_m'] ?? _strings['en']!['time_ago_m']!;
  String get timeAgoH =>
      _strings[languageCode]?['time_ago_h'] ?? _strings['en']!['time_ago_h']!;
  String get timeAgoD =>
      _strings[languageCode]?['time_ago_d'] ?? _strings['en']!['time_ago_d']!;

  // Recommendation loading
  String get loadingText1 =>
      _strings[languageCode]?['loading_text_1'] ??
      _strings['en']!['loading_text_1']!;
  String get loadingText2 =>
      _strings[languageCode]?['loading_text_2'] ??
      _strings['en']!['loading_text_2']!;
  String get loadingText3 =>
      _strings[languageCode]?['loading_text_3'] ??
      _strings['en']!['loading_text_3']!;
  String get loadingText4 =>
      _strings[languageCode]?['loading_text_4'] ??
      _strings['en']!['loading_text_4']!;
  String get recLoading =>
      _strings[languageCode]?['rec_loading'] ?? _strings['en']!['rec_loading']!;
  String get newPost =>
      _strings[languageCode]?['new_post'] ?? _strings['en']!['new_post']!;
  String get postBtn =>
      _strings[languageCode]?['post_btn'] ?? _strings['en']!['post_btn']!;
  String get postContentHint =>
      _strings[languageCode]?['post_content_hint'] ??
      _strings['en']!['post_content_hint']!;
  String get category =>
      _strings[languageCode]?['category'] ?? _strings['en']!['category']!;

  String get governmentSchemesTitle =>
      _strings[languageCode]?['government_schemes_title'] ??
      _strings['en']!['government_schemes_title']!;
  String get searchSchemes =>
      _strings[languageCode]?['search_schemes'] ??
      _strings['en']!['search_schemes']!;
  String get noSchemesFound =>
      _strings[languageCode]?['no_schemes_found'] ??
      _strings['en']!['no_schemes_found']!;
  String get stateBadge =>
      _strings[languageCode]?['state_badge'] ?? _strings['en']!['state_badge']!;
  String get requiredDocuments =>
      _strings[languageCode]?['required_documents'] ??
      _strings['en']!['required_documents']!;
  String get websiteUrlCopied =>
      _strings[languageCode]?['website_url_copied'] ??
      _strings['en']!['website_url_copied']!;
  String get visitOfficialWebsite =>
      _strings[languageCode]?['visit_official_website'] ??
      _strings['en']!['visit_official_website']!;
  String get helplineNumberCopied =>
      _strings[languageCode]?['helpline_number_copied'] ??
      _strings['en']!['helpline_number_copied']!;
  String get helplineLabel =>
      _strings[languageCode]?['helpline_label'] ??
      _strings['en']!['helpline_label']!;
  String get aboutSection =>
      _strings[languageCode]?['about_section'] ??
      _strings['en']!['about_section']!;
  String get eligibility =>
      _strings[languageCode]?['eligibility'] ?? _strings['en']!['eligibility']!;
  String get benefits =>
      _strings[languageCode]?['benefits'] ?? _strings['en']!['benefits']!;
  String get howToApply =>
      _strings[languageCode]?['how_to_apply'] ??
      _strings['en']!['how_to_apply']!;

  String get cropSearchTitle =>
      _strings[languageCode]?['crop_search_title'] ??
      _strings['en']!['crop_search_title']!;
  String get cropSearchHint =>
      _strings[languageCode]?['crop_search_hint'] ??
      _strings['en']!['crop_search_hint']!;
  String get cropSearchCount =>
      _strings[languageCode]?['crop_search_count'] ??
      _strings['en']!['crop_search_count']!;
  String get noCropsFound =>
      _strings[languageCode]?['no_crops_found'] ??
      _strings['en']!['no_crops_found']!;
  String get growthDetailsHeading =>
      _strings[languageCode]?['growth_details_heading'] ??
      _strings['en']!['growth_details_heading']!;
  String get duration =>
      _strings[languageCode]?['duration'] ?? _strings['en']!['duration']!;
  String get water =>
      _strings[languageCode]?['water'] ?? _strings['en']!['water']!;
  String get temperature =>
      _strings[languageCode]?['temperature'] ?? _strings['en']!['temperature']!;
  String get season =>
      _strings[languageCode]?['season'] ?? _strings['en']!['season']!;
  String get sowing =>
      _strings[languageCode]?['sowing'] ?? _strings['en']!['sowing']!;
  String get harvest =>
      _strings[languageCode]?['harvest'] ?? _strings['en']!['harvest']!;
  String get investmentReturnsHeading =>
      _strings[languageCode]?['investment_returns_heading'] ??
      _strings['en']!['investment_returns_heading']!;
  String get investmentPerAcre =>
      _strings[languageCode]?['investment_per_acre'] ??
      _strings['en']!['investment_per_acre']!;
  String get expectedYield =>
      _strings[languageCode]?['expected_yield'] ??
      _strings['en']!['expected_yield']!;
  String get revenuePerAcre =>
      _strings[languageCode]?['revenue_per_acre'] ??
      _strings['en']!['revenue_per_acre']!;
  String get profitPerAcre =>
      _strings[languageCode]?['profit_per_acre'] ??
      _strings['en']!['profit_per_acre']!;
  String get suitableRegionsHeading =>
      _strings[languageCode]?['suitable_regions_heading'] ??
      _strings['en']!['suitable_regions_heading']!;
  String get suitableSoilsLabel =>
      _strings[languageCode]?['suitable_soils_label'] ??
      _strings['en']!['suitable_soils_label']!;
  String get suitableStatesLabel =>
      _strings[languageCode]?['suitable_states_label'] ??
      _strings['en']!['suitable_states_label']!;
  String get agroClimaticLabel =>
      _strings[languageCode]?['agro_climatic_label'] ??
      _strings['en']!['agro_climatic_label']!;
  String get marketRiskHeading =>
      _strings[languageCode]?['market_risk_heading'] ??
      _strings['en']!['market_risk_heading']!;
  String get marketDemand =>
      _strings[languageCode]?['market_demand'] ??
      _strings['en']!['market_demand']!;
  String get riskLevel =>
      _strings[languageCode]?['risk_level'] ?? _strings['en']!['risk_level']!;
  String get cropAnalysisLoading =>
      _strings[languageCode]?['crop_analysis_loading'] ??
      _strings['en']!['crop_analysis_loading']!;
  String get noFarmsFoundTitle =>
      _strings[languageCode]?['no_farms_found_title'] ??
      _strings['en']!['no_farms_found_title']!;
  String get noFarmsFoundBody =>
      _strings[languageCode]?['no_farms_found_body'] ??
      _strings['en']!['no_farms_found_body']!;
  String get ok => _strings[languageCode]?['ok'] ?? _strings['en']!['ok']!;
  String get cropAnalysisTitle =>
      _strings[languageCode]?['crop_analysis_title'] ??
      _strings['en']!['crop_analysis_title']!;
  String get errorPrefix =>
      _strings[languageCode]?['error_prefix'] ??
      _strings['en']!['error_prefix']!;
  String get close =>
      _strings[languageCode]?['close'] ?? _strings['en']!['close']!;
  String get analysisFailed =>
      _strings[languageCode]?['analysis_failed'] ??
      _strings['en']!['analysis_failed']!;
  String get analyzeForMyFarm =>
      _strings[languageCode]?['analyze_for_my_farm'] ??
      _strings['en']!['analyze_for_my_farm']!;

  String get aiRecommendationLoading =>
      _strings[languageCode]?['ai_recommendation_loading'] ??
      _strings['en']!['ai_recommendation_loading']!;
  String get aiRecommendationTitle =>
      _strings[languageCode]?['ai_recommendation_title'] ??
      _strings['en']!['ai_recommendation_title']!;
  String get aiRecommendationFailed =>
      _strings[languageCode]?['ai_recommendation_failed'] ??
      _strings['en']!['ai_recommendation_failed']!;
  String get aiRecommendationTitle2 =>
      _strings[languageCode]?['ai_recommendation_title'] ??
      _strings['en']!['ai_recommendation_title']!;
  String get searchFertilizersHint =>
      _strings[languageCode]?['search_fertilizers_hint'] ??
      _strings['en']!['search_fertilizers_hint']!;
  String get fertilizerCount =>
      _strings[languageCode]?['fertilizer_count'] ??
      _strings['en']!['fertilizer_count']!;
  String get noFertilizersFound =>
      _strings[languageCode]?['no_fertilizers_found'] ??
      _strings['en']!['no_fertilizers_found']!;
  String get npkPrefix =>
      _strings[languageCode]?['npk_prefix'] ?? _strings['en']!['npk_prefix']!;
  String get useCaseLabel =>
      _strings[languageCode]?['use_case_label'] ??
      _strings['en']!['use_case_label']!;
  String get targetCropsLabel =>
      _strings[languageCode]?['target_crops_label'] ??
      _strings['en']!['target_crops_label']!;
  String get applicationRateLabel =>
      _strings[languageCode]?['application_rate_label'] ??
      _strings['en']!['application_rate_label']!;

  String get searchCommodityHint =>
      _strings[languageCode]?['search_commodity_hint'] ??
      _strings['en']!['search_commodity_hint']!;
  String get loading =>
      _strings[languageCode]?['loading'] ?? _strings['en']!['loading']!;
  String get commodityPricesCount =>
      _strings[languageCode]?['commodity_prices_count'] ??
      _strings['en']!['commodity_prices_count']!;
  String get failedToLoadPrices =>
      _strings[languageCode]?['failed_to_load_prices'] ??
      _strings['en']!['failed_to_load_prices']!;
  String get retry =>
      _strings[languageCode]?['retry'] ?? _strings['en']!['retry']!;
  String get noPricesFound =>
      _strings[languageCode]?['no_prices_found'] ??
      _strings['en']!['no_prices_found']!;
  String get priceMinLabel =>
      _strings[languageCode]?['price_min_label'] ??
      _strings['en']!['price_min_label']!;
  String get priceModalLabel =>
      _strings[languageCode]?['price_modal_label'] ??
      _strings['en']!['price_modal_label']!;
  String get priceMaxLabel =>
      _strings[languageCode]?['price_max_label'] ??
      _strings['en']!['price_max_label']!;

  String get marketPricesSubtitle =>
      _strings[languageCode]?['mk_subtitle'] ?? _strings['en']!['mk_subtitle']!;
  String get marketOverview =>
      _strings[languageCode]?['mk_overview'] ?? _strings['en']!['mk_overview']!;
  String get marketStatesCovered =>
      _strings[languageCode]?['mk_states_covered'] ??
      _strings['en']!['mk_states_covered']!;
  String get marketDataPoints =>
      _strings[languageCode]?['mk_data_points'] ??
      _strings['en']!['mk_data_points']!;
  String get marketLatestUpdate =>
      _strings[languageCode]?['mk_latest_update'] ??
      _strings['en']!['mk_latest_update']!;
  String get marketCommoditiesAvailable =>
      _strings[languageCode]?['mk_commodities'] ??
      _strings['en']!['mk_commodities']!;
  String get marketSearchHint =>
      _strings[languageCode]?['mk_search_hint'] ??
      _strings['en']!['mk_search_hint']!;
  String get marketSelectState =>
      _strings[languageCode]?['mk_select_state'] ??
      _strings['en']!['mk_select_state']!;
  String get marketSelectDistrict =>
      _strings[languageCode]?['mk_select_district'] ??
      _strings['en']!['mk_select_district']!;
  String get marketSelectCommodity =>
      _strings[languageCode]?['mk_select_commodity'] ??
      _strings['en']!['mk_select_commodity']!;
  String get refresh =>
      _strings[languageCode]?['mk_refresh'] ?? _strings['en']!['mk_refresh']!;
  String get marketStateDashboard =>
      _strings[languageCode]?['mk_state_dashboard'] ??
      _strings['en']!['mk_state_dashboard']!;
  String get marketLatestPrices =>
      _strings[languageCode]?['mk_latest_prices'] ??
      _strings['en']!['mk_latest_prices']!;
  String get marketDistrictPrices =>
      _strings[languageCode]?['mk_district_prices'] ??
      _strings['en']!['mk_district_prices']!;
  String get marketMarket =>
      _strings[languageCode]?['mk_market'] ?? _strings['en']!['mk_market']!;
  String get marketCommodity =>
      _strings[languageCode]?['mk_commodity'] ??
      _strings['en']!['mk_commodity']!;
  String get marketVariety =>
      _strings[languageCode]?['mk_variety'] ?? _strings['en']!['mk_variety']!;
  String get marketPricePerKg =>
      _strings[languageCode]?['mk_price_per_kg'] ??
      _strings['en']!['mk_price_per_kg']!;
  String get marketMinPrice =>
      _strings[languageCode]?['mk_min_price'] ??
      _strings['en']!['mk_min_price']!;
  String get marketModalPrice =>
      _strings[languageCode]?['mk_modal_price'] ??
      _strings['en']!['mk_modal_price']!;
  String get marketMaxPrice =>
      _strings[languageCode]?['mk_max_price'] ??
      _strings['en']!['mk_max_price']!;
  String get marketUpdated =>
      _strings[languageCode]?['mk_updated'] ?? _strings['en']!['mk_updated']!;
  String get marketLastUpdated =>
      _strings[languageCode]?['mk_last_updated'] ??
      _strings['en']!['mk_last_updated']!;
  String get marketOriginalUnit =>
      _strings[languageCode]?['mk_original_unit'] ??
      _strings['en']!['mk_original_unit']!;
  String get marketUnitConversion =>
      _strings[languageCode]?['mk_unit_conversion'] ??
      _strings['en']!['mk_unit_conversion']!;
  String get marketPriceUnitUnavailable =>
      _strings[languageCode]?['mk_price_unit_unavailable'] ??
      _strings['en']!['mk_price_unit_unavailable']!;
  String get marketAllIndia =>
      _strings[languageCode]?['mk_all_india'] ??
      _strings['en']!['mk_all_india']!;
  String get marketAllIndiaDetail =>
      _strings[languageCode]?['mk_all_india_detail'] ??
      _strings['en']!['mk_all_india_detail']!;
  String get marketOfflineBanner =>
      _strings[languageCode]?['mk_offline_banner'] ??
      _strings['en']!['mk_offline_banner']!;
  String get marketInsightHeading =>
      _strings[languageCode]?['mk_insight'] ?? _strings['en']!['mk_insight']!;
  String get marketInsightEmpty =>
      _strings[languageCode]?['mk_insight_empty'] ??
      _strings['en']!['mk_insight_empty']!;
  String get marketDisclaimer =>
      _strings[languageCode]?['mk_disclaimer'] ??
      _strings['en']!['mk_disclaimer']!;
  String get marketViewDetails =>
      _strings[languageCode]?['mk_view_details'] ??
      _strings['en']!['mk_view_details']!;
  String get marketArrivals =>
      _strings[languageCode]?['mk_arrivals'] ?? _strings['en']!['mk_arrivals']!;
  String get marketSource =>
      _strings[languageCode]?['mk_source'] ?? _strings['en']!['mk_source']!;
  String get marketNoPrices =>
      _strings[languageCode]?['mk_no_prices'] ??
      _strings['en']!['mk_no_prices']!;
  String get marketDistricts =>
      _strings[languageCode]?['mk_districts'] ??
      _strings['en']!['mk_districts']!;
  String get marketStates =>
      _strings[languageCode]?['mk_states'] ?? _strings['en']!['mk_states']!;

  String get unionTerritory =>
      _strings[languageCode]?['mk_union_territory'] ??
      _strings['en']!['mk_union_territory']!;
  String get marketState =>
      _strings[languageCode]?['mk_state'] ?? _strings['en']!['mk_state']!;
  String get marketTapCommodity =>
      _strings[languageCode]?['mk_tap_commodity'] ??
      _strings['en']!['mk_tap_commodity']!;
  String get marketBackToIndia =>
      _strings[languageCode]?['mk_back_to_india'] ??
      _strings['en']!['mk_back_to_india']!;
  String get marketFarmContext =>
      _strings[languageCode]?['mk_farm_context'] ??
      _strings['en']!['mk_farm_context']!;
  String get marketPriceHistory =>
      _strings[languageCode]?['mk_price_history'] ??
      _strings['en']!['mk_price_history']!;
  String get marketHistory7d =>
      _strings[languageCode]?['mk_history_7d'] ??
      _strings['en']!['mk_history_7d']!;
  String get marketHistory30d =>
      _strings[languageCode]?['mk_history_30d'] ??
      _strings['en']!['mk_history_30d']!;
  String get marketHistoryNone =>
      _strings[languageCode]?['mk_history_none'] ??
      _strings['en']!['mk_history_none']!;
  String get marketHistoryNote =>
      _strings[languageCode]?['mk_history_note'] ??
      _strings['en']!['mk_history_note']!;

  String get pestPickImageFailed =>
      _strings[languageCode]?['pest_pick_image_failed'] ??
      _strings['en']!['pest_pick_image_failed']!;
  String get pestValidateMessage =>
      _strings[languageCode]?['pest_validate_message'] ??
      _strings['en']!['pest_validate_message']!;
  String get treatmentImmediate =>
      _strings[languageCode]?['treatment_immediate'] ??
      _strings['en']!['treatment_immediate']!;
  String get treatmentBiological =>
      _strings[languageCode]?['treatment_biological'] ??
      _strings['en']!['treatment_biological']!;
  String get treatmentChemical =>
      _strings[languageCode]?['treatment_chemical'] ??
      _strings['en']!['treatment_chemical']!;
  String get unknown =>
      _strings[languageCode]?['unknown'] ?? _strings['en']!['unknown']!;
  String get pestTreatmentFallback =>
      _strings[languageCode]?['pest_treatment_fallback'] ??
      _strings['en']!['pest_treatment_fallback']!;
  String get pestPreventionFallback =>
      _strings[languageCode]?['pest_prevention_fallback'] ??
      _strings['en']!['pest_prevention_fallback']!;
  String get pestSeverityScore =>
      _strings[languageCode]?['pest_severity_score'] ??
      _strings['en']!['pest_severity_score']!;
  String get crop =>
      _strings[languageCode]?['crop'] ?? _strings['en']!['crop']!;
  String get pestAnalysisErrorTitle =>
      _strings[languageCode]?['pest_analysis_error_title'] ??
      _strings['en']!['pest_analysis_error_title']!;
  String get pestAnalyzeFailed =>
      _strings[languageCode]?['pest_analyze_failed'] ??
      _strings['en']!['pest_analyze_failed']!;
  String get pestNoFarmMessage =>
      _strings[languageCode]?['pest_no_farm_message'] ??
      _strings['en']!['pest_no_farm_message']!;
  String get pestSavedRecordsSnackbar =>
      _strings[languageCode]?['pest_saved_records_snackbar'] ??
      _strings['en']!['pest_saved_records_snackbar']!;
  String get pestDetectHeader =>
      _strings[languageCode]?['pest_detect_header'] ??
      _strings['en']!['pest_detect_header']!;
  String get pestStepCropTitle =>
      _strings[languageCode]?['pest_step_crop_title'] ??
      _strings['en']!['pest_step_crop_title']!;
  String get pestCropHint =>
      _strings[languageCode]?['pest_crop_hint'] ??
      _strings['en']!['pest_crop_hint']!;
  String get pestStepPhotosTitle =>
      _strings[languageCode]?['pest_step_photos_title'] ??
      _strings['en']!['pest_step_photos_title']!;
  String get camera =>
      _strings[languageCode]?['camera'] ?? _strings['en']!['camera']!;
  String get gallery =>
      _strings[languageCode]?['gallery'] ?? _strings['en']!['gallery']!;
  String get pestPhotosSelected =>
      _strings[languageCode]?['pest_photos_selected'] ??
      _strings['en']!['pest_photos_selected']!;
  String get pestAiAnalysisTitle =>
      _strings[languageCode]?['pest_ai_analysis_title'] ??
      _strings['en']!['pest_ai_analysis_title']!;
  String get analyzeImagesButton =>
      _strings[languageCode]?['analyze_images_button'] ??
      _strings['en']!['analyze_images_button']!;
  String get pestAnalyzingHeading =>
      _strings[languageCode]?['pest_analyzing_heading'] ??
      _strings['en']!['pest_analyzing_heading']!;
  String get pestAnalyzingBody =>
      _strings[languageCode]?['pest_analyzing_body'] ??
      _strings['en']!['pest_analyzing_body']!;
  String get pestAiAnalysisTitle2 =>
      _strings[languageCode]?['pest_ai_analysis_title'] ??
      _strings['en']!['pest_ai_analysis_title']!;
  String get riskSuffix =>
      _strings[languageCode]?['risk_suffix'] ?? _strings['en']!['risk_suffix']!;
  String get pestBasedOnVisual =>
      _strings[languageCode]?['pest_based_on_visual'] ??
      _strings['en']!['pest_based_on_visual']!;
  String get pestConfidence =>
      _strings[languageCode]?['pest_confidence'] ??
      _strings['en']!['pest_confidence']!;
  String get pestTreatmentLabel =>
      _strings[languageCode]?['pest_treatment_label'] ??
      _strings['en']!['pest_treatment_label']!;
  String get pestPreventionLabel =>
      _strings[languageCode]?['pest_prevention_label'] ??
      _strings['en']!['pest_prevention_label']!;
  String get pestDisclaimer =>
      _strings[languageCode]?['pest_disclaimer'] ??
      _strings['en']!['pest_disclaimer']!;
  String get pestSavedButton =>
      _strings[languageCode]?['pest_saved_button'] ??
      _strings['en']!['pest_saved_button']!;
  String get pestSaveButton =>
      _strings[languageCode]?['pest_save_button'] ??
      _strings['en']!['pest_save_button']!;

  // Main shell screen
  String get home =>
      _strings[languageCode]?['home'] ?? _strings['en']!['home']!;
  String get farm =>
      _strings[languageCode]?['farm'] ?? _strings['en']!['farm']!;
  String get tools =>
      _strings[languageCode]?['tools'] ?? _strings['en']!['tools']!;
  String get account =>
      _strings[languageCode]?['account'] ?? _strings['en']!['account']!;

  // Account screen
  String get userFallback =>
      _strings[languageCode]?['user_fallback'] ??
      _strings['en']!['user_fallback']!;
  String get editProfile =>
      _strings[languageCode]?['edit_profile'] ??
      _strings['en']!['edit_profile']!;
  String get language =>
      _strings[languageCode]?['language'] ?? _strings['en']!['language']!;
  String get appearance =>
      _strings[languageCode]?['appearance'] ?? _strings['en']!['appearance']!;
  String get notifications =>
      _strings[languageCode]?['notifications'] ??
      _strings['en']!['notifications']!;
  String get helpSupport =>
      _strings[languageCode]?['help_support'] ??
      _strings['en']!['help_support']!;
  String get aboutVidhai =>
      _strings[languageCode]?['about_vidhai'] ??
      _strings['en']!['about_vidhai']!;
  String get console =>
      _strings[languageCode]?['console'] ?? _strings['en']!['console']!;
  String get googleAccount =>
      _strings[languageCode]?['google_account'] ??
      _strings['en']!['google_account']!;
  String get googleAlreadyLinked =>
      _strings[languageCode]?['google_already_linked'] ??
      _strings['en']!['google_already_linked']!;
  String get googleAlreadyLinkedMsg =>
      _strings[languageCode]?['google_already_linked_msg'] ??
      _strings['en']!['google_already_linked_msg']!;
  String get googleLinkFailed =>
      _strings[languageCode]?['google_link_failed'] ??
      _strings['en']!['google_link_failed']!;
  String get googleAlreadyLinkedMsgAr =>
      _strings[languageCode]?['google_already_linked_msg_ar'] ??
      _strings['en']!['google_already_linked_msg_ar']!;
  String get invalidGoogleCredentials =>
      _strings[languageCode]?['invalid_google_credentials'] ??
      _strings['en']!['invalid_google_credentials']!;
  String get googleSigninCancelled =>
      _strings[languageCode]?['google_signin_cancelled'] ??
      _strings['en']!['google_signin_cancelled']!;
  String get signInWithGoogle =>
      _strings[languageCode]?['sign_in_with_google'] ??
      _strings['en']!['sign_in_with_google']!;
  String get signInDescription =>
      _strings[languageCode]?['sign_in_description'] ??
      _strings['en']!['sign_in_description']!;
  String get signingIn =>
      _strings[languageCode]?['signing_in'] ?? _strings['en']!['signing_in']!;
  String get signInFailed =>
      _strings[languageCode]?['sign_in_failed'] ??
      _strings['en']!['sign_in_failed']!;
  String get signInConfigError =>
      _strings[languageCode]?['sign_in_config_error'] ??
      _strings['en']!['sign_in_config_error']!;
  // Post detail screen
  String get postTitle =>
      _strings[languageCode]?['post_title'] ?? _strings['en']!['post_title']!;
  String get comments =>
      _strings[languageCode]?['comments'] ?? _strings['en']!['comments']!;
  String get noCommentsYet =>
      _strings[languageCode]?['no_comments_yet'] ??
      _strings['en']!['no_comments_yet']!;
  String get writeCommentHint =>
      _strings[languageCode]?['write_comment_hint'] ??
      _strings['en']!['write_comment_hint']!;
  String get timeAgoNow =>
      _strings[languageCode]?['time_ago_now'] ??
      _strings['en']!['time_ago_now']!;

  // Time ago short methods
  String timeAgoShortM(String minutes) =>
      _strings[languageCode]?['time_ago_short_m'] ??
      _strings['en']!['time_ago_short_m']!;
  String timeAgoShortH(String hours) =>
      _strings[languageCode]?['time_ago_short_h'] ??
      _strings['en']!['time_ago_short_h']!;
  String timeAgoShortD(String days) =>
      _strings[languageCode]?['time_ago_short_d'] ??
      _strings['en']!['time_ago_short_d']!;
  String timeAgoShortW(String weeks) =>
      _strings[languageCode]?['time_ago_short_w'] ??
      _strings['en']!['time_ago_short_w']!;

  // Farmer home screen
  String get goodMorning =>
      _strings[languageCode]?['good_morning'] ??
      _strings['en']!['good_morning']!;
  String get goodAfternoon =>
      _strings[languageCode]?['good_afternoon'] ??
      _strings['en']!['good_afternoon']!;
  String get goodEvening =>
      _strings[languageCode]?['good_evening'] ??
      _strings['en']!['good_evening']!;
  String get goodNight =>
      _strings[languageCode]?['good_night'] ?? _strings['en']!['good_night']!;
  String get quote1 =>
      _strings[languageCode]?['quote1'] ?? _strings['en']!['quote1']!;
  String get quote2 =>
      _strings[languageCode]?['quote2'] ?? _strings['en']!['quote2']!;
  String get quote3 =>
      _strings[languageCode]?['quote3'] ?? _strings['en']!['quote3']!;
  String get quote4 =>
      _strings[languageCode]?['quote4'] ?? _strings['en']!['quote4']!;
  String get quote5 =>
      _strings[languageCode]?['quote5'] ?? _strings['en']!['quote5']!;
  String get addFarmLocationWeather =>
      _strings[languageCode]?['add_farm_location_weather'] ??
      _strings['en']!['add_farm_location_weather']!;
  String get noWeatherData =>
      _strings[languageCode]?['no_weather_data'] ??
      _strings['en']!['no_weather_data']!;
  String get seeAll =>
      _strings[languageCode]?['see_all'] ?? _strings['en']!['see_all']!;
  String get moreTasks =>
      _strings[languageCode]?['more_tasks'] ?? _strings['en']!['more_tasks']!;

  // Crop setup screen
  String get cropSetup =>
      _strings[languageCode]?['crop_setup'] ?? _strings['en']!['crop_setup']!;
  String get cropSetupHelpText =>
      _strings[languageCode]?['crop_setup_help_text'] ??
      _strings['en']!['crop_setup_help_text']!;
  String get lastCropGrown =>
      _strings[languageCode]?['last_crop_grown'] ??
      _strings['en']!['last_crop_grown']!;
  String get hintLastCrop =>
      _strings[languageCode]?['hint_last_crop'] ??
      _strings['en']!['hint_last_crop']!;
  String get whenWasItHarvested =>
      _strings[languageCode]?['when_was_it_harvested'] ??
      _strings['en']!['when_was_it_harvested']!;
  String get selectHarvestDate =>
      _strings[languageCode]?['select_harvest_date'] ??
      _strings['en']!['select_harvest_date']!;
  String get howLongLandIdle =>
      _strings[languageCode]?['how_long_land_idle'] ??
      _strings['en']!['how_long_land_idle']!;
  String get selectDuration =>
      _strings[languageCode]?['select_duration'] ??
      _strings['en']!['select_duration']!;
  String get whenLastIrrigation =>
      _strings[languageCode]?['when_last_irrigation'] ??
      _strings['en']!['when_last_irrigation']!;
  String get selectLastIrrigationDate =>
      _strings[languageCode]?['select_last_irrigation_date'] ??
      _strings['en']!['select_last_irrigation_date']!;
  String get currentWaterAvailability =>
      _strings[languageCode]?['current_water_availability'] ??
      _strings['en']!['current_water_availability']!;
  String get selectSoilType =>
      _strings[languageCode]?['select_soil_type'] ??
      _strings['en']!['select_soil_type']!;
  String get soilCondition =>
      _strings[languageCode]?['soil_condition'] ??
      _strings['en']!['soil_condition']!;
  String get selectSoilCondition =>
      _strings[languageCode]?['select_soil_condition'] ??
      _strings['en']!['select_soil_condition']!;
  String get irrigationSystemAvailable =>
      _strings[languageCode]?['irrigation_system_available'] ??
      _strings['en']!['irrigation_system_available']!;
  String get selectIrrigationSystem =>
      _strings[languageCode]?['select_irrigation_system'] ??
      _strings['en']!['select_irrigation_system']!;
  String get autoFilledFromFarmData =>
      _strings[languageCode]?['auto_filled_from_farm_data'] ??
      _strings['en']!['auto_filled_from_farm_data']!;

  // Farm history screen
  String get previousExpenses =>
      _strings[languageCode]?['previous_expenses'] ??
      _strings['en']!['previous_expenses']!;
  String get noExpenseRecordsFound =>
      _strings[languageCode]?['no_expense_records_found'] ??
      _strings['en']!['no_expense_records_found']!;
  String get importantEvents =>
      _strings[languageCode]?['important_events'] ??
      _strings['en']!['important_events']!;
  String get noImportantEventsRecorded =>
      _strings[languageCode]?['no_important_events_recorded'] ??
      _strings['en']!['no_important_events_recorded']!;
  String get resolvedPrefix =>
      _strings[languageCode]?['resolved_prefix'] ??
      _strings['en']!['resolved_prefix']!;
  String get detectedPrefix =>
      _strings[languageCode]?['detected_prefix'] ??
      _strings['en']!['detected_prefix']!;
  String get noHistoryRecordsYet =>
      _strings[languageCode]?['no_history_records_yet'] ??
      _strings['en']!['no_history_records_yet']!;
  String get farmHistoryEmptyDesc =>
      _strings[languageCode]?['farm_history_empty_desc'] ??
      _strings['en']!['farm_history_empty_desc']!;

  // Disease screen
  String get diseasePestRecords =>
      _strings[languageCode]?['disease_pest_records'] ??
      _strings['en']!['disease_pest_records']!;
  String get editRecord =>
      _strings[languageCode]?['edit_record'] ?? _strings['en']!['edit_record']!;
  String get addDiseasePest =>
      _strings[languageCode]?['add_disease_pest'] ??
      _strings['en']!['add_disease_pest']!;
  String get detectedDate =>
      _strings[languageCode]?['detected_date'] ??
      _strings['en']!['detected_date']!;
  String get hintCrop =>
      _strings[languageCode]?['hint_crop'] ?? _strings['en']!['hint_crop']!;
  String get problem =>
      _strings[languageCode]?['problem'] ?? _strings['en']!['problem']!;
  String get hintProblem =>
      _strings[languageCode]?['hint_problem'] ??
      _strings['en']!['hint_problem']!;
  String get severity =>
      _strings[languageCode]?['severity'] ?? _strings['en']!['severity']!;
  String get selectSeverity =>
      _strings[languageCode]?['select_severity'] ??
      _strings['en']!['select_severity']!;
  String get treatmentOptional =>
      _strings[languageCode]?['treatment_optional'] ??
      _strings['en']!['treatment_optional']!;
  String get hintTreatment =>
      _strings[languageCode]?['hint_treatment'] ??
      _strings['en']!['hint_treatment']!;
  String get status =>
      _strings[languageCode]?['status'] ?? _strings['en']!['status']!;
  String get noDiseaseRecords =>
      _strings[languageCode]?['no_disease_records'] ??
      _strings['en']!['no_disease_records']!;
  String get trackDiseasesPests =>
      _strings[languageCode]?['track_diseases_pests'] ??
      _strings['en']!['track_diseases_pests']!;

  // Fertilizer screen
  String get fertilizerRecords =>
      _strings[languageCode]?['fertilizer_records'] ??
      _strings['en']!['fertilizer_records']!;
  String get qty => _strings[languageCode]?['qty'] ?? _strings['en']!['qty']!;
  String get method =>
      _strings[languageCode]?['method'] ?? _strings['en']!['method']!;
  String get deleteRecord =>
      _strings[languageCode]?['delete_record'] ??
      _strings['en']!['delete_record']!;
  String get delete =>
      _strings[languageCode]?['delete'] ?? _strings['en']!['delete']!;
  String get editFertilizerRecord =>
      _strings[languageCode]?['edit_fertilizer_record'] ??
      _strings['en']!['edit_fertilizer_record']!;
  String get addFertilizerRecord =>
      _strings[languageCode]?['add_fertilizer_record'] ??
      _strings['en']!['add_fertilizer_record']!;
  String get productName =>
      _strings[languageCode]?['product_name'] ??
      _strings['en']!['product_name']!;
  String get hintProductName =>
      _strings[languageCode]?['hint_product_name'] ??
      _strings['en']!['hint_product_name']!;
  String get type =>
      _strings[languageCode]?['type'] ?? _strings['en']!['type']!;
  String get selectType =>
      _strings[languageCode]?['select_type'] ?? _strings['en']!['select_type']!;
  String get date =>
      _strings[languageCode]?['date'] ?? _strings['en']!['date']!;
  String get quantity =>
      _strings[languageCode]?['quantity'] ?? _strings['en']!['quantity']!;
  String get hintQuantity =>
      _strings[languageCode]?['hint_quantity'] ??
      _strings['en']!['hint_quantity']!;
  String get applicationMethod =>
      _strings[languageCode]?['application_method'] ??
      _strings['en']!['application_method']!;
  String get hintApplicationMethod =>
      _strings[languageCode]?['hint_application_method'] ??
      _strings['en']!['hint_application_method']!;
  String get cropOptional =>
      _strings[languageCode]?['crop_optional'] ??
      _strings['en']!['crop_optional']!;
  String get hintCropWheatPaddy =>
      _strings[languageCode]?['hint_crop_wheat_paddy'] ??
      _strings['en']!['hint_crop_wheat_paddy']!;
  String get update =>
      _strings[languageCode]?['update'] ?? _strings['en']!['update']!;
  String get noFertilizerRecords =>
      _strings[languageCode]?['no_fertilizer_records'] ??
      _strings['en']!['no_fertilizer_records']!;
  String get trackFertilizerApplications =>
      _strings[languageCode]?['track_fertilizer_applications'] ??
      _strings['en']!['track_fertilizer_applications']!;

  // Pesticide screen
  String get pesticideRecords =>
      _strings[languageCode]?['pesticide_records'] ??
      _strings['en']!['pesticide_records']!;
  String get area =>
      _strings[languageCode]?['area'] ?? _strings['en']!['area']!;
  String get purpose =>
      _strings[languageCode]?['purpose'] ?? _strings['en']!['purpose']!;
  String get deleteRecord2 =>
      _strings[languageCode]?['delete_record'] ??
      _strings['en']!['delete_record']!;
  String get delete2 =>
      _strings[languageCode]?['delete'] ?? _strings['en']!['delete']!;
  String get editPesticideRecord =>
      _strings[languageCode]?['edit_pesticide_record'] ??
      _strings['en']!['edit_pesticide_record']!;
  String get addPesticideRecord =>
      _strings[languageCode]?['add_pesticide_record'] ??
      _strings['en']!['add_pesticide_record']!;
  String get productName2 =>
      _strings[languageCode]?['product_name'] ??
      _strings['en']!['product_name']!;
  String get hintProductNamePesticide =>
      _strings[languageCode]?['hint_product_name_pesticide'] ??
      _strings['en']!['hint_product_name_pesticide']!;
  String get date2 =>
      _strings[languageCode]?['date'] ?? _strings['en']!['date']!;
  String get quantity2 =>
      _strings[languageCode]?['quantity'] ?? _strings['en']!['quantity']!;
  String get hintQuantityMl =>
      _strings[languageCode]?['hint_quantity_ml'] ??
      _strings['en']!['hint_quantity_ml']!;
  String get applicationArea =>
      _strings[languageCode]?['application_area'] ??
      _strings['en']!['application_area']!;
  String get hintApplicationArea =>
      _strings[languageCode]?['hint_application_area'] ??
      _strings['en']!['hint_application_area']!;
  String get purpose2 =>
      _strings[languageCode]?['purpose'] ?? _strings['en']!['purpose']!;
  String get hintPurpose =>
      _strings[languageCode]?['hint_purpose'] ??
      _strings['en']!['hint_purpose']!;
  // Expense screen
  String expenseCountLabel(String count) =>
      _strings[languageCode]?['expense_count_label'] ??
      _strings['en']!['expense_count_label']!;
  String get deleteExpense =>
      _strings[languageCode]?['delete_expense'] ??
      _strings['en']!['delete_expense']!;
  String deleteExpenseConfirm(String category, String amount) =>
      _strings[languageCode]?['delete_expense_confirm'] ??
      _strings['en']!['delete_expense_confirm']!;
  String get editExpense =>
      _strings[languageCode]?['edit_expense'] ??
      _strings['en']!['edit_expense']!;
  String get addExpense =>
      _strings[languageCode]?['add_expense'] ?? _strings['en']!['add_expense']!;
  String get selectCategoryHint =>
      _strings[languageCode]?['select_category_hint'] ??
      _strings['en']!['select_category_hint']!;
  String get amount =>
      _strings[languageCode]?['amount'] ?? _strings['en']!['amount']!;
  String get description =>
      _strings[languageCode]?['description'] ?? _strings['en']!['description']!;
  String get hintDescription =>
      _strings[languageCode]?['hint_description'] ??
      _strings['en']!['hint_description']!;
  String get vendorOptional =>
      _strings[languageCode]?['vendor_optional'] ??
      _strings['en']!['vendor_optional']!;
  String get hintVendor =>
      _strings[languageCode]?['hint_vendor'] ?? _strings['en']!['hint_vendor']!;
  String get receiptPhotoOptional =>
      _strings[languageCode]?['receipt_photo_optional'] ??
      _strings['en']!['receipt_photo_optional']!;
  String get tapToAddReceipt =>
      _strings[languageCode]?['tap_to_add_receipt'] ??
      _strings['en']!['tap_to_add_receipt']!;
  String get noExpensesYet =>
      _strings[languageCode]?['no_expenses_yet'] ??
      _strings['en']!['no_expenses_yet']!;
  String get trackFarmExpenses =>
      _strings[languageCode]?['track_farm_expenses'] ??
      _strings['en']!['track_farm_expenses']!;

  String get cropOptional2 =>
      _strings[languageCode]?['crop_optional'] ??
      _strings['en']!['crop_optional']!;
  String get hintCropWheatRice =>
      _strings[languageCode]?['hint_crop_wheat_rice'] ??
      _strings['en']!['hint_crop_wheat_rice']!;
  String get notesOptional =>
      _strings[languageCode]?['notes_optional'] ??
      _strings['en']!['notes_optional']!;
  String get hintNotes =>
      _strings[languageCode]?['hint_notes'] ?? _strings['en']!['hint_notes']!;
  String get update2 =>
      _strings[languageCode]?['update'] ?? _strings['en']!['update']!;
  String get noPesticideRecords =>
      _strings[languageCode]?['no_pesticide_records'] ??
      _strings['en']!['no_pesticide_records']!;

  // Farmer home screen
  String get trackPesticideApplications =>
      _strings[languageCode]?['track_pesticide_applications'] ??
      _strings['en']!['track_pesticide_applications']!;

  // Farm history screen
  String get overview =>
      _strings[languageCode]?['overview'] ?? _strings['en']!['overview']!;
  String get previousTreatments =>
      _strings[languageCode]?['previous_treatments'] ??
      _strings['en']!['previous_treatments']!;
  String get diseases =>
      _strings[languageCode]?['diseases'] ?? _strings['en']!['diseases']!;
  String get previousCrops =>
      _strings[languageCode]?['previous_crops'] ??
      _strings['en']!['previous_crops']!;
  String get noCropRecordsFound =>
      _strings[languageCode]?['no_crop_records_found'] ??
      _strings['en']!['no_crop_records_found']!;
  String get noTreatmentRecordsFound =>
      _strings[languageCode]?['no_treatment_records_found'] ??
      _strings['en']!['no_treatment_records_found']!;
  String get noFertilizerRecordsFound =>
      _strings[languageCode]?['no_fertilizer_records_found'] ??
      _strings['en']!['no_fertilizer_records_found']!;
  String get diseaseRecords =>
      _strings[languageCode]?['disease_records'] ??
      _strings['en']!['disease_records']!;
  String get noIrrigationRecordsFound =>
      _strings[languageCode]?['no_irrigation_records_found'] ??
      _strings['en']!['no_irrigation_records_found']!;
  String recordCountLabel(String count) =>
      _strings[languageCode]?['record_count_label'] ??
      _strings['en']!['record_count_label']!;

  // Tasks screen
  String get todaysTasks =>
      _strings[languageCode]?['todays_tasks'] ??
      _strings['en']!['todays_tasks']!;
  String get tasksCompletedCount =>
      _strings[languageCode]?['tasks_completed_count'] ??
      _strings['en']!['tasks_completed_count']!;
  String get farmAssistantTitle =>
      _strings[languageCode]?['farm_assistant_title'] ??
      _strings['en']!['farm_assistant_title']!;
  String get aiAssistantWhatNow =>
      _strings[languageCode]?['ai_assistant_what_now'] ??
      _strings['en']!['ai_assistant_what_now']!;
  String get ask => _strings[languageCode]?['ask'] ?? _strings['en']!['ask']!;
  String get vidhaiAssistant =>
      _strings[languageCode]?['vidhai_assistant'] ??
      _strings['en']!['vidhai_assistant']!;
  String get assistantConfirm =>
      _strings[languageCode]?['assistant_confirm'] ??
      _strings['en']!['assistant_confirm']!;
  String get assistantWelcome =>
      _strings[languageCode]?['assistant_welcome'] ??
      _strings['en']!['assistant_welcome']!;
  String get assistantWelcomeBack =>
      _strings[languageCode]?['assistant_welcome_back'] ??
      _strings['en']!['assistant_welcome_back']!;
  String assistantWelcomeBackNamed(String name) =>
      (_strings[languageCode]?['assistant_welcome_back_named'] ??
              _strings['en']!['assistant_welcome_back_named']!)
          .replaceAll('{name}', name);
  String get assistantHint =>
      _strings[languageCode]?['assistant_hint'] ??
      _strings['en']!['assistant_hint']!;
  String get assistantLimit =>
      _strings[languageCode]?['assistant_limit'] ??
      _strings['en']!['assistant_limit']!;
  String get assistantReview =>
      _strings[languageCode]?['assistant_review'] ??
      _strings['en']!['assistant_review']!;
  String get askAboutFarm =>
      _strings[languageCode]?['ask_about_farm'] ??
      _strings['en']!['ask_about_farm']!;
  String get askVoiceOrTyping =>
      _strings[languageCode]?['ask_voice_or_typing'] ??
      _strings['en']!['ask_voice_or_typing']!;
  String get aiResponsePlaceholder =>
      _strings[languageCode]?['ai_response_placeholder'] ??
      _strings['en']!['ai_response_placeholder']!;
  String get noTasksYet =>
      _strings[languageCode]?['no_tasks_yet'] ??
      _strings['en']!['no_tasks_yet']!;
  String get configureFarmsSmartTasks =>
      _strings[languageCode]?['configure_farms_smart_tasks'] ??
      _strings['en']!['configure_farms_smart_tasks']!;

  // Farm screen
  String get myFarms =>
      _strings[languageCode]?['my_farms'] ?? _strings['en']!['my_farms']!;
  String get addFarm =>
      _strings[languageCode]?['add_farm'] ?? _strings['en']!['add_farm']!;
  String get noFarmsYet =>
      _strings[languageCode]?['no_farms_yet'] ??
      _strings['en']!['no_farms_yet']!;
  String get tapAddFarmToCreate =>
      _strings[languageCode]?['tap_add_farm_to_create'] ??
      _strings['en']!['tap_add_farm_to_create']!;
  String get myFarm =>
      _strings[languageCode]?['my_farm'] ?? _strings['en']!['my_farm']!;
  String get stage =>
      _strings[languageCode]?['stage'] ?? _strings['en']!['stage']!;
  String get currentStage =>
      _strings[languageCode]?['current_stage'] ??
      _strings['en']!['current_stage']!;
  String get edit =>
      _strings[languageCode]?['edit'] ?? _strings['en']!['edit']!;
  String get editFarm =>
      _strings[languageCode]?['edit_farm'] ?? _strings['en']!['edit_farm']!;
  String get cropStatus =>
      _strings[languageCode]?['crop_status'] ?? _strings['en']!['crop_status']!;
  String get farmInformation =>
      _strings[languageCode]?['farm_information'] ??
      _strings['en']!['farm_information']!;
  String get totalExpenses =>
      _strings[languageCode]?['total_expenses'] ??
      _strings['en']!['total_expenses']!;
  String get deleteFarm =>
      _strings[languageCode]?['delete_farm'] ?? _strings['en']!['delete_farm']!;
  String deleteFarmConfirm(String name) {
    final t = _strings[languageCode]?['delete_farm_confirm'] ??
        _strings['en']!['delete_farm_confirm']!;
    return t.replaceAll('{name}', name);
  }

  String get farmDeleted =>
      _strings[languageCode]?['farm_deleted'] ??
      _strings['en']!['farm_deleted']!;
  String get deleteFarmFailed =>
      _strings[languageCode]?['delete_farm_failed'] ??
      _strings['en']!['delete_farm_failed']!;
  String get totalFarms =>
      _strings[languageCode]?['total_farms'] ?? _strings['en']!['total_farms']!;
  String get activeFarms =>
      _strings[languageCode]?['active_farms'] ??
      _strings['en']!['active_farms']!;
  String get notConfigured =>
      _strings[languageCode]?['not_configured'] ??
      _strings['en']!['not_configured']!;
  String get noLocation =>
      _strings[languageCode]?['no_location'] ?? _strings['en']!['no_location']!;
  String get noCrop =>
      _strings[languageCode]?['no_crop'] ?? _strings['en']!['no_crop']!;
  String get loadingWeather =>
      _strings[languageCode]?['loading_weather'] ??
      _strings['en']!['loading_weather']!;

  // Crop setup screen
  String get currentSeason =>
      _strings[languageCode]?['current_season'] ??
      _strings['en']!['current_season']!;
  String get autoDetected =>
      _strings[languageCode]?['auto_detected'] ??
      _strings['en']!['auto_detected']!;
  String get cropDurationPreference =>
      _strings[languageCode]?['crop_duration_preference'] ??
      _strings['en']!['crop_duration_preference']!;
  String get cropCategoryPreference =>
      _strings[languageCode]?['crop_category_preference'] ??
      _strings['en']!['crop_category_preference']!;
  String get getRecommendations =>
      _strings[languageCode]?['get_recommendations'] ??
      _strings['en']!['get_recommendations']!;

  // Farm details screen
  String get farmNotFound =>
      _strings[languageCode]?['farm_not_found'] ??
      _strings['en']!['farm_not_found']!;
  String get active =>
      _strings[languageCode]?['active'] ?? _strings['en']!['active']!;
  String get noLocationSet =>
      _strings[languageCode]?['no_location_set'] ??
      _strings['en']!['no_location_set']!;
  String get size =>
      _strings[languageCode]?['size'] ?? _strings['en']!['size']!;
  String get notSet =>
      _strings[languageCode]?['not_set'] ?? _strings['en']!['not_set']!;
  String get cropInfo =>
      _strings[languageCode]?['crop_info'] ?? _strings['en']!['crop_info']!;
  String get configureCrop =>
      _strings[languageCode]?['configure_crop'] ??
      _strings['en']!['configure_crop']!;
  String get weather =>
      _strings[languageCode]?['weather'] ?? _strings['en']!['weather']!;
  String get tapToView =>
      _strings[languageCode]?['tap_to_view'] ?? _strings['en']!['tap_to_view']!;
  String get noDataYet =>
      _strings[languageCode]?['no_data_yet'] ?? _strings['en']!['no_data_yet']!;
  String get soil =>
      _strings[languageCode]?['soil'] ?? _strings['en']!['soil']!;
  String get expenses =>
      _strings[languageCode]?['expenses'] ?? _strings['en']!['expenses']!;
  String get viewRecords =>
      _strings[languageCode]?['view_records'] ??
      _strings['en']!['view_records']!;
  String get pesticides =>
      _strings[languageCode]?['pesticides'] ?? _strings['en']!['pesticides']!;
  String get fertilizers =>
      _strings[languageCode]?['fertilizers'] ?? _strings['en']!['fertilizers']!;
  String get disease =>
      _strings[languageCode]?['disease'] ?? _strings['en']!['disease']!;
  String get viewAlerts =>
      _strings[languageCode]?['view_alerts'] ?? _strings['en']!['view_alerts']!;
  String get history =>
      _strings[languageCode]?['history'] ?? _strings['en']!['history']!;
  String get farmHistory =>
      _strings[languageCode]?['farm_history'] ??
      _strings['en']!['farm_history']!;
  String get recommend =>
      _strings[languageCode]?['recommend'] ?? _strings['en']!['recommend']!;
  String get aiCropAdvice =>
      _strings[languageCode]?['ai_crop_advice'] ??
      _strings['en']!['ai_crop_advice']!;
  String get farming =>
      _strings[languageCode]?['farming'] ?? _strings['en']!['farming']!;
  String get farmingMethod =>
      _strings[languageCode]?['farming_method'] ??
      _strings['en']!['farming_method']!;
  String get noFarmingMethodConfigured =>
      _strings[languageCode]?['no_farming_method_configured'] ??
      _strings['en']!['no_farming_method_configured']!;
  String get availabilityLabel =>
      _strings[languageCode]?['availability_label'] ??
      _strings['en']!['availability_label']!;
  String get sourceLabel =>
      _strings[languageCode]?['source_label'] ??
      _strings['en']!['source_label']!;
  String get noWaterDataConfigured =>
      _strings[languageCode]?['no_water_data_configured'] ??
      _strings['en']!['no_water_data_configured']!;
  String get aiAnalysisLabel =>
      _strings[languageCode]?['ai_analysis_label'] ??
      _strings['en']!['ai_analysis_label']!;
  String get noSoilDataConfigured =>
      _strings[languageCode]?['no_soil_data_configured'] ??
      _strings['en']!['no_soil_data_configured']!;
  String get noIrrigationDataConfigured =>
      _strings[languageCode]?['no_irrigation_data_configured'] ??
      _strings['en']!['no_irrigation_data_configured']!;
  String get irrigation =>
      _strings[languageCode]?['irrigation'] ?? _strings['en']!['irrigation']!;
  String get typeLabel =>
      _strings[languageCode]?['type_label'] ?? _strings['en']!['type_label']!;

  // Community screen
  String get aiAssisted =>
      _strings[languageCode]?['ai_assisted'] ?? _strings['en']!['ai_assisted']!;
  String get communityCategoryGeneral =>
      _strings[languageCode]?['community_category_general'] ??
      _strings['en']!['community_category_general']!;
  String get communityCategoryCrops =>
      _strings[languageCode]?['community_category_crops'] ??
      _strings['en']!['community_category_crops']!;
  String get communityCategoryPestControl =>
      _strings[languageCode]?['community_category_pest_control'] ??
      _strings['en']!['community_category_pest_control']!;
  String get communityCategoryIrrigation =>
      _strings[languageCode]?['community_category_irrigation'] ??
      _strings['en']!['community_category_irrigation']!;
  String get communityCategoryMarket =>
      _strings[languageCode]?['community_category_market'] ??
      _strings['en']!['community_category_market']!;
  String get communityCategoryEquipment =>
      _strings[languageCode]?['community_category_equipment'] ??
      _strings['en']!['community_category_equipment']!;
  String get communityCategoryOrganic =>
      _strings[languageCode]?['community_category_organic'] ??
      _strings['en']!['community_category_organic']!;
  String get communityCategoryWeather =>
      _strings[languageCode]?['community_category_weather'] ??
      _strings['en']!['community_category_weather']!;
  String get communityCategorySchemes =>
      _strings[languageCode]?['community_category_schemes'] ??
      _strings['en']!['community_category_schemes']!;
  String get postPublished =>
      _strings[languageCode]?['post_published'] ??
      _strings['en']!['post_published']!;
  String get postFailed =>
      _strings[languageCode]?['post_failed'] ?? _strings['en']!['post_failed']!;

  String get linkGoogleAccount =>
      _strings[languageCode]?['link_google_account'] ??
      _strings['en']!['link_google_account']!;

  String get appearanceDesc =>
      _strings[languageCode]?['appearance_desc'] ??
      _strings['en']!['appearance_desc']!;

  String get lightMode =>
      _strings[languageCode]?['light_mode'] ?? _strings['en']!['light_mode']!;

  String get darkMode =>
      _strings[languageCode]?['dark_mode'] ?? _strings['en']!['dark_mode']!;

  String get mintTheme =>
      _strings[languageCode]?['mint_theme'] ?? _strings['en']!['mint_theme']!;

  String get pistachioTheme =>
      _strings[languageCode]?['pistachio_theme'] ??
      _strings['en']!['pistachio_theme']!;

  String get systemDefault =>
      _strings[languageCode]?['system_default'] ??
      _strings['en']!['system_default']!;

  String get followDeviceSetting =>
      _strings[languageCode]?['follow_device_setting'] ??
      _strings['en']!['follow_device_setting']!;

  String get logoutConfirmation =>
      _strings[languageCode]?['logout_confirmation'] ??
      _strings['en']!['logout_confirmation']!;

  String get emailUs =>
      _strings[languageCode]?['email_us'] ?? _strings['en']!['email_us']!;

  String get callUs =>
      _strings[languageCode]?['call_us'] ?? _strings['en']!['call_us']!;

  String get liveChat =>
      _strings[languageCode]?['live_chat'] ?? _strings['en']!['live_chat']!;

  String get liveChatAvailability =>
      _strings[languageCode]?['live_chat_availability'] ??
      _strings['en']!['live_chat_availability']!;

  String get faq => _strings[languageCode]?['faq'] ?? _strings['en']!['faq']!;

  String get helpCenter =>
      _strings[languageCode]?['help_center'] ?? _strings['en']!['help_center']!;

  String get copyrightNotice =>
      _strings[languageCode]?['copyright_notice'] ??
      _strings['en']!['copyright_notice']!;

  String get aboutDescription =>
      _strings[languageCode]?['about_description'] ??
      _strings['en']!['about_description']!;

  String get switchConsole =>
      _strings[languageCode]?['switch_console'] ??
      _strings['en']!['switch_console']!;

  String get consoleSwitched =>
      _strings[languageCode]?['console_switched'] ??
      _strings['en']!['console_switched']!;

  String get consoleSwitchedMessage =>
      _strings[languageCode]?['console_switched_message'] ??
      _strings['en']!['console_switched_message']!;

  String get linkGoogleDescription =>
      _strings[languageCode]?['link_google_description'] ??
      _strings['en']!['link_google_description']!;

  String get linkNow =>
      _strings[languageCode]?['link_now'] ?? _strings['en']!['link_now']!;

  String get googleLinkedSuccess =>
      _strings[languageCode]?['google_linked_success'] ??
      _strings['en']!['google_linked_success']!;

  String get googleLinkedOtherUser =>
      _strings[languageCode]?['google_linked_other_user'] ??
      _strings['en']!['google_linked_other_user']!;

  String get cropBudgetPerAcre =>
      _strings[languageCode]?['cropBudgetPerAcre'] ??
      _strings['en']!['cropBudgetPerAcre']!;

  String get cropBudgetHint =>
      _strings[languageCode]?['cropBudgetHint'] ??
      _strings['en']!['cropBudgetHint']!;

  String get cropBudgetHelper =>
      _strings[languageCode]?['cropBudgetHelper'] ??
      _strings['en']!['cropBudgetHelper']!;

  String t(String key) {
    final value = _strings[languageCode]?[key] ?? _strings['en']?[key];
    if (value != null && value.isNotEmpty) return value;
    debugPrint('[AppLocalizations] missing translation key: $key');
    return key;
  }

  // Consumer home + exploration
  String get helloNamed =>
      _strings[languageCode]?['hello_named'] ?? _strings['en']!['hello_named']!;
  String get discoverFresh =>
      _strings[languageCode]?['discover_fresh'] ??
      _strings['en']!['discover_fresh']!;
  String get liveMarketPrices =>
      _strings[languageCode]?['live_market_prices'] ??
      _strings['en']!['live_market_prices']!;
  String get marketPricesEmpty =>
      _strings[languageCode]?['market_prices_empty'] ??
      _strings['en']!['market_prices_empty']!;
  String get explore =>
      _strings[languageCode]?['explore'] ?? _strings['en']!['explore']!;
  String get cropGuide =>
      _strings[languageCode]?['crop_guide'] ?? _strings['en']!['crop_guide']!;
  String get cropGuideDesc =>
      _strings[languageCode]?['crop_guide_desc'] ??
      _strings['en']!['crop_guide_desc']!;
  String get priceTrends =>
      _strings[languageCode]?['price_trends'] ??
      _strings['en']!['price_trends']!;
  String get priceTrendsDesc =>
      _strings[languageCode]?['price_trends_desc'] ??
      _strings['en']!['price_trends_desc']!;
  String get askAi =>
      _strings[languageCode]?['ask_ai'] ?? _strings['en']!['ask_ai']!;
  String get askAiDesc =>
      _strings[languageCode]?['ask_ai_desc'] ?? _strings['en']!['ask_ai_desc']!;

  // AI chat
  String get chatHistory =>
      _strings[languageCode]?['chat_history'] ??
      _strings['en']!['chat_history']!;
  String get chatHint =>
      _strings[languageCode]?['chat_hint'] ?? _strings['en']!['chat_hint']!;
  String get photo =>
      _strings[languageCode]?['photo'] ?? _strings['en']!['photo']!;
  String get voice =>
      _strings[languageCode]?['voice'] ?? _strings['en']!['voice']!;
  String get historyBtn =>
      _strings[languageCode]?['history_btn'] ?? _strings['en']!['history_btn']!;
  String get addAttachment =>
      _strings[languageCode]?['add_attachment'] ??
      _strings['en']!['add_attachment']!;
  String get askAnything =>
      _strings[languageCode]?['ask_anything'] ??
      _strings['en']!['ask_anything']!;
  String get newChat =>
      _strings[languageCode]?['new_chat'] ?? _strings['en']!['new_chat']!;
  String get noChatsYet =>
      _strings[languageCode]?['no_chats_yet'] ??
      _strings['en']!['no_chats_yet']!;

  // Live voice
  String get exitLiveVoice =>
      _strings[languageCode]?['exit_live_voice'] ??
      _strings['en']!['exit_live_voice']!;
  String get stop =>
      _strings[languageCode]?['stop'] ?? _strings['en']!['stop']!;
  String get autoContinueOn =>
      _strings[languageCode]?['auto_continue_on'] ??
      _strings['en']!['auto_continue_on']!;
  String get autoContinueOff =>
      _strings[languageCode]?['auto_continue_off'] ??
      _strings['en']!['auto_continue_off']!;

  // Farm card
  String get farmNameLabel =>
      _strings[languageCode]?['farm_name_label'] ??
      _strings['en']!['farm_name_label']!;
  String get farmSizeLabel =>
      _strings[languageCode]?['farm_size_label'] ??
      _strings['en']!['farm_size_label']!;
  String get farmLocationLabel =>
      _strings[languageCode]?['farm_location_label'] ??
      _strings['en']!['farm_location_label']!;
  String get village =>
      _strings[languageCode]?['village'] ?? _strings['en']!['village']!;
  String get permissionDeniedText =>
      _strings[languageCode]?['permission_denied_text'] ??
      _strings['en']!['permission_denied_text']!;
  String get permissionPermanent =>
      _strings[languageCode]?['permission_permanent'] ??
      _strings['en']!['permission_permanent']!;
  String get settings =>
      _strings[languageCode]?['settings'] ?? _strings['en']!['settings']!;
  String get locationDisabled =>
      _strings[languageCode]?['location_disabled'] ??
      _strings['en']!['location_disabled']!;
  String get microphonePermission =>
      _strings[languageCode]?['microphone_permission'] ??
      _strings['en']!['microphone_permission']!;
  String get chooseGallery =>
      _strings[languageCode]?['choose_gallery'] ??
      _strings['en']!['choose_gallery']!;
  String get viewPrevResult =>
      _strings[languageCode]?['view_prev_result'] ??
      _strings['en']!['view_prev_result']!;
  String get aiAnalysisFailed =>
      _strings[languageCode]?['ai_analysis_failed'] ??
      _strings['en']!['ai_analysis_failed']!;
  String get soilAnalysisError =>
      _strings[languageCode]?['soil_analysis_error'] ??
      _strings['en']!['soil_analysis_error']!;
  String get aiSoilAnalysis =>
      _strings[languageCode]?['ai_soil_analysis'] ??
      _strings['en']!['ai_soil_analysis']!;
  String get manualSelect =>
      _strings[languageCode]?['manual_select'] ??
      _strings['en']!['manual_select']!;
  String get ageYears =>
      _strings[languageCode]?['age_years'] ?? _strings['en']!['age_years']!;
  String get saveProfile =>
      _strings[languageCode]?['save_profile'] ??
      _strings['en']!['save_profile']!;
  String get useAnyway =>
      _strings[languageCode]?['use_anyway'] ?? _strings['en']!['use_anyway']!;
  String get aiChat =>
      _strings[languageCode]?['ai_chat'] ?? _strings['en']!['ai_chat']!;
  String get attachPhotoHint =>
      _strings[languageCode]?['attach_photo_hint'] ??
      _strings['en']!['attach_photo_hint']!;
  String get file =>
      _strings[languageCode]?['file'] ?? _strings['en']!['file']!;
  String get fileTypeUnsupported =>
      _strings[languageCode]?['file_type_unsupported'] ??
      _strings['en']!['file_type_unsupported']!;
  String get assistantConfirmPrompt =>
      _strings[languageCode]?['assistant_confirm_prompt'] ??
      _strings['en']!['assistant_confirm_prompt']!;
  String get assistantDone =>
      _strings[languageCode]?['assistant_done'] ??
      _strings['en']!['assistant_done']!;
  String get assistantFailed =>
      _strings[languageCode]?['assistant_failed'] ??
      _strings['en']!['assistant_failed']!;
  String get assistantCancelled =>
      _strings[languageCode]?['assistant_cancelled'] ??
      _strings['en']!['assistant_cancelled']!;
  String get assistantCouldNotSetField =>
      _strings[languageCode]?['assistant_could_not_set_field'] ??
      _strings['en']!['assistant_could_not_set_field']!;
  String get defaultUserNameFarmer =>
      _strings[languageCode]?['default_user_name_farmer'] ??
      _strings['en']!['default_user_name_farmer']!;
  String get defaultUserNameUser =>
      _strings[languageCode]?['default_user_name_user'] ??
      _strings['en']!['default_user_name_user']!;
  String get defaultUserNameConsumer =>
      _strings[languageCode]?['default_user_name_consumer'] ??
      _strings['en']!['default_user_name_consumer']!;
  String get errorGeneric =>
      _strings[languageCode]?['error_generic'] ??
      _strings['en']!['error_generic']!;
  String get errorFallback =>
      _strings[languageCode]?['error_fallback'] ??
      _strings['en']!['error_fallback']!;
  String get listenNowInstruction =>
      _strings[languageCode]?['listen_now_instruction'] ??
      _strings['en']!['listen_now_instruction']!;
  String get listenNowListening =>
      _strings[languageCode]?['listen_now_listening'] ??
      _strings['en']!['listen_now_listening']!;
  String get copy =>
      _strings[languageCode]?['copy'] ?? _strings['en']!['copy']!;
  String get share =>
      _strings[languageCode]?['share'] ?? _strings['en']!['share']!;
  String get assistantFieldNotAvailable =>
      _strings[languageCode]?['assistant_field_not_available'] ??
      _strings['en']!['assistant_field_not_available']!;
  String get assistantInvalidValue =>
      _strings[languageCode]?['assistant_invalid_value'] ??
      _strings['en']!['assistant_invalid_value']!;
  String get assistantActionNotRegistered =>
      _strings[languageCode]?['assistant_action_not_registered'] ??
      _strings['en']!['assistant_action_not_registered']!;
  String get assistantActionFailed =>
      _strings[languageCode]?['assistant_action_failed'] ??
      _strings['en']!['assistant_action_failed']!;

  // Community feed screen
  String get communityNoPosts =>
      _strings[languageCode]?['community_no_posts'] ??
      _strings['en']!['community_no_posts']!;
  String get communityNoPostsHint =>
      _strings[languageCode]?['community_no_posts_hint'] ??
      _strings['en']!['community_no_posts_hint']!;
  String get all => _strings[languageCode]?['all'] ?? _strings['en']!['all']!;
  String get timeAgoW =>
      _strings[languageCode]?['time_ago_w'] ?? _strings['en']!['time_ago_w']!;
  String get filterByLocation =>
      _strings[languageCode]?['filter_by_location'] ??
      _strings['en']!['filter_by_location']!;
  String get district =>
      _strings[languageCode]?['district'] ?? _strings['en']!['district']!;
  String get state =>
      _strings[languageCode]?['state'] ?? _strings['en']!['state']!;
  String get clearFilters =>
      _strings[languageCode]?['clear_filters'] ??
      _strings['en']!['clear_filters']!;
  String get apply =>
      _strings[languageCode]?['apply'] ?? _strings['en']!['apply']!;

  // Add farm screen
  String get addNewFarm =>
      _strings[languageCode]?['add_new_farm'] ??
      _strings['en']!['add_new_farm']!;
  String get saveFarm =>
      _strings[languageCode]?['save_farm'] ?? _strings['en']!['save_farm']!;
  String get pleaseFillFarmDetails =>
      _strings[languageCode]?['please_fill_farm_details'] ??
      _strings['en']!['please_fill_farm_details']!;
  String get pleaseFillFarmRequired =>
      _strings[languageCode]?['please_fill_farm_required'] ??
      _strings['en']!['please_fill_farm_required']!;
  String get savedSuccessfully =>
      _strings[languageCode]?['saved_successfully'] ??
      _strings['en']!['saved_successfully']!;
  String get errorSavingFarm =>
      _strings[languageCode]?['error_saving_farm'] ??
      _strings['en']!['error_saving_farm']!;

  // Edit profile screen
  String get nameCannotBeEmpty =>
      _strings[languageCode]?['name_cannot_be_empty'] ??
      _strings['en']!['name_cannot_be_empty']!;
  String get profileSavedSuccess =>
      _strings[languageCode]?['profile_saved_success'] ??
      _strings['en']!['profile_saved_success']!;
  String get name =>
      _strings[languageCode]?['name'] ?? _strings['en']!['name']!;
  String get enterNameHint =>
      _strings[languageCode]?['enter_name_hint'] ??
      _strings['en']!['enter_name_hint']!;
  String get ageAutoCalculated =>
      _strings[languageCode]?['age_auto_calculated'] ??
      _strings['en']!['age_auto_calculated']!;
  String get currentAddress =>
      _strings[languageCode]?['current_address'] ??
      _strings['en']!['current_address']!;
  String get enterAddressHint =>
      _strings[languageCode]?['enter_address_hint'] ??
      _strings['en']!['enter_address_hint']!;
  String get useCurrentLocation =>
      _strings[languageCode]?['use_current_location'] ??
      _strings['en']!['use_current_location']!;
  String get selectGender =>
      _strings[languageCode]?['select_gender'] ??
      _strings['en']!['select_gender']!;
  String get male =>
      _strings[languageCode]?['male'] ?? _strings['en']!['male']!;
  String get female =>
      _strings[languageCode]?['female'] ?? _strings['en']!['female']!;
  String get otherGender =>
      _strings[languageCode]?['other_gender'] ??
      _strings['en']!['other_gender']!;
  String get selectDateOfBirth =>
      _strings[languageCode]?['select_date_of_birth'] ??
      _strings['en']!['select_date_of_birth']!;
  String get locationPermissionDenied =>
      _strings[languageCode]?['location_permission_denied'] ??
      _strings['en']!['location_permission_denied']!;
  String get locationServicesDisabled =>
      _strings[languageCode]?['location_services_disabled'] ??
      _strings['en']!['location_services_disabled']!;
  String get locationDetectedSuccess =>
      _strings[languageCode]?['location_detected_success'] ??
      _strings['en']!['location_detected_success']!;
  String get getLocationFailed =>
      _strings[languageCode]?['get_location_failed'] ??
      _strings['en']!['get_location_failed']!;
  String get voiceInputNotAvailable =>
      _strings[languageCode]?['voice_input_not_available'] ??
      _strings['en']!['voice_input_not_available']!;
  String get aiOffline =>
      _strings[languageCode]?['ai_offline'] ?? _strings['en']!['ai_offline']!;
  String get aiAuthError =>
      _strings[languageCode]?['ai_auth_error'] ??
      _strings['en']!['ai_auth_error']!;
  String get aiGenericError =>
      _strings[languageCode]?['ai_generic_error'] ??
      _strings['en']!['ai_generic_error']!;
  String get aiCopied =>
      _strings[languageCode]?['ai_copied'] ?? _strings['en']!['ai_copied']!;
  String get aiVoiceTapToStart =>
      _strings[languageCode]?['ai_voice_tap_to_start'] ??
      _strings['en']!['ai_voice_tap_to_start']!;
  String get aiVoiceListening =>
      _strings[languageCode]?['ai_voice_listening'] ??
      _strings['en']!['ai_voice_listening']!;
  String get aiVoiceThinking =>
      _strings[languageCode]?['ai_voice_thinking'] ??
      _strings['en']!['ai_voice_thinking']!;
  String get aiVoiceSpeaking =>
      _strings[languageCode]?['ai_voice_speaking'] ??
      _strings['en']!['ai_voice_speaking']!;
  String get aiVoiceError =>
      _strings[languageCode]?['ai_voice_error'] ??
      _strings['en']!['ai_voice_error']!;
  String get communityComingSoon =>
      _strings[languageCode]?['community_coming_soon'] ??
      _strings['en']!['community_coming_soon']!;
  String get communityComingSoonDesc =>
      _strings[languageCode]?['community_coming_soon_desc'] ??
      _strings['en']!['community_coming_soon_desc']!;
  String get farmWorkspace =>
      _strings[languageCode]?['farm_workspace'] ??
      _strings['en']!['farm_workspace']!;
  String get farmWorkspaceDesc =>
      _strings[languageCode]?['farm_workspace_desc'] ??
      _strings['en']!['farm_workspace_desc']!;
  String get pestAddAnotherPhoto =>
      _strings[languageCode]?['pest_add_another_photo'] ??
      _strings['en']!['pest_add_another_photo']!;
  String get pestAddPhotoLabel =>
      _strings[languageCode]?['pest_add_photo_label'] ??
      _strings['en']!['pest_add_photo_label']!;
  String get pestAddToTasks =>
      _strings[languageCode]?['pest_add_to_tasks'] ??
      _strings['en']!['pest_add_to_tasks']!;
  String get pestAnalyzeNow =>
      _strings[languageCode]?['pest_analyze_now'] ??
      _strings['en']!['pest_analyze_now']!;
  String get pestCausesLabel =>
      _strings[languageCode]?['pest_causes_label'] ??
      _strings['en']!['pest_causes_label']!;
  String get pestClearPhotos =>
      _strings[languageCode]?['pest_clear_photos'] ??
      _strings['en']!['pest_clear_photos']!;
  String get pestConditionLabel =>
      _strings[languageCode]?['pest_condition_label'] ??
      _strings['en']!['pest_condition_label']!;
  String get pestCropAutoHint =>
      _strings[languageCode]?['pest_crop_auto_hint'] ??
      _strings['en']!['pest_crop_auto_hint']!;
  String get pestFarmNone =>
      _strings[languageCode]?['pest_farm_none'] ??
      _strings['en']!['pest_farm_none']!;
  String get pestFarmNoneHint =>
      _strings[languageCode]?['pest_farm_none_hint'] ??
      _strings['en']!['pest_farm_none_hint']!;
  String get pestHealthy =>
      _strings[languageCode]?['pest_healthy'] ??
      _strings['en']!['pest_healthy']!;
  String get pestHistorySaved =>
      _strings[languageCode]?['pest_history_saved'] ??
      _strings['en']!['pest_history_saved']!;
  String get pestIssueDetected =>
      _strings[languageCode]?['pest_issue_detected'] ??
      _strings['en']!['pest_issue_detected']!;
  String get pestFarmTaskTitle =>
      _strings[languageCode]?['pest_farm_task_title'] ??
      _strings['en']!['pest_farm_task_title']!;
  String get pestLowConfidenceWarning =>
      _strings[languageCode]?['pest_low_confidence_warning'] ??
      _strings['en']!['pest_low_confidence_warning']!;
  String get pestNoCropsFound =>
      _strings[languageCode]?['pest_no_crops_found'] ??
      _strings['en']!['pest_no_crops_found']!;
  String get pestNoPhotosYet =>
      _strings[languageCode]?['pest_no_photos_yet'] ??
      _strings['en']!['pest_no_photos_yet']!;
  String get pestPhotoHint =>
      _strings[languageCode]?['pest_photo_hint'] ??
      _strings['en']!['pest_photo_hint']!;
  String get pestRemedyLabel =>
      _strings[languageCode]?['pest_remedy_label'] ??
      _strings['en']!['pest_remedy_label']!;
  String get pestRemedyNote =>
      _strings[languageCode]?['pest_remedy_note'] ??
      _strings['en']!['pest_remedy_note']!;
  String get pestRemovePhoto =>
      _strings[languageCode]?['pest_remove_photo'] ??
      _strings['en']!['pest_remove_photo']!;
  String get pestMaxHint =>
      _strings[languageCode]?['pest_maximum_hint'] ??
      _strings['en']!['pest_maximum_hint']!;
  String get remedyChemical =>
      _strings[languageCode]?['remedy_chemical'] ??
      _strings['en']!['remedy_chemical']!;
  String get remedyOrganic =>
      _strings[languageCode]?['remedy_organic'] ??
      _strings['en']!['remedy_organic']!;
  String get severityHigh =>
      _strings[languageCode]?['severity_high'] ??
      _strings['en']!['severity_high']!;
  String get severityLow =>
      _strings[languageCode]?['severity_low'] ??
      _strings['en']!['severity_low']!;
  String get severityMedium =>
      _strings[languageCode]?['severity_medium'] ??
      _strings['en']!['severity_medium']!;
  String get pestSymptomsLabel =>
      _strings[languageCode]?['pest_symptoms_label'] ??
      _strings['en']!['pest_symptoms_label']!;
  String get pestSelectFarmLabel =>
      _strings[languageCode]?['pest_select_farm_label'] ??
      _strings['en']!['pest_select_farm_label']!;
  String get pestTaskAdded =>
      _strings[languageCode]?['pest_task_added'] ??
      _strings['en']!['pest_task_added']!;
  String get pestTempNotSaved =>
      _strings[languageCode]?['pest_temp_not_saved'] ??
      _strings['en']!['pest_temp_not_saved']!;
  String get pestUnclearPhotoWarning =>
      _strings[languageCode]?['pest_unclear_photo_warning'] ??
      _strings['en']!['pest_unclear_photo_warning']!;
  String get pestViewFertilizerGuide =>
      _strings[languageCode]?['pest_view_fertilizer_guide'] ??
      _strings['en']!['pest_view_fertilizer_guide']!;
  String get pestMultiTitle =>
      _strings[languageCode]?['pest_multi_title'] ??
      _strings['en']!['pest_multi_title']!;
  String get pestMultiIntro =>
      _strings[languageCode]?['pest_multi_intro'] ??
      _strings['en']!['pest_multi_intro']!;
  String get pestAddAnotherPart =>
      _strings[languageCode]?['pest_add_another_part'] ??
      _strings['en']!['pest_add_another_part']!;
  String get pestUploadPhoto =>
      _strings[languageCode]?['pest_upload_photo'] ??
      _strings['en']!['pest_upload_photo']!;
  String get pestPartLabel =>
      _strings[languageCode]?['pest_part_label'] ??
      _strings['en']!['pest_part_label']!;
  String get pestSelectPartHint =>
      _strings[languageCode]?['pest_select_part_hint'] ??
      _strings['en']!['pest_select_part_hint']!;
  String get pestObservationLabel =>
      _strings[languageCode]?['pest_observation_label'] ??
      _strings['en']!['pest_observation_label']!;
  String get pestObservationHint =>
      _strings[languageCode]?['pest_observation_hint'] ??
      _strings['en']!['pest_observation_hint']!;
  String get pestPartWholePlant =>
      _strings[languageCode]?['pest_part_whole_plant'] ??
      _strings['en']!['pest_part_whole_plant']!;
  String get pestPartLeaf =>
      _strings[languageCode]?['pest_part_leaf'] ??
      _strings['en']!['pest_part_leaf']!;
  String get pestPartStem =>
      _strings[languageCode]?['pest_part_stem'] ??
      _strings['en']!['pest_part_stem']!;
  String get pestPartRoot =>
      _strings[languageCode]?['pest_part_root'] ??
      _strings['en']!['pest_part_root']!;
  String get pestPartFlower =>
      _strings[languageCode]?['pest_part_flower'] ??
      _strings['en']!['pest_part_flower']!;
  String get pestPartFruit =>
      _strings[languageCode]?['pest_part_fruit'] ??
      _strings['en']!['pest_part_fruit']!;
  String get pestPartSeed =>
      _strings[languageCode]?['pest_part_seed'] ??
      _strings['en']!['pest_part_seed']!;
  String get pestPartOther =>
      _strings[languageCode]?['pest_part_other'] ??
      _strings['en']!['pest_part_other']!;
  String get pestPhotosLabel =>
      _strings[languageCode]?['pest_photos_label'] ??
      _strings['en']!['pest_photos_label']!;
  String get pestAffectedParts =>
      _strings[languageCode]?['pest_affected_parts'] ??
      _strings['en']!['pest_affected_parts']!;
  String get pestFarmerObservations =>
      _strings[languageCode]?['pest_farmer_observations'] ??
      _strings['en']!['pest_farmer_observations']!;
  String get pestRecommendation =>
      _strings[languageCode]?['pest_recommendation'] ??
      _strings['en']!['pest_recommendation']!;
  String get pestUncertainty =>
      _strings[languageCode]?['pest_uncertainty'] ??
      _strings['en']!['pest_uncertainty']!;
  String get pestCombinedAnalysis =>
      _strings[languageCode]?['pest_combined_analysis'] ??
      _strings['en']!['pest_combined_analysis']!;
  String get pestNoPhotoValidation =>
      _strings[languageCode]?['pest_no_photo_validation'] ??
      _strings['en']!['pest_no_photo_validation']!;
  String get pestNoPartValidation =>
      _strings[languageCode]?['pest_no_part_validation'] ??
      _strings['en']!['pest_no_part_validation']!;
  String get pestInvalidPhoto =>
      _strings[languageCode]?['pest_invalid_photo'] ??
      _strings['en']!['pest_invalid_photo']!;
  String get pestCropRequired =>
      _strings[languageCode]?['pest_crop_required'] ??
      _strings['en']!['pest_crop_required']!;
  String get pestWorkspaceSaveFailed =>
      _strings[languageCode]?['pest_workspace_save_failed'] ??
      _strings['en']!['pest_workspace_save_failed']!;
  String get pestCaseHeading =>
      _strings[languageCode]?['pest_case_heading'] ??
      _strings['en']!['pest_case_heading']!;
  String get workspaceAnalyses =>
      _strings[languageCode]?['workspace_analyses'] ??
      _strings['en']!['workspace_analyses']!;
  String get workspaceLatest =>
      _strings[languageCode]?['workspace_latest'] ??
      _strings['en']!['workspace_latest']!;
  String get workspaceNoAnalysis =>
      _strings[languageCode]?['workspace_no_analysis'] ??
      _strings['en']!['workspace_no_analysis']!;
  String get workspaceOpen =>
      _strings[languageCode]?['workspace_open'] ??
      _strings['en']!['workspace_open']!;

  String get workspaceAddNote =>
      _strings[languageCode]?['workspace_add_note'] ??
      _strings['en']!['workspace_add_note']!;
  String get workspaceDeleteNoteConfirm =>
      _strings[languageCode]?['workspace_delete_note_confirm'] ??
      _strings['en']!['workspace_delete_note_confirm']!;
  String get workspaceEditNote =>
      _strings[languageCode]?['workspace_edit_note'] ??
      _strings['en']!['workspace_edit_note']!;
  String get workspaceManualNote =>
      _strings[languageCode]?['workspace_manual_note'] ??
      _strings['en']!['workspace_manual_note']!;
  String get workspaceNewNote =>
      _strings[languageCode]?['workspace_new_note'] ??
      _strings['en']!['workspace_new_note']!;
  String get workspaceNoFarm =>
      _strings[languageCode]?['workspace_no_farm'] ??
      _strings['en']!['workspace_no_farm']!;
  String get workspaceNoteContentHint =>
      _strings[languageCode]?['workspace_note_content_hint'] ??
      _strings['en']!['workspace_note_content_hint']!;
  String get workspaceNoteCrop =>
      _strings[languageCode]?['workspace_note_crop'] ??
      _strings['en']!['workspace_note_crop']!;
  String get workspaceNoteDeleted =>
      _strings[languageCode]?['workspace_note_deleted'] ??
      _strings['en']!['workspace_note_deleted']!;
  String get workspaceNoteFarm =>
      _strings[languageCode]?['workspace_note_farm'] ??
      _strings['en']!['workspace_note_farm']!;
  String get workspaceNoteSaved =>
      _strings[languageCode]?['workspace_note_saved'] ??
      _strings['en']!['workspace_note_saved']!;
  String get workspaceNoteTitleHint =>
      _strings[languageCode]?['workspace_note_title_hint'] ??
      _strings['en']!['workspace_note_title_hint']!;
  String get workspaceNoteTitleRequired =>
      _strings[languageCode]?['workspace_note_title_required'] ??
      _strings['en']!['workspace_note_title_required']!;
  String get workspaceNoteUpdated =>
      _strings[languageCode]?['workspace_note_updated'] ??
      _strings['en']!['workspace_note_updated']!;
  String get workspaceNotesEmpty =>
      _strings[languageCode]?['workspace_notes_empty'] ??
      _strings['en']!['workspace_notes_empty']!;
  String get workspaceNotesEmptyHint =>
      _strings[languageCode]?['workspace_notes_empty_hint'] ??
      _strings['en']!['workspace_notes_empty_hint']!;
  String get workspaceOlder =>
      _strings[languageCode]?['workspace_older'] ??
      _strings['en']!['workspace_older']!;
  String get workspacePestNote =>
      _strings[languageCode]?['workspace_pest_note'] ??
      _strings['en']!['workspace_pest_note']!;
  String get workspacePestSaved =>
      _strings[languageCode]?['workspace_pest_saved'] ??
      _strings['en']!['workspace_pest_saved']!;
  String get workspaceSavePest =>
      _strings[languageCode]?['workspace_save_pest'] ??
      _strings['en']!['workspace_save_pest']!;
  String get workspaceToday =>
      _strings[languageCode]?['workspace_today'] ??
      _strings['en']!['workspace_today']!;
  String get workspaceYesterday =>
      _strings[languageCode]?['workspace_yesterday'] ??
      _strings['en']!['workspace_yesterday']!;

  // Personal Details redesign
  String get pdSubtitle =>
      _strings[languageCode]?['pd_subtitle'] ?? _strings['en']!['pd_subtitle']!;
  String get currentLocation =>
      _strings[languageCode]?['current_location'] ??
      _strings['en']!['current_location']!;
  String get detectingLocation =>
      _strings[languageCode]?['detecting_location'] ??
      _strings['en']!['detecting_location']!;
  String get locationDetectionFailed =>
      _strings[languageCode]?['location_detection_failed'] ??
      _strings['en']!['location_detection_failed']!;
  String get locationPermissionNeeded =>
      _strings[languageCode]?['location_permission_needed'] ??
      _strings['en']!['location_permission_needed']!;
  String get aiLiveButton =>
      _strings[languageCode]?['ai_live_button'] ??
      _strings['en']!['ai_live_button']!;
  String get aiLiveDescription =>
      _strings[languageCode]?['ai_live_description'] ??
      _strings['en']!['ai_live_description']!;
  String get tapToChangePhoto =>
      _strings[languageCode]?['tap_to_change_photo'] ??
      _strings['en']!['tap_to_change_photo']!;
  String get retryLocation =>
      _strings[languageCode]?['retry_location'] ??
      _strings['en']!['retry_location']!;

  // AI Live (realtime streaming speech-to-text)
  String get aiLiveTitle =>
      _strings[languageCode]?['ai_live_title'] ??
      _strings['en']!['ai_live_title']!;
  String get aiLiveConnecting =>
      _strings[languageCode]?['ai_live_connecting'] ??
      _strings['en']!['ai_live_connecting']!;
  String get aiLiveReconnecting =>
      _strings[languageCode]?['ai_live_reconnecting'] ??
      _strings['en']!['ai_live_reconnecting']!;
  String get aiLiveOffline =>
      _strings[languageCode]?['ai_live_offline'] ??
      _strings['en']!['ai_live_offline']!;
  String get aiLiveMicPermission =>
      _strings[languageCode]?['ai_live_mic_permission'] ??
      _strings['en']!['ai_live_mic_permission']!;
  String get aiLiveMicUnavailable =>
      _strings[languageCode]?['ai_live_mic_unavailable'] ??
      _strings['en']!['ai_live_mic_unavailable']!;
  String get aiLiveServiceError =>
      _strings[languageCode]?['ai_live_service_error'] ??
      _strings['en']!['ai_live_service_error']!;
  String get aiLiveNoInternet =>
      _strings[languageCode]?['ai_live_no_internet'] ??
      _strings['en']!['ai_live_no_internet']!;
  String get aiLiveHint =>
      _strings[languageCode]?['ai_live_hint'] ??
      _strings['en']!['ai_live_hint']!;
  String get aiLiveEmptyTranscript =>
      _strings[languageCode]?['ai_live_empty_transcript'] ??
      _strings['en']!['ai_live_empty_transcript']!;
  String get aiLiveSuggestionsTitle =>
      _strings[languageCode]?['ai_live_suggestions_title'] ??
      _strings['en']!['ai_live_suggestions_title']!;
  String get aiLiveSessionError =>
      _strings[languageCode]?['ai_live_session_error'] ??
      _strings['en']!['ai_live_session_error']!;
  String get aiLiveApplied =>
      _strings[languageCode]?['ai_live_applied'] ??
      _strings['en']!['ai_live_applied']!;
  String get aiLiveApply =>
      _strings[languageCode]?['ai_live_apply'] ??
      _strings['en']!['ai_live_apply']!;
  String get aiLiveTapToListen =>
      _strings[languageCode]?['ai_live_tap_to_listen'] ??
      _strings['en']!['ai_live_tap_to_listen']!;
  String get aiLiveUnsupportedLanguage =>
      _strings[languageCode]?['ai_live_unsupported_language'] ??
      _strings['en']!['ai_live_unsupported_language']!;

  static Map<String, Map<String, String>> get _strings => {
        'en': enStrings,
        'ta': taStrings,
        'te': teStrings,
        'kn': knStrings,
        'ml': mlStrings,
        'hi': hiStrings,
        'bn': bnStrings,
        'mr': mrStrings,
        'gu': guStrings,
        'pa': paStrings,
        'or': orStrings,
        'as': asStrings,
        'ur': urStrings,
      };
}

class _AppLocalizationsScope extends InheritedWidget {
  final AppLocalizations localizations;

  const _AppLocalizationsScope({
    required this.localizations,
    required super.child,
  });

  @override
  bool updateShouldNotify(_AppLocalizationsScope oldWidget) {
    return localizations.languageCode != oldWidget.localizations.languageCode;
  }
}

class AppLocalizationsProvider extends StatefulWidget {
  final String initialLanguageCode;
  final Widget child;

  const AppLocalizationsProvider({
    required this.initialLanguageCode,
    required this.child,
    super.key,
  });

  static AppLocalizationsProviderState of(BuildContext context) {
    return context.findAncestorStateOfType<AppLocalizationsProviderState>()!;
  }

  @override
  State<AppLocalizationsProvider> createState() =>
      AppLocalizationsProviderState();
}

class AppLocalizationsProviderState extends State<AppLocalizationsProvider> {
  late String _languageCode;

  @override
  void initState() {
    super.initState();
    _languageCode = widget.initialLanguageCode;
  }

  AppLocalizations get localizations => AppLocalizations(_languageCode);

  void setLanguage(String code) {
    setState(() {
      _languageCode = code;
    });
    AppLocalizations.saveLanguage(code);
  }

  @override
  Widget build(BuildContext context) {
    return _AppLocalizationsScope(
      localizations: localizations,
      child: widget.child,
    );
  }
}
