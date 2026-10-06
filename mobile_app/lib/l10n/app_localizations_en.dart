// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mobile App';

  @override
  String get homeTitle => 'Environment Ready';

  @override
  String get envReadyMessage =>
      'The clean architecture skeleton is running with localization, declarative routing and MVVM state management.';

  @override
  String get architectureSectionTitle => 'Architecture Layers';

  @override
  String get layerUi => 'UI — Views & ViewModels';

  @override
  String get layerDomain => 'Domain — Models & Use Cases';

  @override
  String get layerData => 'Data — Services & Repositories';

  @override
  String get counterSectionTitle => 'MVVM Counter Demo';

  @override
  String counterValue(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count taps',
      zero: 'Ready',
    );
    return '$_temp0';
  }

  @override
  String get increment => 'Increment';

  @override
  String get reset => 'Reset';
}
