import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

enum VoiceField {
  name,
  gender,
  dateOfBirth,
  age,
  email,
  address,
  farmName,
  farmSize,
  irrigationType,
  waterSource,
  soilType,
  waterAvailability,
  farmingMethod,
  none,
}

class VoiceService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  bool _available = false;

  bool get isAvailable => _available;
  bool get isListening => _speech.isListening;

  Future<bool> initialize() async {
    try {
      _available = await _speech.initialize(
        onStatus: (_) {},
        onError: (_) {},
      );
      _initialized = true;
      return _available;
    } catch (_) {
      _available = false;
      return false;
    }
  }

  Future<void> startListening({
    required void Function(String text, double confidence) onResult,
    required void Function() onListeningComplete,
    String localeId = 'en_US',
  }) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) {
        onListeningComplete();
        return;
      }
    }

    if (_speech.isListening) {
      await _speech.stop();
    }

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        final text = result.recognizedWords.trim();
        if (text.isNotEmpty) {
          onResult(text, result.confidence);
        }
        if (result.finalResult) {
          onListeningComplete();
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  static VoiceField classifySpeech(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('name') ||
        lower.startsWith('my name') ||
        (lower.startsWith('i am') && lower.contains('called'))) {
      return VoiceField.name;
    }
    if (lower.contains('gender') ||
        lower.contains('male') ||
        lower.contains('female') ||
        lower.contains('sex')) {
      return VoiceField.gender;
    }
    if (lower.contains('date of birth') ||
        lower.contains('birthday') ||
        lower.contains('born') ||
        lower.contains('dob')) {
      return VoiceField.dateOfBirth;
    }
    if (lower.contains('age') ||
        lower.contains('years old') ||
        lower.contains('year old')) {
      return VoiceField.age;
    }
    if (lower.contains('email') || lower.contains('mail')) {
      return VoiceField.email;
    }
    if (lower.contains('address') ||
        lower.contains('location') ||
        lower.contains('city') ||
        lower.contains('live in') ||
        lower.contains('reside')) {
      return VoiceField.address;
    }
    if (lower.contains('farm name') || lower.contains('farm called')) {
      return VoiceField.farmName;
    }
    if (lower.contains('farm size') ||
        lower.contains('acre') ||
        lower.contains('hectare') ||
        lower.contains('cent')) {
      return VoiceField.farmSize;
    }
    if (lower.contains('irrigation') ||
        lower.contains('drip') ||
        lower.contains('sprinkler')) {
      return VoiceField.irrigationType;
    }
    if (lower.contains('water source') ||
        lower.contains('well') ||
        lower.contains('borewell') ||
        lower.contains('river')) {
      return VoiceField.waterSource;
    }
    if (lower.contains('soil') ||
        lower.contains('clay') ||
        lower.contains('sandy') ||
        lower.contains('loam')) {
      return VoiceField.soilType;
    }
    if (lower.contains('water availability') ||
        lower.contains('water level') ||
        lower.contains('水量') ||
        lower.contains('நீர் அளவு')) {
      return VoiceField.waterAvailability;
    }
    if (lower.contains('farming method') ||
        lower.contains('organic') ||
        lower.contains('integrated') ||
        lower.contains('conventional') ||
        lower.contains('natural farming') ||
        lower.contains('precision farming')) {
      return VoiceField.farmingMethod;
    }

    return VoiceField.none;
  }

  static String extractValue(String text, VoiceField field) {
    switch (field) {
      case VoiceField.name:
        // For names, preserve the original text as much as possible.
        // Only remove common prefix phrases in the same language.
        final lower = text.toLowerCase();
        final prefixPatterns = [
          RegExp(r'^my name is\s+', caseSensitive: false),
          RegExp(r"^(i'?m|i am)\s+", caseSensitive: false),
          RegExp(r'^call me\s+', caseSensitive: false),
          RegExp(r'^name\s+', caseSensitive: false),
          RegExp(r'^this is\s+', caseSensitive: false),
        ];
        for (final p in prefixPatterns) {
          if (lower.startsWith(p.pattern.replaceAll(r'\s+', ' ').trim())) {
            final match = p.firstMatch(text);
            if (match != null) {
              return text.substring(match.end).trim();
            }
          }
        }
        // For non-Latin scripts (Tamil, Telugu, Hindi, etc.), return as-is
        // since stripping regex patterns would destroy the script
        final hasLatin = RegExp(r'[a-zA-Z]').hasMatch(text);
        if (!hasLatin) return text.trim();
        // For Latin text, try simple prefix removal
        final simplePrefixes = [
          'my name is ',
          "i'm ",
          'i am ',
          'call me ',
          'name '
        ];
        for (final prefix in simplePrefixes) {
          if (lower.startsWith(prefix)) {
            return text.substring(prefix.length).trim();
          }
        }
        return text.trim();

      case VoiceField.gender:
        final gl = text.toLowerCase();
        if (gl.contains('male') && !gl.contains('female')) return 'Male';
        if (gl.contains('female')) return 'Female';
        if (gl.contains('other')) return 'Other';
        return text.trim();

      case VoiceField.age:
        final numMatch = RegExp(r'(\d+)').firstMatch(text);
        if (numMatch != null) return numMatch.group(1)!;
        return text.trim();

      case VoiceField.dateOfBirth:
        return text.trim();

      case VoiceField.email:
        final emailMatch = RegExp(r'[\w\.\-]+@[\w\.\-]+\.\w+').firstMatch(text);
        if (emailMatch != null) return emailMatch.group(0)!;
        return text.trim();

      case VoiceField.address:
        return text.trim();

      case VoiceField.farmName:
        return text.trim();

      case VoiceField.farmSize:
        return text.trim();

      case VoiceField.irrigationType:
        final lower2 = text.toLowerCase();
        if (lower2.contains('drip')) return 'Drip';
        if (lower2.contains('sprinkler')) return 'Sprinkler';
        if (lower2.contains('flood')) return 'Flood';
        if (lower2.contains('rain')) return 'Rainfed';
        if (lower2.contains('manual')) return 'Manual';
        return text.trim();

      case VoiceField.waterSource:
        final lower3 = text.toLowerCase();
        if (lower3.contains('well') && !lower3.contains('bore')) return 'Well';
        if (lower3.contains('borewell') || lower3.contains('bore')) {
          return 'Borewell';
        }
        if (lower3.contains('river')) return 'River';
        if (lower3.contains('canal')) return 'Canal';
        if (lower3.contains('rain')) return 'Rainwater';
        if (lower3.contains('pond')) return 'Pond';
        return text.trim();

      case VoiceField.soilType:
        final lower4 = text.toLowerCase();
        if (lower4.contains('clay')) return 'Clay';
        if (lower4.contains('sandy')) return 'Sandy';
        if (lower4.contains('loam')) return 'Loamy';
        if (lower4.contains('silt')) return 'Silt';
        if (lower4.contains('peat')) return 'Peat';
        if (lower4.contains('chalk')) return 'Chalk';
        if (lower4.contains('saline')) return 'Saline';
        if (lower4.contains('black') || lower4.contains('regur')) {
          return 'Black (Regur)';
        }
        if (lower4.contains('red')) return 'Red';
        if (lower4.contains('laterite')) return 'Laterite';
        return text.trim();

      case VoiceField.waterAvailability:
        return mapWaterAvailability(text) ?? text.trim();

      case VoiceField.farmingMethod:
        final lower5 = text.toLowerCase();
        if (lower5.contains('organic')) return 'Organic Farming';
        if (lower5.contains('integrated')) return 'Integrated Farming';
        if (lower5.contains('conventional') || lower5.contains('chemical')) {
          return 'Conventional/Chemical Farming';
        }
        if (lower5.contains('natural')) return 'Natural Farming';
        if (lower5.contains('precision')) return 'Precision Farming';
        return text.trim();

      case VoiceField.none:
        return text;
    }
  }

  static String? mapWaterAvailability(String text) {
    final lower = text.toLowerCase();
    // English
    if (lower.contains('high') ||
        lower.contains('plenty') ||
        lower.contains('more water') ||
        lower.contains('lots of water') ||
        lower.contains('abundant')) {
      return 'High';
    }
    if (lower.contains('medium') ||
        lower.contains('moderate') ||
        lower.contains('average')) {
      return 'Medium';
    }
    if (lower.contains('low') ||
        lower.contains('less water') ||
        lower.contains('scarce') && !lower.contains('very')) {
      return 'Low';
    }
    if (lower.contains('very low') ||
        lower.contains('very less') ||
        lower.contains('drought') ||
        lower.contains('severe')) {
      return 'Very Low';
    }
    if (lower.contains('no water') ||
        lower.contains('none') ||
        lower.contains('zero')) {
      return 'No Water';
    }
    // Tamil
    if (lower.contains('அதிகமா') ||
        lower.contains('நிறைய') ||
        lower.contains('தண்ணி அதிகமா')) {
      return 'High';
    }
    if (lower.contains('சராசரி') ||
        lower.contains('சுமார்') ||
        lower.contains('மிதமான')) {
      return 'Medium';
    }
    if (lower.contains('குறைவா') ||
        lower.contains('கம்மி') ||
        lower.contains('தண்ணி கம்மி')) {
      return 'Low';
    }
    if (lower.contains('மிகவும் குறைவா') || lower.contains('தண்ணி இல்லாம')) {
      return 'Very Low';
    }
    if (lower.contains('தண்ணி இல்லை') || lower.contains('சுத்தமா இல்லை')) {
      return 'No Water';
    }
    // Telugu
    if (lower.contains('ఎక్కువ') || lower.contains('నీళ్లు ఎక్కువ')) {
      return 'High';
    }
    if (lower.contains('మధ్యస్థం') || lower.contains('సగటు')) return 'Medium';
    if (lower.contains('తక్కువ') && !lower.contains('చాలా తక్కువ')) {
      return 'Low';
    }
    if (lower.contains('చాలా తక్కువ')) return 'Very Low';
    if (lower.contains('నీళ్లు లేదు')) return 'No Water';
    // Hindi
    if (lower.contains('ज़्यादा') ||
        lower.contains('बहुत पानी') ||
        lower.contains('अधिक')) {
      return 'High';
    }
    if (lower.contains('मध्यम') || lower.contains('औसत')) return 'Medium';
    if (lower.contains('कम') && !lower.contains('बहुत कम')) return 'Low';
    if (lower.contains('बहुत कम') || lower.contains('अति कम')) {
      return 'Very Low';
    }
    if (lower.contains('पानी नहीं') || lower.contains('कोई पानी नहीं')) {
      return 'No Water';
    }
    // Kannada
    if (lower.contains('ಹೆಚ್ಚು') || lower.contains('ನೀರು ಹೆಚ್ಚು')) {
      return 'High';
    }
    if (lower.contains('ಮಧ್ಯಮ') || lower.contains('ಸರಾಸರಿ')) return 'Medium';
    if (lower.contains('ಕಡಿಮೆ') && !lower.contains('ತುಂಬಾ ಕಡಿಮೆ')) return 'Low';
    if (lower.contains('ತುಂಬಾ ಕಡಿಮೆ')) return 'Very Low';
    if (lower.contains('ನೀರು ಇಲ್ಲ')) return 'No Water';
    // Malayalam
    if (lower.contains('കൂടുതൽ') || lower.contains('വെള്ളം കൂടുതൽ')) {
      return 'High';
    }
    if (lower.contains('ഇടത്തരം') || lower.contains('ശരാശരി')) return 'Medium';
    if (lower.contains('കുറവ്') && !lower.contains('വളരെ കുറവ്')) return 'Low';
    if (lower.contains('വളരെ കുറവ്')) return 'Very Low';
    if (lower.contains('വെള്ളമില്ല')) return 'No Water';
    // Marathi
    if (lower.contains('जास्त') || lower.contains('पाणी जास्त')) return 'High';
    if (lower.contains('मध्यम') || lower.contains('सरासरी')) return 'Medium';
    if (lower.contains('कमी') && !lower.contains('खूप कमी')) return 'Low';
    if (lower.contains('खूप कमी')) return 'Very Low';
    if (lower.contains('पाणी नाही')) return 'No Water';
    // Bengali
    if (lower.contains('বেশি') || lower.contains('পানি বেশি')) return 'High';
    if (lower.contains('মাঝারি') || lower.contains('গড়')) return 'Medium';
    if (lower.contains('কম') && !lower.contains('খুব কম')) return 'Low';
    if (lower.contains('খুব কম')) return 'Very Low';
    if (lower.contains('পানি নেই')) return 'No Water';
    // Gujarati
    if (lower.contains('વધુ') || lower.contains('પાણી વધુ')) return 'High';
    if (lower.contains('મધ્યમ') || lower.contains('સરેરાશ')) return 'Medium';
    if (lower.contains('�ઓછું') && !lower.contains('ખૂબ ઓછું')) return 'Low';
    if (lower.contains('ખૂબ ઓછું')) return 'Very Low';
    if (lower.contains('પાણી નથી')) return 'No Water';
    // Punjabi
    if (lower.contains('ਵੱਧ') || lower.contains('ਪਾਣੀ ਵੱਧ')) return 'High';
    if (lower.contains('ਦਰਮਿਆਨਾ') || lower.contains('ਔਸਤ')) return 'Medium';
    if (lower.contains('ਘੱਟ') && !lower.contains('ਬਹੁਤ ਘੱਟ')) return 'Low';
    if (lower.contains('ਬਹੁਤ ਘੱਟ')) return 'Very Low';
    if (lower.contains('ਪਾਣੀ ਨਹੀਂ')) return 'No Water';
    // Odia
    if (lower.contains('ବେଶୀ') || lower.contains('ପାଣୀ ବେଶୀ')) return 'High';
    if (lower.contains('ମଧ୍ୟମ') || lower.contains('ଗଡ଼')) return 'Medium';
    if (lower.contains('କମ୍') && !lower.contains('ବହୁତ କମ୍')) return 'Low';
    if (lower.contains('ବହୁତ କମ୍')) return 'Very Low';
    if (lower.contains('ପାଣୀ ନାହିଁ')) return 'No Water';
    // Assamese
    if (lower.contains('বেছি') || lower.contains('পানি বেছি')) return 'High';
    if (lower.contains('মধ্যম') || lower.contains('গড়')) return 'Medium';
    if (lower.contains('কম') && !lower.contains('বহুত কম')) return 'Low';
    if (lower.contains('বহুত কম')) return 'Very Low';
    if (lower.contains('পানি নাই')) return 'No Water';
    // Urdu
    if (lower.contains('زیادہ') || lower.contains('پانی زیادہ')) return 'High';
    if (lower.contains('درمیانی') || lower.contains('اوسط')) return 'Medium';
    if (lower.contains('کم') && !lower.contains('بہت کم')) return 'Low';
    if (lower.contains('بہت کم')) return 'Very Low';
    if (lower.contains('پانی نہیں')) return 'No Water';
    return null;
  }

  static String getLocaleForLanguage(String languageCode) {
    const locales = {
      'en': 'en_US',
      'ta': 'ta_IN',
      'te': 'te_IN',
      'kn': 'kn_IN',
      'ml': 'ml_IN',
      'hi': 'hi_IN',
      'bn': 'bn_IN',
      'mr': 'mr_IN',
      'gu': 'gu_IN',
      'pa': 'pa_IN',
      'or': 'or_IN',
      'as': 'as_IN',
      'ur': 'ur_IN',
    };
    return locales[languageCode] ?? 'en_US';
  }
}
