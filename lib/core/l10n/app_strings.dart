import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;
  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('am'),
    Locale('ti'),
    Locale('om'),
  ];
  static const LocalizationsDelegate<AppStrings> delegate = _AppStringsDelegate();

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings)!;

  static const Map<String, Map<String, String>> _values =
      <String, Map<String, String>>{
    'en': <String, String>{
      'appName': 'AnimPro',
      'myProjects': 'My projects',
      'createAnimation': 'New animation',
      'search': 'Search projects',
      'recentProjects': 'Recent projects',
      'allProjects': 'All projects',
      'welcomeTitle': 'Make a little magic, frame by frame.',
      'welcomeBody': 'A calm, capable animation studio that stays yours. No AI. No account. Just your ideas and a canvas.',
      'tutorialCanvasTitle': 'Draw directly on the canvas',
      'tutorialTimelineTitle': 'Bring drawings to life',
      'tutorialLayersTitle': 'Keep every idea organized',
      'continueLabel': 'Continue',
      'getStarted': 'Start drawing',
      'noProjects': 'Your next idea starts here.',
      'settingsTitle': 'Settings',
      'appearance': 'Appearance',
      'language': 'Language',
      'light': 'Light',
      'dark': 'Dark',
      'about': 'About AnimPro',
    },
    'am': <String, String>{
      'appName': 'አኒምፕሮ',
      'myProjects': 'ፕሮጀክቶቼ',
      'createAnimation': 'አዲስ አኒሜሽን',
      'search': 'ፕሮጀክቶችን ፈልግ',
      'recentProjects': 'የቅርብ ጊዜ ፕሮጀክቶች',
      'allProjects': 'ሁሉም ፕሮጀክቶች',
      'welcomeTitle': 'በእያንዳንዱ ፍሬም ትንሽ አስማት ይፍጠሩ።',
      'welcomeBody': 'በእጅዎ የሚቆይ ቀላልና ብቁ የአኒሜሽን ስቱዲዮ። ያለ AI፣ ያለ መለያ።',
      'tutorialCanvasTitle': 'በሸራው ላይ በቀጥታ ይሳሉ',
      'tutorialTimelineTitle': 'ስዕሎችን እንቅስቃሴ ያድርጉ',
      'tutorialLayersTitle': 'ሀሳቦችዎን ያደራጁ',
      'continueLabel': 'ቀጥል',
      'getStarted': 'መሳል ጀምር',
      'noProjects': 'ቀጣይ ሀሳብዎ እዚህ ይጀምራል።',
      'settingsTitle': 'ቅንብሮች',
      'appearance': 'መልክ',
      'language': 'ቋንቋ',
      'light': 'ብርሃን',
      'dark': 'ጨለማ',
      'about': 'ስለ AnimPro',
    },
    'ti': <String, String>{
      'appName': 'ኣኒምፕሮ',
      'myProjects': 'ፕሮጀክተይ',
      'createAnimation': 'ሓድሽ ኣኒሜሽን',
      'search': 'ፕሮጀክት ድለ',
      'recentProjects': 'ናይ ቀረባ ግዜ ፕሮጀክት',
      'allProjects': 'ኩሎም ፕሮጀክት',
      'welcomeTitle': 'ብነፍሲ ወከፍ ፍሬም ቁሩብ ተኣምር ፍጠር።',
      'welcomeBody': 'ኣብ ቁጽጽርካ ዝኾነ ቀሊልን ውጽኢታውን ስቱድዮ። AI የለን፣ መለያ ኣየድልን።',
      'tutorialCanvasTitle': 'ብቐጥታ ኣብ ሸራ ስኣል',
      'tutorialTimelineTitle': 'ስእልታት ኣንቀሳቕስ',
      'tutorialLayersTitle': 'ሓሳባትካ ኣዳሉ',
      'continueLabel': 'ቀጽል',
      'getStarted': 'ስኣል ጀምር',
      'noProjects': 'ዝቕጽል ሓሳብካ ኣብዚ ይጅምር።',
      'settingsTitle': 'ቅንብራት',
      'appearance': 'ትርኢት',
      'language': 'ቋንቋ',
      'light': 'ብርሃን',
      'dark': 'ጸልማት',
      'about': 'ብዛዕባ AnimPro',
    },
    'om': <String, String>{
      'appName': 'AnimPro',
      'myProjects': 'Pirojektoota koo',
      'createAnimation': 'Animeeshinii haaraa',
      'search': 'Pirojektoota barbaadi',
      'recentProjects': 'Pirojektoota dhiheenyaa',
      'allProjects': 'Pirojektoota hunda',
      'welcomeTitle': 'Fureemii hundaan xiqqoo uumama uumi.',
      'welcomeBody': 'Istuudiyoo salphaa fi dandeettii qabu kan siif ta’u. AI hin jiru, herregni hin barbaachisu.',
      'tutorialCanvasTitle': 'Kanfasi irratti kallattiin kaasi',
      'tutorialTimelineTitle': 'Fakkii sochoosi',
      'tutorialLayersTitle': 'Yaada kee qindeessi',
      'continueLabel': 'Itti fufi',
      'getStarted': 'Ka’uu jalqabi',
      'noProjects': 'Yaadni kee itti aanu asitti jalqaba.',
      'settingsTitle': 'Qindaa’ina',
      'appearance': 'Bifa',
      'language': 'Afaan',
      'light': 'Ifaa',
      'dark': 'Dukkana',
      'about': 'Waa’ee AnimPro',
    },
  };

  String text(String key) =>
      _values[locale.languageCode]?[key] ?? _values['en']![key] ?? key;
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppStrings.supportedLocales.any((item) => item.languageCode == locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) => SynchronousFuture<AppStrings>(AppStrings(locale));

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppStrings> old) => false;
}
