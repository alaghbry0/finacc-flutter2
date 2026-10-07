import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal Accountant'**
  String get appTitle;

  /// No description provided for @appBrand.
  ///
  /// In en, this message translates to:
  /// **'FinAcc'**
  String get appBrand;

  /// No description provided for @brandTagline.
  ///
  /// In en, this message translates to:
  /// **'Complete accounting & inventory system — works fully offline'**
  String get brandTagline;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get commonDetails;

  /// No description provided for @commonViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get commonViewAll;

  /// No description provided for @splashLoading.
  ///
  /// In en, this message translates to:
  /// **'Preparing your local database…'**
  String get splashLoading;

  /// No description provided for @onboardWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Personal Accountant'**
  String get onboardWelcomeTitle;

  /// No description provided for @onboardWelcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'A complete accounting and inventory system for your shop — your data stays on your device, offline, no subscriptions.'**
  String get onboardWelcomeMessage;

  /// No description provided for @onboardFeature1Title.
  ///
  /// In en, this message translates to:
  /// **'Works 100% offline'**
  String get onboardFeature1Title;

  /// No description provided for @onboardFeature1Desc.
  ///
  /// In en, this message translates to:
  /// **'Sell, buy, stocktake and report — even with no network at all.'**
  String get onboardFeature1Desc;

  /// No description provided for @onboardFeature2Title.
  ///
  /// In en, this message translates to:
  /// **'Numbers you can trust'**
  String get onboardFeature2Title;

  /// No description provided for @onboardFeature2Desc.
  ///
  /// In en, this message translates to:
  /// **'Atomic document numbering that never repeats, weighted-average cost, and hard protection against negative stock.'**
  String get onboardFeature2Desc;

  /// No description provided for @onboardFeature3Title.
  ///
  /// In en, this message translates to:
  /// **'Full privacy'**
  String get onboardFeature3Title;

  /// No description provided for @onboardFeature3Desc.
  ///
  /// In en, this message translates to:
  /// **'No data ever leaves to any server — your backups belong to you.'**
  String get onboardFeature3Desc;

  /// No description provided for @onboardStepCompany.
  ///
  /// In en, this message translates to:
  /// **'Company details'**
  String get onboardStepCompany;

  /// No description provided for @onboardStepSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get onboardStepSecurity;

  /// No description provided for @onboardStepReview.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get onboardStepReview;

  /// No description provided for @companyNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Company name'**
  String get companyNameLabel;

  /// No description provided for @companyNameHint.
  ///
  /// In en, this message translates to:
  /// **'As it appears to customers on invoices'**
  String get companyNameHint;

  /// No description provided for @companyPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get companyPhoneLabel;

  /// No description provided for @companyPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'For WhatsApp support and reminders later'**
  String get companyPhoneHint;

  /// No description provided for @baseCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Base currency'**
  String get baseCurrencyLabel;

  /// No description provided for @baseCurrencyHint.
  ///
  /// In en, this message translates to:
  /// **'Fixed after setup — other currencies get daily rates'**
  String get baseCurrencyHint;

  /// No description provided for @baseCurrencyDecimalsNote.
  ///
  /// In en, this message translates to:
  /// **'{decimals, plural, zero{no decimals} one{one decimal place} other{decimal places: {decimals}}}'**
  String baseCurrencyDecimalsNote(num decimals);

  /// No description provided for @companyFormInvalid.
  ///
  /// In en, this message translates to:
  /// **'Complete the company name and choose a base currency'**
  String get companyFormInvalid;

  /// No description provided for @pinSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Your PIN code'**
  String get pinSetupTitle;

  /// No description provided for @pinSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'4 to 6 digits — asked every time the app opens'**
  String get pinSetupSubtitle;

  /// No description provided for @pinConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm the code'**
  String get pinConfirmTitle;

  /// No description provided for @pinConfirmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Re-enter the same code to confirm'**
  String get pinConfirmSubtitle;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'The codes do not match. Try again.'**
  String get pinMismatch;

  /// No description provided for @pinInvalidLength.
  ///
  /// In en, this message translates to:
  /// **'The code must be 4 to 6 digits.'**
  String get pinInvalidLength;

  /// No description provided for @passphraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Recovery passphrase'**
  String get passphraseTitle;

  /// No description provided for @passphraseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recovery gate when the PIN is forgotten (after 10 wrong attempts) — it can never be recovered'**
  String get passphraseSubtitle;

  /// No description provided for @passphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Passphrase (8 characters or more)'**
  String get passphraseLabel;

  /// No description provided for @passphraseConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm passphrase'**
  String get passphraseConfirmLabel;

  /// No description provided for @passphraseMismatch.
  ///
  /// In en, this message translates to:
  /// **'The passphrases do not match. Try again.'**
  String get passphraseMismatch;

  /// No description provided for @passphraseWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Important — read before continuing'**
  String get passphraseWarningTitle;

  /// No description provided for @passphraseWarningBody.
  ///
  /// In en, this message translates to:
  /// **'Forgetting the passphrase means permanent loss of access; the only recovery is a backup file you keep. Store it safely and enable backups early.'**
  String get passphraseWarningBody;

  /// No description provided for @passphraseShort.
  ///
  /// In en, this message translates to:
  /// **'The passphrase must be at least 8 characters.'**
  String get passphraseShort;

  /// No description provided for @creatingTitle.
  ///
  /// In en, this message translates to:
  /// **'Setting up your shop…'**
  String get creatingTitle;

  /// No description provided for @creatingMessage.
  ///
  /// In en, this message translates to:
  /// **'Creating the company, main warehouse, main cashbox and fiscal year inside one safe transaction — any failure rolls everything back.'**
  String get creatingMessage;

  /// No description provided for @createdTitle.
  ///
  /// In en, this message translates to:
  /// **'Setup complete'**
  String get createdTitle;

  /// No description provided for @createdMessage.
  ///
  /// In en, this message translates to:
  /// **'We created “{warehouse}” and “{cashbox}”, ready for your first invoice — no mandatory setup remains.'**
  String createdMessage(Object cashbox, Object warehouse);

  /// No description provided for @startUsing.
  ///
  /// In en, this message translates to:
  /// **'Start using'**
  String get startUsing;

  /// No description provided for @setupFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Setup could not complete'**
  String get setupFailedTitle;

  /// No description provided for @setupFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Review the details and try again — nothing was written to the database.'**
  String get setupFailedBody;

  /// No description provided for @lockTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN'**
  String get lockTitle;

  /// No description provided for @lockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The app is locked to protect your financial data'**
  String get lockSubtitle;

  /// No description provided for @lockWrong.
  ///
  /// In en, this message translates to:
  /// **'Incorrect code'**
  String get lockWrong;

  /// No description provided for @lockAttemptsBeforeLock.
  ///
  /// In en, this message translates to:
  /// **'{count} attempts left before a temporary delay'**
  String lockAttemptsBeforeLock(Object count);

  /// No description provided for @lockDelayedMessage.
  ///
  /// In en, this message translates to:
  /// **'Wait {duration} then try again'**
  String lockDelayedMessage(Object duration);

  /// No description provided for @lockPassphraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Passphrase required'**
  String get lockPassphraseTitle;

  /// No description provided for @lockPassphraseMessage.
  ///
  /// In en, this message translates to:
  /// **'All ten PIN attempts are used. Enter the passphrase you chose during setup to regain access.'**
  String get lockPassphraseMessage;

  /// No description provided for @lockPassphraseFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Passphrase'**
  String get lockPassphraseFieldLabel;

  /// No description provided for @lockPassphraseFailed.
  ///
  /// In en, this message translates to:
  /// **'Incorrect passphrase.'**
  String get lockPassphraseFailed;

  /// No description provided for @lockUnlockButton.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get lockUnlockButton;

  /// No description provided for @lockUsePassphrase.
  ///
  /// In en, this message translates to:
  /// **'Use passphrase'**
  String get lockUsePassphrase;

  /// No description provided for @lockBackToPin.
  ///
  /// In en, this message translates to:
  /// **'Back to PIN'**
  String get lockBackToPin;

  /// No description provided for @lockVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get lockVerifying;

  /// No description provided for @wipeDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Wipe all data?'**
  String get wipeDialogTitle;

  /// No description provided for @wipeDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Everything will be permanently erased — invoices, items, balances and settings — and the app returns to first-install state. This cannot be undone.'**
  String get wipeDialogBody;

  /// No description provided for @wipeConfirmWord.
  ///
  /// In en, this message translates to:
  /// **'wipe'**
  String get wipeConfirmWord;

  /// No description provided for @wipeFinalTitle.
  ///
  /// In en, this message translates to:
  /// **'Final confirmation'**
  String get wipeFinalTitle;

  /// No description provided for @wipeFinalBody.
  ///
  /// In en, this message translates to:
  /// **'Type “wipe” exactly to confirm erasing the whole database. If you have a backup file it stays safe outside the app.'**
  String get wipeFinalBody;

  /// No description provided for @wipeDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Data wiped'**
  String get wipeDoneTitle;

  /// No description provided for @wipeDoneBody.
  ///
  /// In en, this message translates to:
  /// **'The app will now reopen on the setup screen.'**
  String get wipeDoneBody;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get dashboardTitle;

  /// No description provided for @dashboardQuickAccess.
  ///
  /// In en, this message translates to:
  /// **'Quick access'**
  String get dashboardQuickAccess;

  /// No description provided for @dashboardQuickRates.
  ///
  /// In en, this message translates to:
  /// **'Rates'**
  String get dashboardQuickRates;

  /// No description provided for @morningGreeting.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get morningGreeting;

  /// No description provided for @eveningGreeting.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get eveningGreeting;

  /// No description provided for @todaySales.
  ///
  /// In en, this message translates to:
  /// **'Today\'s sales'**
  String get todaySales;

  /// No description provided for @todayProfit.
  ///
  /// In en, this message translates to:
  /// **'Today\'s profit'**
  String get todayProfit;

  /// No description provided for @todayInvoices.
  ///
  /// In en, this message translates to:
  /// **'Today\'s invoices'**
  String get todayInvoices;

  /// No description provided for @netCash.
  ///
  /// In en, this message translates to:
  /// **'Net cash'**
  String get netCash;

  /// No description provided for @last30DaysTitle.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days of sales'**
  String get last30DaysTitle;

  /// No description provided for @chartEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Your sales will appear here after the first invoice'**
  String get chartEmptyMessage;

  /// No description provided for @stockAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock alerts'**
  String get stockAlertsTitle;

  /// No description provided for @stockAlertsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No alerts — all items are above their minimum'**
  String get stockAlertsEmpty;

  /// No description provided for @stockAlertsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, zero{no items} one{one item} other{{count} items}} below minimum'**
  String stockAlertsCount(num count);

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabSell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get tabSell;

  /// No description provided for @tabInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get tabInventory;

  /// No description provided for @tabCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get tabCash;

  /// No description provided for @tabMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get tabMore;

  /// No description provided for @comingSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Coming in the next slices'**
  String get comingSoonTitle;

  /// No description provided for @comingSoonBody.
  ///
  /// In en, this message translates to:
  /// **'The “{feature}” module is built in its dedicated slice after phase one approval — the architecture and database are already ready for it.'**
  String comingSoonBody(Object feature);

  /// No description provided for @comingGatedBadge.
  ///
  /// In en, this message translates to:
  /// **'Awaiting phase-one approval'**
  String get comingGatedBadge;

  /// No description provided for @featureSell.
  ///
  /// In en, this message translates to:
  /// **'Selling & POS'**
  String get featureSell;

  /// No description provided for @featureInventory.
  ///
  /// In en, this message translates to:
  /// **'Items, stock & batches'**
  String get featureInventory;

  /// No description provided for @featureCash.
  ///
  /// In en, this message translates to:
  /// **'Cashboxes & cash'**
  String get featureCash;

  /// No description provided for @featureMore.
  ///
  /// In en, this message translates to:
  /// **'Parties, reports & settings'**
  String get featureMore;

  /// No description provided for @comingSellH1.
  ///
  /// In en, this message translates to:
  /// **'A fast POS — one or two taps per item'**
  String get comingSellH1;

  /// No description provided for @comingSellH2.
  ///
  /// In en, this message translates to:
  /// **'Credit invoices and full installment plans with guard policies'**
  String get comingSellH2;

  /// No description provided for @comingInventoryH1.
  ///
  /// In en, this message translates to:
  /// **'Items with weighted-average cost and barcode cards'**
  String get comingInventoryH1;

  /// No description provided for @comingInventoryH2.
  ///
  /// In en, this message translates to:
  /// **'Supply batches, FEFO expiry dates, and negative-stock protection'**
  String get comingInventoryH2;

  /// No description provided for @comingCashH1.
  ///
  /// In en, this message translates to:
  /// **'Receipt and payment movements across multiple cashboxes'**
  String get comingCashH1;

  /// No description provided for @comingCashH2.
  ///
  /// In en, this message translates to:
  /// **'Reconciliations and end-of-day balances in all currencies'**
  String get comingCashH2;

  /// No description provided for @comingMoreH1.
  ///
  /// In en, this message translates to:
  /// **'Parties (customers/suppliers) with governed credit limits'**
  String get comingMoreH1;

  /// No description provided for @comingMoreH2.
  ///
  /// In en, this message translates to:
  /// **'Reports, analytics, and scheduled backups'**
  String get comingMoreH2;

  /// No description provided for @settingsBaseCurrency.
  ///
  /// In en, this message translates to:
  /// **'Base currency'**
  String get settingsBaseCurrency;

  /// No description provided for @settingsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get settingsAdmin;

  /// No description provided for @settingsAutolock.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock after'**
  String get settingsAutolock;

  /// No description provided for @settingsAutolackValue.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, one{one minute} other{{minutes} minutes}} of inactivity'**
  String settingsAutolackValue(num minutes);

  /// No description provided for @settingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurity;

  /// No description provided for @settingsChangePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get settingsChangePin;

  /// No description provided for @settingsChangePinDesc.
  ///
  /// In en, this message translates to:
  /// **'Verify your current PIN, then set a new one'**
  String get settingsChangePinDesc;

  /// No description provided for @settingsLockNow.
  ///
  /// In en, this message translates to:
  /// **'Lock the app now'**
  String get settingsLockNow;

  /// No description provided for @settingsLockNowDesc.
  ///
  /// In en, this message translates to:
  /// **'Returns to the sign-in screen immediately'**
  String get settingsLockNowDesc;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsTheme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Auto (follow system)'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @settingsThemeNote.
  ///
  /// In en, this message translates to:
  /// **'Your choice is stored in your local database and survives restarts.'**
  String get settingsThemeNote;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsData;

  /// No description provided for @settingsWipe.
  ///
  /// In en, this message translates to:
  /// **'Erase all data'**
  String get settingsWipe;

  /// No description provided for @settingsWipeDesc.
  ///
  /// In en, this message translates to:
  /// **'Resets the app to first-install state — irreversible'**
  String get settingsWipeDesc;

  /// No description provided for @settingsAboutPhase1.
  ///
  /// In en, this message translates to:
  /// **'Phase 1 complete'**
  String get settingsAboutPhase1;

  /// No description provided for @settingsAboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0 — Slice 0 + Slice 1'**
  String get settingsAboutVersion;

  /// No description provided for @settingsAboutSrs.
  ///
  /// In en, this message translates to:
  /// **'Built per the approved SRS v1.5 specification'**
  String get settingsAboutSrs;

  /// No description provided for @changePinStep1Label.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get changePinStep1Label;

  /// No description provided for @changePinStep2Label.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get changePinStep2Label;

  /// No description provided for @changePinStep3Label.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get changePinStep3Label;

  /// No description provided for @changePinStepCurrent.
  ///
  /// In en, this message translates to:
  /// **'Enter your current PIN to continue'**
  String get changePinStepCurrent;

  /// No description provided for @changePinStepNew.
  ///
  /// In en, this message translates to:
  /// **'Choose a new PIN of 4 to 6 digits'**
  String get changePinStepNew;

  /// No description provided for @changePinStepConfirm.
  ///
  /// In en, this message translates to:
  /// **'Re-enter the new PIN to confirm'**
  String get changePinStepConfirm;

  /// No description provided for @changePinDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'PIN changed successfully'**
  String get changePinDoneTitle;

  /// No description provided for @changePinDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Use the new PIN to unlock the app from now on — the change has been recorded in the audit log.'**
  String get changePinDoneBody;

  /// No description provided for @changePinWrongCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current PIN is incorrect — try again'**
  String get changePinWrongCurrent;

  /// No description provided for @changePinSameAsCurrent.
  ///
  /// In en, this message translates to:
  /// **'The new PIN matches the current one — choose a different PIN'**
  String get changePinSameAsCurrent;

  /// No description provided for @changePinNoPin.
  ///
  /// In en, this message translates to:
  /// **'No PIN is configured — set up the app again'**
  String get changePinNoPin;

  /// No description provided for @dbOpenErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not open the database'**
  String get dbOpenErrorTitle;

  /// No description provided for @dbOpenErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'The database file may be busy or storage is full. Try again — your data is unaffected.'**
  String get dbOpenErrorMessage;

  /// No description provided for @genericErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred'**
  String get genericErrorTitle;

  /// No description provided for @loadingData.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loadingData;

  /// No description provided for @settingsAutolockSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock delay'**
  String get settingsAutolockSheetTitle;

  /// No description provided for @settingsAutolockSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The app locks after this idle period — allowed range is 1 to 60 minutes.'**
  String get settingsAutolockSheetSubtitle;

  /// No description provided for @settingsNumerals.
  ///
  /// In en, this message translates to:
  /// **'Numerals'**
  String get settingsNumerals;

  /// No description provided for @numeralsWestern.
  ///
  /// In en, this message translates to:
  /// **'Western'**
  String get numeralsWestern;

  /// No description provided for @numeralsArabicIndic.
  ///
  /// In en, this message translates to:
  /// **'Eastern Arabic'**
  String get numeralsArabicIndic;

  /// No description provided for @settingsNumeralsNote.
  ///
  /// In en, this message translates to:
  /// **'Applies instantly to amounts and dates across the app — storage always stays in western digits.'**
  String get settingsNumeralsNote;

  /// No description provided for @settingsAuditLog.
  ///
  /// In en, this message translates to:
  /// **'Audit log'**
  String get settingsAuditLog;

  /// No description provided for @settingsAuditLogDesc.
  ///
  /// In en, this message translates to:
  /// **'Extended security events — append-only'**
  String get settingsAuditLogDesc;

  /// No description provided for @auditTitle.
  ///
  /// In en, this message translates to:
  /// **'Audit log'**
  String get auditTitle;

  /// No description provided for @auditProtectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Protected inside your database'**
  String get auditProtectedTitle;

  /// No description provided for @auditProtectedBody.
  ///
  /// In en, this message translates to:
  /// **'Critical security events are recorded here and can never be edited or deleted from the app — the protection itself lives inside the database file (triggers block updates and deletes from any tool).'**
  String get auditProtectedBody;

  /// No description provided for @auditAppendOnlyBadge.
  ///
  /// In en, this message translates to:
  /// **'Append-only'**
  String get auditAppendOnlyBadge;

  /// No description provided for @auditEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No events recorded yet'**
  String get auditEmptyTitle;

  /// No description provided for @auditEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Critical security events appear here: setup, PIN changes, lockout thresholds, and security settings changes.'**
  String get auditEmptyBody;

  /// No description provided for @auditDayToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get auditDayToday;

  /// No description provided for @auditDayYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get auditDayYesterday;

  /// No description provided for @auditActionAppSetup.
  ///
  /// In en, this message translates to:
  /// **'App setup'**
  String get auditActionAppSetup;

  /// No description provided for @auditActionPinChange.
  ///
  /// In en, this message translates to:
  /// **'PIN changed'**
  String get auditActionPinChange;

  /// No description provided for @auditActionLockoutDelay.
  ///
  /// In en, this message translates to:
  /// **'Attempt limit exceeded — temporary delay'**
  String get auditActionLockoutDelay;

  /// No description provided for @auditActionLockoutPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Attempts exhausted — passphrase required'**
  String get auditActionLockoutPassphrase;

  /// No description provided for @auditActionSettingsChange.
  ///
  /// In en, this message translates to:
  /// **'Security setting changed'**
  String get auditActionSettingsChange;

  /// No description provided for @auditActionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Event: {action}'**
  String auditActionUnknown(Object action);

  /// No description provided for @auditLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more ({shown} of {total})'**
  String auditLoadMore(Object shown, Object total);

  /// No description provided for @auditFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get auditFilterAll;

  /// No description provided for @auditFilterSetup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get auditFilterSetup;

  /// No description provided for @auditFilterSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get auditFilterSecurity;

  /// No description provided for @auditFilterSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get auditFilterSettings;

  /// No description provided for @auditFilterOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get auditFilterOther;

  /// No description provided for @auditFilterEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No events in this category'**
  String get auditFilterEmptyTitle;

  /// No description provided for @auditFilterEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Pick another category or clear the filter to see all recorded events.'**
  String get auditFilterEmptyBody;

  /// No description provided for @auditCountsAll.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No events} one{1 event} other{{count} events}}'**
  String auditCountsAll(num count);

  /// No description provided for @settingsLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get settingsLicenses;

  /// No description provided for @settingsLicensesDesc.
  ///
  /// In en, this message translates to:
  /// **'Open-source components inside the app'**
  String get settingsLicensesDesc;

  /// No description provided for @dateSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s date'**
  String get dateSheetTitle;

  /// No description provided for @dateSheetTodayBadge.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dateSheetTodayBadge;

  /// No description provided for @dateSheetHijriLabel.
  ///
  /// In en, this message translates to:
  /// **'Hijri calendar'**
  String get dateSheetHijriLabel;

  /// No description provided for @dateSheetGregorianLabel.
  ///
  /// In en, this message translates to:
  /// **'Gregorian calendar'**
  String get dateSheetGregorianLabel;

  /// No description provided for @dateSheetWeekdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Weekday'**
  String get dateSheetWeekdayLabel;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @inventoryHomeHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Inventory management'**
  String get inventoryHomeHeroTitle;

  /// No description provided for @inventoryHomeHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your items, batches and stock in one place — classify, track and get alerted before running out'**
  String get inventoryHomeHeroSubtitle;

  /// No description provided for @inventoryHubAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add a new item'**
  String get inventoryHubAddItem;

  /// No description provided for @inventoryHubAddItemDesc.
  ///
  /// In en, this message translates to:
  /// **'Name, barcode, category and prices in all currencies'**
  String get inventoryHubAddItemDesc;

  /// No description provided for @inventoryHubItems.
  ///
  /// In en, this message translates to:
  /// **'Available items'**
  String get inventoryHubItems;

  /// No description provided for @inventoryHubItemsDesc.
  ///
  /// In en, this message translates to:
  /// **'Instant search by name or barcode with category filters'**
  String get inventoryHubItemsDesc;

  /// No description provided for @inventoryHubLowStock.
  ///
  /// In en, this message translates to:
  /// **'Items running low'**
  String get inventoryHubLowStock;

  /// No description provided for @inventoryHubLowStockDesc.
  ///
  /// In en, this message translates to:
  /// **'Every item at or below its reorder level — full outages included'**
  String get inventoryHubLowStockDesc;

  /// No description provided for @inventoryHubBatches.
  ///
  /// In en, this message translates to:
  /// **'Batches & expiry dates'**
  String get inventoryHubBatches;

  /// No description provided for @inventoryHubBatchesDesc.
  ///
  /// In en, this message translates to:
  /// **'FEFO alerts for expired and soon-to-expire batches'**
  String get inventoryHubBatchesDesc;

  /// No description provided for @inventoryHubImport.
  ///
  /// In en, this message translates to:
  /// **'Import items from a file'**
  String get inventoryHubImport;

  /// No description provided for @inventoryHubImportDesc.
  ///
  /// In en, this message translates to:
  /// **'CSV or Excel with validation and review before insert'**
  String get inventoryHubImportDesc;

  /// No description provided for @inventoryHubCategoriesUnits.
  ///
  /// In en, this message translates to:
  /// **'Categories & units'**
  String get inventoryHubCategoriesUnits;

  /// No description provided for @inventoryHubCategoriesUnitsDesc.
  ///
  /// In en, this message translates to:
  /// **'Two-level category tree and units with conversion factors'**
  String get inventoryHubCategoriesUnitsDesc;

  /// No description provided for @itemsListTitle.
  ///
  /// In en, this message translates to:
  /// **'Available items'**
  String get itemsListTitle;

  /// No description provided for @itemsListSubtitleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items yet} one{1 item} other{{count} items}}'**
  String itemsListSubtitleCount(num count);

  /// No description provided for @itemsListSubtitleApprox.
  ///
  /// In en, this message translates to:
  /// **'More than {count} items'**
  String itemsListSubtitleApprox(Object count);

  /// No description provided for @itemsListSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or barcode'**
  String get itemsListSearchHint;

  /// No description provided for @itemsListFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get itemsListFilterAll;

  /// No description provided for @itemsListStockLabel.
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get itemsListStockLabel;

  /// No description provided for @itemsListPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get itemsListPriceLabel;

  /// No description provided for @itemsListOutOfStockBadge.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get itemsListOutOfStockBadge;

  /// No description provided for @itemsListLowStockBadge.
  ///
  /// In en, this message translates to:
  /// **'Running low'**
  String get itemsListLowStockBadge;

  /// No description provided for @itemServiceBadge.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get itemServiceBadge;

  /// No description provided for @itemBatchesBadge.
  ///
  /// In en, this message translates to:
  /// **'Batches'**
  String get itemBatchesBadge;

  /// No description provided for @itemsListAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a new item'**
  String get itemsListAddTooltip;

  /// No description provided for @itemsListLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more ({shown})'**
  String itemsListLoadMore(Object shown);

  /// No description provided for @itemsListEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No items yet'**
  String get itemsListEmptyTitle;

  /// No description provided for @itemsListEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Create your first item to track its stock and prices, or import a ready list from a CSV or Excel file.'**
  String get itemsListEmptyBody;

  /// No description provided for @itemsListEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Add first item'**
  String get itemsListEmptyAction;

  /// No description provided for @itemsListSearchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching results'**
  String get itemsListSearchEmptyTitle;

  /// No description provided for @itemsListSearchEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try another keyword or clear the search to see all items.'**
  String get itemsListSearchEmptyBody;

  /// No description provided for @itemFormAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a new item'**
  String get itemFormAddTitle;

  /// No description provided for @itemFormEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get itemFormEditTitle;

  /// No description provided for @itemFormEditNote.
  ///
  /// In en, this message translates to:
  /// **'Stock is not edited here — the opening quantity is entered on creation only; afterwards it changes through purchase, sale and stocktake movements.'**
  String get itemFormEditNote;

  /// No description provided for @itemFormNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get itemFormNameLabel;

  /// No description provided for @itemFormNameHint.
  ///
  /// In en, this message translates to:
  /// **'As it appears on invoices and in search'**
  String get itemFormNameHint;

  /// No description provided for @itemFormNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Item name is required'**
  String get itemFormNameRequired;

  /// No description provided for @itemFormBarcodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get itemFormBarcodeLabel;

  /// No description provided for @itemFormBarcodeHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to auto-generate an EAN-13 on save'**
  String get itemFormBarcodeHint;

  /// No description provided for @itemFormBarcodeGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get itemFormBarcodeGenerate;

  /// No description provided for @itemFormBarcodeRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get itemFormBarcodeRegenerate;

  /// No description provided for @itemFormBarcodeQrToggle.
  ///
  /// In en, this message translates to:
  /// **'QR'**
  String get itemFormBarcodeQrToggle;

  /// No description provided for @itemFormBarcodeEanToggle.
  ///
  /// In en, this message translates to:
  /// **'EAN'**
  String get itemFormBarcodeEanToggle;

  /// No description provided for @itemFormCode128Caption.
  ///
  /// In en, this message translates to:
  /// **'Code128 — supplier barcode'**
  String get itemFormCode128Caption;

  /// No description provided for @itemFormCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get itemFormCategoryLabel;

  /// No description provided for @itemFormCategoryNone.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get itemFormCategoryNone;

  /// No description provided for @itemFormCategoryAdd.
  ///
  /// In en, this message translates to:
  /// **'New category…'**
  String get itemFormCategoryAdd;

  /// No description provided for @itemFormUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit of measure'**
  String get itemFormUnitLabel;

  /// No description provided for @itemFormUnitNone.
  ///
  /// In en, this message translates to:
  /// **'No unit'**
  String get itemFormUnitNone;

  /// No description provided for @itemFormUnitAdd.
  ///
  /// In en, this message translates to:
  /// **'New unit…'**
  String get itemFormUnitAdd;

  /// No description provided for @itemFormCostLabel.
  ///
  /// In en, this message translates to:
  /// **'Cost price'**
  String get itemFormCostLabel;

  /// No description provided for @itemFormCostInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid cost price (zero or more)'**
  String get itemFormCostInvalid;

  /// No description provided for @itemFormMinStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Reorder level'**
  String get itemFormMinStockLabel;

  /// No description provided for @itemFormMinStockHint.
  ///
  /// In en, this message translates to:
  /// **'Alert when stock falls below this level'**
  String get itemFormMinStockHint;

  /// No description provided for @itemFormMinStockInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid level (zero or more)'**
  String get itemFormMinStockInvalid;

  /// No description provided for @itemFormOpeningQtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Opening quantity'**
  String get itemFormOpeningQtyLabel;

  /// No description provided for @itemFormOpeningQtyHint.
  ///
  /// In en, this message translates to:
  /// **'Recorded as an opening balance in the main warehouse'**
  String get itemFormOpeningQtyHint;

  /// No description provided for @itemFormOpeningQtyInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid quantity (zero or more)'**
  String get itemFormOpeningQtyInvalid;

  /// No description provided for @itemFormServiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Service item'**
  String get itemFormServiceLabel;

  /// No description provided for @itemFormServiceDesc.
  ///
  /// In en, this message translates to:
  /// **'No stock or quantity — e.g. delivery or installation'**
  String get itemFormServiceDesc;

  /// No description provided for @itemFormTrackBatchesLabel.
  ///
  /// In en, this message translates to:
  /// **'Track batches & expiry'**
  String get itemFormTrackBatchesLabel;

  /// No description provided for @itemFormTrackBatchesDesc.
  ///
  /// In en, this message translates to:
  /// **'Quantity is managed in FEFO-ordered batches with expiry dates — record batches from the item card after saving.'**
  String get itemFormTrackBatchesDesc;

  /// No description provided for @itemFormPricesSection.
  ///
  /// In en, this message translates to:
  /// **'Sale prices'**
  String get itemFormPricesSection;

  /// No description provided for @itemFormPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Sale price — {currency}'**
  String itemFormPriceLabel(Object currency);

  /// No description provided for @itemFormPriceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price (zero or more)'**
  String get itemFormPriceInvalid;

  /// No description provided for @itemFormNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get itemFormNotesLabel;

  /// No description provided for @itemFormNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — shown on the item card'**
  String get itemFormNotesHint;

  /// No description provided for @itemFormSave.
  ///
  /// In en, this message translates to:
  /// **'Save data'**
  String get itemFormSave;

  /// No description provided for @itemFormSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get itemFormSaving;

  /// No description provided for @itemFormSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Item saved successfully'**
  String get itemFormSavedMessage;

  /// No description provided for @categoryNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryNameLabel;

  /// No description provided for @categoryParentLabel.
  ///
  /// In en, this message translates to:
  /// **'Parent category'**
  String get categoryParentLabel;

  /// No description provided for @categoryParentNone.
  ///
  /// In en, this message translates to:
  /// **'— top-level —'**
  String get categoryParentNone;

  /// No description provided for @unitNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit name'**
  String get unitNameLabel;

  /// No description provided for @unitFactorLabel.
  ///
  /// In en, this message translates to:
  /// **'Conversion factor'**
  String get unitFactorLabel;

  /// No description provided for @unitFactorHint.
  ///
  /// In en, this message translates to:
  /// **'Example: 1 carton = 24 pieces → enter 24'**
  String get unitFactorHint;

  /// No description provided for @unitFactorInvalid.
  ///
  /// In en, this message translates to:
  /// **'The conversion factor must be a number greater than zero'**
  String get unitFactorInvalid;

  /// No description provided for @itemDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Item card'**
  String get itemDetailTitle;

  /// No description provided for @itemDetailArchivedBadge.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get itemDetailArchivedBadge;

  /// No description provided for @itemDetailBatchesBadge.
  ///
  /// In en, this message translates to:
  /// **'FEFO batches'**
  String get itemDetailBatchesBadge;

  /// No description provided for @itemDetailCostLabel.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get itemDetailCostLabel;

  /// No description provided for @itemDetailPricesSection.
  ///
  /// In en, this message translates to:
  /// **'Sale prices'**
  String get itemDetailPricesSection;

  /// No description provided for @itemDetailStockSection.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get itemDetailStockSection;

  /// No description provided for @itemDetailTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get itemDetailTotalLabel;

  /// No description provided for @itemDetailMinStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Reorder level'**
  String get itemDetailMinStockLabel;

  /// No description provided for @itemDetailServiceNote.
  ///
  /// In en, this message translates to:
  /// **'Service item — no stock or quantities are tracked.'**
  String get itemDetailServiceNote;

  /// No description provided for @itemDetailBatchesSection.
  ///
  /// In en, this message translates to:
  /// **'Batches — earliest expiry first (FEFO)'**
  String get itemDetailBatchesSection;

  /// No description provided for @itemDetailNoBatches.
  ///
  /// In en, this message translates to:
  /// **'No batches recorded yet — batches are created with purchase invoices.'**
  String get itemDetailNoBatches;

  /// No description provided for @itemDetailMovementsSection.
  ///
  /// In en, this message translates to:
  /// **'Recent movements'**
  String get itemDetailMovementsSection;

  /// No description provided for @itemDetailNoMovements.
  ///
  /// In en, this message translates to:
  /// **'No movements yet'**
  String get itemDetailNoMovements;

  /// No description provided for @itemDetailRemainingLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get itemDetailRemainingLabel;

  /// No description provided for @itemDetailBarcodeNote.
  ///
  /// In en, this message translates to:
  /// **'Printing and sharing arrive with the printing module later — the barcode is ready to scan from the screen.'**
  String get itemDetailBarcodeNote;

  /// No description provided for @itemDetailQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Item QR code'**
  String get itemDetailQrTitle;

  /// No description provided for @itemDetailEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get itemDetailEditAction;

  /// No description provided for @itemDetailArchiveAction.
  ///
  /// In en, this message translates to:
  /// **'Archive item'**
  String get itemDetailArchiveAction;

  /// No description provided for @itemDetailArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive this item?'**
  String get itemDetailArchiveTitle;

  /// No description provided for @itemDetailArchiveBody.
  ///
  /// In en, this message translates to:
  /// **'Archiving instead of deleting — the item disappears from search and sales while its movements and prices remain in history. An item with movements is never deleted.'**
  String get itemDetailArchiveBody;

  /// No description provided for @itemDetailArchivedMessage.
  ///
  /// In en, this message translates to:
  /// **'Item archived — its history is fully preserved'**
  String get itemDetailArchivedMessage;

  /// No description provided for @itemDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'The item does not exist or was removed from the database.'**
  String get itemDetailNotFound;

  /// No description provided for @batchDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{expires today} one{1 day left} other{{count} days left}}'**
  String batchDaysLeft(num count);

  /// No description provided for @batchExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get batchExpired;

  /// No description provided for @batchNoExpiry.
  ///
  /// In en, this message translates to:
  /// **'No expiry'**
  String get batchNoExpiry;

  /// No description provided for @itemMovementOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get itemMovementOpening;

  /// No description provided for @itemMovementPurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get itemMovementPurchase;

  /// No description provided for @itemMovementSale.
  ///
  /// In en, this message translates to:
  /// **'Sale'**
  String get itemMovementSale;

  /// No description provided for @itemMovementSaleReturn.
  ///
  /// In en, this message translates to:
  /// **'Sales return'**
  String get itemMovementSaleReturn;

  /// No description provided for @itemMovementPurchaseReturn.
  ///
  /// In en, this message translates to:
  /// **'Purchase return'**
  String get itemMovementPurchaseReturn;

  /// No description provided for @itemMovementStocktakeAdjust.
  ///
  /// In en, this message translates to:
  /// **'Stocktake adjustment'**
  String get itemMovementStocktakeAdjust;

  /// No description provided for @itemMovementManualAdjust.
  ///
  /// In en, this message translates to:
  /// **'Manual adjustment'**
  String get itemMovementManualAdjust;

  /// No description provided for @itemMovementTransferIn.
  ///
  /// In en, this message translates to:
  /// **'Transfer in'**
  String get itemMovementTransferIn;

  /// No description provided for @itemMovementTransferOut.
  ///
  /// In en, this message translates to:
  /// **'Transfer out'**
  String get itemMovementTransferOut;

  /// No description provided for @itemMovementUnknown.
  ///
  /// In en, this message translates to:
  /// **'Movement'**
  String get itemMovementUnknown;

  /// No description provided for @lowStockTitle.
  ///
  /// In en, this message translates to:
  /// **'Items running low'**
  String get lowStockTitle;

  /// No description provided for @lowStockThresholdLabel.
  ///
  /// In en, this message translates to:
  /// **'Minimum level'**
  String get lowStockThresholdLabel;

  /// No description provided for @lowStockSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name'**
  String get lowStockSearchHint;

  /// No description provided for @lowStockResultCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items} one{1 item} other{{count} items}}'**
  String lowStockResultCount(num count);

  /// No description provided for @lowStockEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No items match these criteria'**
  String get lowStockEmptyTitle;

  /// No description provided for @lowStockEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'All items are above the set level — raise the level to see more, or change the search keyword.'**
  String get lowStockEmptyBody;

  /// No description provided for @batchesTitle.
  ///
  /// In en, this message translates to:
  /// **'Batches & expiry dates'**
  String get batchesTitle;

  /// No description provided for @batchesFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get batchesFilterAll;

  /// No description provided for @batchesBucketExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get batchesBucketExpired;

  /// No description provided for @batchesBucket30.
  ///
  /// In en, this message translates to:
  /// **'≤ 30 days'**
  String get batchesBucket30;

  /// No description provided for @batchesBucket60.
  ///
  /// In en, this message translates to:
  /// **'≤ 60 days'**
  String get batchesBucket60;

  /// No description provided for @batchesBucket90.
  ///
  /// In en, this message translates to:
  /// **'≤ 90 days'**
  String get batchesBucket90;

  /// No description provided for @batchesResultCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No batches} one{1 batch} other{{count} batches}}'**
  String batchesResultCount(num count);

  /// No description provided for @batchesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No batches in this bucket'**
  String get batchesEmptyTitle;

  /// No description provided for @batchesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Batches are created with purchase invoices for tracked items and are listed here ordered by earliest expiry.'**
  String get batchesEmptyBody;

  /// No description provided for @batchesQtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get batchesQtyLabel;

  /// No description provided for @batchesExpiryLabel.
  ///
  /// In en, this message translates to:
  /// **'Expiry'**
  String get batchesExpiryLabel;

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import items'**
  String get importTitle;

  /// No description provided for @importModeFile.
  ///
  /// In en, this message translates to:
  /// **'File (CSV / Excel)'**
  String get importModeFile;

  /// No description provided for @importModePaste.
  ///
  /// In en, this message translates to:
  /// **'Paste CSV'**
  String get importModePaste;

  /// No description provided for @importPickFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get importPickFile;

  /// No description provided for @importPickFileDesc.
  ///
  /// In en, this message translates to:
  /// **'A CSV or Excel (xlsx) file — the first sheet is read'**
  String get importPickFileDesc;

  /// No description provided for @importPasteHint.
  ///
  /// In en, this message translates to:
  /// **'Paste CSV content here — the first line is the header row'**
  String get importPasteHint;

  /// No description provided for @importPasteFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Name,Barcode,Cost,Qty,Min,Category,Unit'**
  String get importPasteFieldHint;

  /// No description provided for @importClearSource.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get importClearSource;

  /// No description provided for @importContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue to column mapping'**
  String get importContinue;

  /// No description provided for @importMappingSection.
  ///
  /// In en, this message translates to:
  /// **'Column mapping'**
  String get importMappingSection;

  /// No description provided for @importMappingDesc.
  ///
  /// In en, this message translates to:
  /// **'We guessed the mapping from the header row — review and correct as needed.'**
  String get importMappingDesc;

  /// No description provided for @importMappingIgnore.
  ///
  /// In en, this message translates to:
  /// **'— ignore —'**
  String get importMappingIgnore;

  /// No description provided for @importColumnName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get importColumnName;

  /// No description provided for @importColumnBarcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get importColumnBarcode;

  /// No description provided for @importColumnCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get importColumnCost;

  /// No description provided for @importColumnQty.
  ///
  /// In en, this message translates to:
  /// **'Opening quantity'**
  String get importColumnQty;

  /// No description provided for @importColumnMinStock.
  ///
  /// In en, this message translates to:
  /// **'Reorder level'**
  String get importColumnMinStock;

  /// No description provided for @importColumnCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get importColumnCategory;

  /// No description provided for @importColumnUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get importColumnUnit;

  /// No description provided for @importColumnNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get importColumnNotes;

  /// No description provided for @importColumnPrice.
  ///
  /// In en, this message translates to:
  /// **'Price {code}'**
  String importColumnPrice(Object code);

  /// No description provided for @importAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Analyze the file'**
  String get importAnalyze;

  /// No description provided for @importAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing…'**
  String get importAnalyzing;

  /// No description provided for @importNoSource.
  ///
  /// In en, this message translates to:
  /// **'Pick a file or paste CSV content first'**
  String get importNoSource;

  /// No description provided for @importNameNotMapped.
  ///
  /// In en, this message translates to:
  /// **'Map the “Name” column first — it is required'**
  String get importNameNotMapped;

  /// No description provided for @importValidRows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 valid row} other{{count} valid rows}}'**
  String importValidRows(num count);

  /// No description provided for @importFailedRows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 failed row} other{{count} failed rows}}'**
  String importFailedRows(num count);

  /// No description provided for @importFailuresExpand.
  ///
  /// In en, this message translates to:
  /// **'Show failed rows ({count})'**
  String importFailuresExpand(Object count);

  /// No description provided for @importFailuresCollapse.
  ///
  /// In en, this message translates to:
  /// **'Hide failed rows'**
  String get importFailuresCollapse;

  /// No description provided for @importFailureRow.
  ///
  /// In en, this message translates to:
  /// **'Row {row}'**
  String importFailureRow(Object row);

  /// No description provided for @importNewCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories to be created: {names}'**
  String importNewCategories(Object names);

  /// No description provided for @importNewUnits.
  ///
  /// In en, this message translates to:
  /// **'Units to be created: {names}'**
  String importNewUnits(Object names);

  /// No description provided for @importAckLabel.
  ///
  /// In en, this message translates to:
  /// **'I acknowledge inserting only the valid rows and skipping the failed ones'**
  String get importAckLabel;

  /// No description provided for @importCommit.
  ///
  /// In en, this message translates to:
  /// **'Insert valid rows'**
  String get importCommit;

  /// No description provided for @importCommitClean.
  ///
  /// In en, this message translates to:
  /// **'Insert all rows'**
  String get importCommitClean;

  /// No description provided for @importCommitting.
  ///
  /// In en, this message translates to:
  /// **'Inserting…'**
  String get importCommitting;

  /// No description provided for @importResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Import result'**
  String get importResultTitle;

  /// No description provided for @importResultInserted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 item inserted} other{{count} items inserted}}'**
  String importResultInserted(num count);

  /// No description provided for @importResultFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No failed rows} one{1 row failed} other{{count} rows failed}}'**
  String importResultFailed(num count);

  /// No description provided for @importResultCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories created: {count}'**
  String importResultCategories(Object count);

  /// No description provided for @importResultUnits.
  ///
  /// In en, this message translates to:
  /// **'Units created: {count}'**
  String importResultUnits(Object count);

  /// No description provided for @importResultSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Inserted {inserted}, failed {failed}'**
  String importResultSnackbar(Object failed, Object inserted);

  /// No description provided for @importFileReadError.
  ///
  /// In en, this message translates to:
  /// **'Could not read the file — make sure it is a valid CSV or Excel file'**
  String get importFileReadError;

  /// No description provided for @importRestart.
  ///
  /// In en, this message translates to:
  /// **'Import another file'**
  String get importRestart;

  /// No description provided for @categoriesUnitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories & units'**
  String get categoriesUnitsTitle;

  /// No description provided for @categoriesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Item categories'**
  String get categoriesSectionTitle;

  /// No description provided for @categoriesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get categoriesAdd;

  /// No description provided for @categoriesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get categoriesEmptyTitle;

  /// No description provided for @categoriesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Organize your items with top-level and sub categories — they appear in the items list filter.'**
  String get categoriesEmptyBody;

  /// No description provided for @categoriesRootBadge.
  ///
  /// In en, this message translates to:
  /// **'Top-level'**
  String get categoriesRootBadge;

  /// No description provided for @categoriesChildCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 sub-category} other{{count} sub-categories}}'**
  String categoriesChildCount(num count);

  /// No description provided for @unitsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Units of measure'**
  String get unitsSectionTitle;

  /// No description provided for @unitsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add unit'**
  String get unitsAdd;

  /// No description provided for @unitsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No units yet'**
  String get unitsEmptyTitle;

  /// No description provided for @unitsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Piece, carton, kilogram — with a conversion factor for converting between units.'**
  String get unitsEmptyBody;

  /// No description provided for @unitFactorTimes.
  ///
  /// In en, this message translates to:
  /// **'× {factor}'**
  String unitFactorTimes(Object factor);

  /// No description provided for @partiesTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Parties'**
  String get partiesTabTitle;

  /// No description provided for @partiesHomeHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Parties management'**
  String get partiesHomeHeroTitle;

  /// No description provided for @partiesHomeHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customers and suppliers with their balances — each currency on its own, never mixed'**
  String get partiesHomeHeroSubtitle;

  /// No description provided for @partiesHubCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get partiesHubCustomers;

  /// No description provided for @partiesHubCustomersDesc.
  ///
  /// In en, this message translates to:
  /// **'Customer files, balances and account statements'**
  String get partiesHubCustomersDesc;

  /// No description provided for @partiesHubSuppliers.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get partiesHubSuppliers;

  /// No description provided for @partiesHubSuppliersDesc.
  ///
  /// In en, this message translates to:
  /// **'Supplier files and what you owe them'**
  String get partiesHubSuppliersDesc;

  /// No description provided for @partiesHubReceivables.
  ///
  /// In en, this message translates to:
  /// **'Outstanding at customers'**
  String get partiesHubReceivables;

  /// No description provided for @partiesHubReceivablesDesc.
  ///
  /// In en, this message translates to:
  /// **'Open receivables ordered by oldest invoice'**
  String get partiesHubReceivablesDesc;

  /// No description provided for @partiesHubPayables.
  ///
  /// In en, this message translates to:
  /// **'Outstanding to suppliers'**
  String get partiesHubPayables;

  /// No description provided for @partiesHubPayablesDesc.
  ///
  /// In en, this message translates to:
  /// **'Payables on the business, per currency'**
  String get partiesHubPayablesDesc;

  /// No description provided for @partiesHubRates.
  ///
  /// In en, this message translates to:
  /// **'Daily exchange rates'**
  String get partiesHubRates;

  /// No description provided for @partiesHubRatesDesc.
  ///
  /// In en, this message translates to:
  /// **'Update today\'s rates before issuing any non-base invoice'**
  String get partiesHubRatesDesc;

  /// No description provided for @partiesFxChipComplete.
  ///
  /// In en, this message translates to:
  /// **'Today\'s rates complete'**
  String get partiesFxChipComplete;

  /// No description provided for @partiesFxChipMissing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 currency without today\'s rate} other{{count} currencies without today\'s rate}}'**
  String partiesFxChipMissing(num count);

  /// No description provided for @partiesHomeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No parties yet'**
  String get partiesHomeEmptyTitle;

  /// No description provided for @partiesHomeEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Register your first customer or supplier to start tracking balances and statements per currency.'**
  String get partiesHomeEmptyBody;

  /// No description provided for @partiesHomeEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Register customer'**
  String get partiesHomeEmptyAction;

  /// No description provided for @partiesCountCustomers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No customers yet} one{1 customer} other{{count} customers}}'**
  String partiesCountCustomers(num count);

  /// No description provided for @partiesCountSuppliers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No suppliers yet} one{1 supplier} other{{count} suppliers}}'**
  String partiesCountSuppliers(num count);

  /// No description provided for @partiesDuesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No parties} one{1 party} other{{count} parties}}'**
  String partiesDuesCount(num count);

  /// No description provided for @partiesListCustomersTitle.
  ///
  /// In en, this message translates to:
  /// **'All customers'**
  String get partiesListCustomersTitle;

  /// No description provided for @partiesListSuppliersTitle.
  ///
  /// In en, this message translates to:
  /// **'All suppliers'**
  String get partiesListSuppliersTitle;

  /// No description provided for @partiesListSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or phone'**
  String get partiesListSearchHint;

  /// No description provided for @partiesListSearchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching results'**
  String get partiesListSearchEmptyTitle;

  /// No description provided for @partiesListSearchEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try another name or clear the search.'**
  String get partiesListSearchEmptyBody;

  /// No description provided for @partiesListEmptyCustomersTitle.
  ///
  /// In en, this message translates to:
  /// **'No customers yet'**
  String get partiesListEmptyCustomersTitle;

  /// No description provided for @partiesListEmptyCustomersBody.
  ///
  /// In en, this message translates to:
  /// **'Register your customers so the app tracks their balances and statements per currency.'**
  String get partiesListEmptyCustomersBody;

  /// No description provided for @partiesListEmptySuppliersTitle.
  ///
  /// In en, this message translates to:
  /// **'No suppliers yet'**
  String get partiesListEmptySuppliersTitle;

  /// No description provided for @partiesListEmptySuppliersBody.
  ///
  /// In en, this message translates to:
  /// **'Register your suppliers so the app tracks what you owe them per currency.'**
  String get partiesListEmptySuppliersBody;

  /// No description provided for @partiesListAddCustomersAction.
  ///
  /// In en, this message translates to:
  /// **'Register customer'**
  String get partiesListAddCustomersAction;

  /// No description provided for @partiesListAddSuppliersAction.
  ///
  /// In en, this message translates to:
  /// **'Register supplier'**
  String get partiesListAddSuppliersAction;

  /// No description provided for @partiesListAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get partiesListAddTooltip;

  /// No description provided for @partiesFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get partiesFilterAll;

  /// No description provided for @partiesFilterWithBalance.
  ///
  /// In en, this message translates to:
  /// **'With balances'**
  String get partiesFilterWithBalance;

  /// No description provided for @partiesFilterZeroBalance.
  ///
  /// In en, this message translates to:
  /// **'Zero balance'**
  String get partiesFilterZeroBalance;

  /// No description provided for @partiesFilterArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get partiesFilterArchived;

  /// No description provided for @partiesArchivedBadge.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get partiesArchivedBadge;

  /// No description provided for @partiesBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get partiesBalanceLabel;

  /// No description provided for @partiesBalanceOwed.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get partiesBalanceOwed;

  /// No description provided for @partiesBalanceCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get partiesBalanceCredit;

  /// No description provided for @partiesSwipeArchiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get partiesSwipeArchiveLabel;

  /// No description provided for @partiesArchiveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive {name}?'**
  String partiesArchiveConfirmTitle(Object name);

  /// No description provided for @partiesArchiveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'They will be excluded from new sales and purchases, while their history and balances remain in reports.'**
  String get partiesArchiveConfirmBody;

  /// No description provided for @partiesArchiveHasMovements.
  ///
  /// In en, this message translates to:
  /// **'{name} cannot be archived — they have recorded financial movements kept in their reports.'**
  String partiesArchiveHasMovements(Object name);

  /// No description provided for @partiesArchivedDone.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get partiesArchivedDone;

  /// No description provided for @partiesNoPhone.
  ///
  /// In en, this message translates to:
  /// **'No phone on file'**
  String get partiesNoPhone;

  /// No description provided for @partyFormAddCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'New customer'**
  String get partyFormAddCustomerTitle;

  /// No description provided for @partyFormEditCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit customer'**
  String get partyFormEditCustomerTitle;

  /// No description provided for @partyFormAddSupplierTitle.
  ///
  /// In en, this message translates to:
  /// **'New supplier'**
  String get partyFormAddSupplierTitle;

  /// No description provided for @partyFormEditSupplierTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit supplier'**
  String get partyFormEditSupplierTitle;

  /// No description provided for @partyFormNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get partyFormNameLabel;

  /// No description provided for @partyFormNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Abdullah Mohammed'**
  String get partyFormNameHint;

  /// No description provided for @partyFormNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required — enter it then save.'**
  String get partyFormNameRequired;

  /// No description provided for @partyFormPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get partyFormPhoneLabel;

  /// No description provided for @partyFormWhatsappLabel.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp number'**
  String get partyFormWhatsappLabel;

  /// No description provided for @partyFormWhatsappHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty if same as phone'**
  String get partyFormWhatsappHint;

  /// No description provided for @partyFormAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get partyFormAddressLabel;

  /// No description provided for @partyFormAreaLabel.
  ///
  /// In en, this message translates to:
  /// **'Neighborhood / area'**
  String get partyFormAreaLabel;

  /// No description provided for @partyFormCreditLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Credit limit'**
  String get partyFormCreditLimitLabel;

  /// No description provided for @partyFormCreditLimitHint.
  ///
  /// In en, this message translates to:
  /// **'Empty or a number'**
  String get partyFormCreditLimitHint;

  /// No description provided for @partyFormCreditLimitHelp.
  ///
  /// In en, this message translates to:
  /// **'Empty = no limit at all · Zero = credit sales forbidden · Number = maximum allowed debt'**
  String get partyFormCreditLimitHelp;

  /// No description provided for @partyFormCreditLimitInvalid.
  ///
  /// In en, this message translates to:
  /// **'Credit limit must be a number of zero or more — or leave it empty.'**
  String get partyFormCreditLimitInvalid;

  /// No description provided for @partyFormOpeningSection.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get partyFormOpeningSection;

  /// No description provided for @partyFormOpeningAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get partyFormOpeningAmountLabel;

  /// No description provided for @partyFormOpeningAmountHint.
  ///
  /// In en, this message translates to:
  /// **'0 if no prior balance'**
  String get partyFormOpeningAmountHint;

  /// No description provided for @partyFormOpeningAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Opening balance must be a positive number.'**
  String get partyFormOpeningAmountInvalid;

  /// No description provided for @partyFormOpeningCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get partyFormOpeningCurrencyLabel;

  /// No description provided for @partyFormOpeningCurrencyRequired.
  ///
  /// In en, this message translates to:
  /// **'A non-zero opening balance requires a currency.'**
  String get partyFormOpeningCurrencyRequired;

  /// No description provided for @partyFormOpeningCurrencyNone.
  ///
  /// In en, this message translates to:
  /// **'No currency — pick one for a non-zero amount'**
  String get partyFormOpeningCurrencyNone;

  /// No description provided for @partyFormOpeningDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance date'**
  String get partyFormOpeningDateLabel;

  /// No description provided for @partyFormOpeningLockedNote.
  ///
  /// In en, this message translates to:
  /// **'This party has financial movements — the opening balance is locked once any movement exists.'**
  String get partyFormOpeningLockedNote;

  /// No description provided for @partyFormNoRateError.
  ///
  /// In en, this message translates to:
  /// **'No exchange rate recorded for this currency — enter today\'s rate in «Exchange rates» first.'**
  String get partyFormNoRateError;

  /// No description provided for @partyFormNoUserError.
  ///
  /// In en, this message translates to:
  /// **'Could not save — no active admin user in the database.'**
  String get partyFormNoUserError;

  /// No description provided for @partyFormNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get partyFormNotesLabel;

  /// No description provided for @partyFormNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Internal notes, never printed on invoices'**
  String get partyFormNotesHint;

  /// No description provided for @partyFormSaveLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get partyFormSaveLabel;

  /// No description provided for @partyFormSavedCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer saved'**
  String get partyFormSavedCustomer;

  /// No description provided for @partyFormSavedSupplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier saved'**
  String get partyFormSavedSupplier;

  /// No description provided for @partiesCreditLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Credit limit'**
  String get partiesCreditLimitLabel;

  /// No description provided for @partiesCreditUnlimited.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get partiesCreditUnlimited;

  /// No description provided for @partiesCreditForbidden.
  ///
  /// In en, this message translates to:
  /// **'No credit'**
  String get partiesCreditForbidden;

  /// No description provided for @partiesCreditLimitValue.
  ///
  /// In en, this message translates to:
  /// **'Limit {amount}'**
  String partiesCreditLimitValue(Object amount);

  /// No description provided for @partyDetailInfoSection.
  ///
  /// In en, this message translates to:
  /// **'Party details'**
  String get partyDetailInfoSection;

  /// No description provided for @partyDetailBalancesSection.
  ///
  /// In en, this message translates to:
  /// **'Balances by currency'**
  String get partyDetailBalancesSection;

  /// No description provided for @partyDetailBalancesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No balances yet — appears with the first credit invoice or voucher.'**
  String get partyDetailBalancesEmpty;

  /// No description provided for @partyDetailStatementSection.
  ///
  /// In en, this message translates to:
  /// **'Account statement'**
  String get partyDetailStatementSection;

  /// No description provided for @partyDetailStatementCurrency.
  ///
  /// In en, this message translates to:
  /// **'Statement currency'**
  String get partyDetailStatementCurrency;

  /// No description provided for @partyDetailStatementFrom.
  ///
  /// In en, this message translates to:
  /// **'From date'**
  String get partyDetailStatementFrom;

  /// No description provided for @partyDetailStatementTo.
  ///
  /// In en, this message translates to:
  /// **'To date'**
  String get partyDetailStatementTo;

  /// No description provided for @partyDetailPeriodAll.
  ///
  /// In en, this message translates to:
  /// **'All periods'**
  String get partyDetailPeriodAll;

  /// No description provided for @partyDetailPeriodThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get partyDetailPeriodThisMonth;

  /// No description provided for @partyDetailPeriodThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get partyDetailPeriodThisYear;

  /// No description provided for @partyDetailFinalBalance.
  ///
  /// In en, this message translates to:
  /// **'Final balance'**
  String get partyDetailFinalBalance;

  /// No description provided for @partyDetailCarryInBalance.
  ///
  /// In en, this message translates to:
  /// **'Prior balance at period start'**
  String get partyDetailCarryInBalance;

  /// No description provided for @partyDetailNoEntries.
  ///
  /// In en, this message translates to:
  /// **'No entries in this currency for the selected period.'**
  String get partyDetailNoEntries;

  /// No description provided for @partyDetailNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Party not found'**
  String get partyDetailNotFoundTitle;

  /// No description provided for @partyDetailEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get partyDetailEditAction;

  /// No description provided for @partyDetailNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'The id may be wrong or the record missing.'**
  String get partyDetailNotFoundBody;

  /// No description provided for @partyDetailArchivedBanner.
  ///
  /// In en, this message translates to:
  /// **'Archived party — shown for reports only, not used in new operations.'**
  String get partyDetailArchivedBanner;

  /// No description provided for @partyDetailOpeningRow.
  ///
  /// In en, this message translates to:
  /// **'Opening balance recorded on {date}'**
  String partyDetailOpeningRow(Object date);

  /// No description provided for @partyDetailNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get partyDetailNotesLabel;

  /// No description provided for @statementKindInvoice.
  ///
  /// In en, this message translates to:
  /// **'Sales invoice'**
  String get statementKindInvoice;

  /// No description provided for @statementKindReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt voucher'**
  String get statementKindReceipt;

  /// No description provided for @statementKindSaleReturn.
  ///
  /// In en, this message translates to:
  /// **'Sales return'**
  String get statementKindSaleReturn;

  /// No description provided for @statementKindPurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase invoice'**
  String get statementKindPurchase;

  /// No description provided for @statementKindPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment voucher'**
  String get statementKindPayment;

  /// No description provided for @statementKindPurchaseReturn.
  ///
  /// In en, this message translates to:
  /// **'Purchase return'**
  String get statementKindPurchaseReturn;

  /// No description provided for @statementKindOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get statementKindOpening;

  /// No description provided for @statementKindCarryIn.
  ///
  /// In en, this message translates to:
  /// **'Prior balance'**
  String get statementKindCarryIn;

  /// No description provided for @statementBalanceColumn.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get statementBalanceColumn;

  /// No description provided for @statementAmountColumn.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get statementAmountColumn;

  /// No description provided for @receivablesTitle.
  ///
  /// In en, this message translates to:
  /// **'Outstanding at customers'**
  String get receivablesTitle;

  /// No description provided for @payablesTitle.
  ///
  /// In en, this message translates to:
  /// **'Outstanding to suppliers'**
  String get payablesTitle;

  /// No description provided for @receivablesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing outstanding'**
  String get receivablesEmptyTitle;

  /// No description provided for @receivablesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No open receivables on any customer right now.'**
  String get receivablesEmptyBody;

  /// No description provided for @payablesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No open payables to any supplier right now.'**
  String get payablesEmptyBody;

  /// No description provided for @partiesBalancesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or phone'**
  String get partiesBalancesSearchHint;

  /// No description provided for @partiesBalancesSearchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching results'**
  String get partiesBalancesSearchEmptyTitle;

  /// No description provided for @partiesBalancesSearchEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try another name or clear the search.'**
  String get partiesBalancesSearchEmptyBody;

  /// No description provided for @partiesBalancesTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total due'**
  String get partiesBalancesTotalLabel;

  /// No description provided for @partiesDaysLateChip.
  ///
  /// In en, this message translates to:
  /// **'Late by {count, plural, one{1 day} other{{count} days}}'**
  String partiesDaysLateChip(num count);

  /// No description provided for @partiesLastPaymentLabel.
  ///
  /// In en, this message translates to:
  /// **'Last payment {date}'**
  String partiesLastPaymentLabel(Object date);

  /// No description provided for @partiesNoMixNote.
  ///
  /// In en, this message translates to:
  /// **'Every balance is held in its own currency — a party with balances in two currencies appears as two separate rows, never summed.'**
  String get partiesNoMixNote;

  /// No description provided for @fxRatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily exchange rates'**
  String get fxRatesTitle;

  /// No description provided for @fxTodayCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s rates'**
  String get fxTodayCardTitle;

  /// No description provided for @fxTodayHijriDate.
  ///
  /// In en, this message translates to:
  /// **'Rates for {date}'**
  String fxTodayHijriDate(Object date);

  /// No description provided for @fxBaseNote.
  ///
  /// In en, this message translates to:
  /// **'Base currency {code} — always 1, never entered.'**
  String fxBaseNote(Object code);

  /// No description provided for @fxAgainstBase.
  ///
  /// In en, this message translates to:
  /// **'per {code}'**
  String fxAgainstBase(Object code);

  /// No description provided for @fxRateFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Today\'s rate'**
  String get fxRateFieldLabel;

  /// No description provided for @fxLastKnownRate.
  ///
  /// In en, this message translates to:
  /// **'Last known rate: {rate} on {date}'**
  String fxLastKnownRate(Object date, Object rate);

  /// No description provided for @fxNoRateYet.
  ///
  /// In en, this message translates to:
  /// **'No rate recorded for this currency yet'**
  String get fxNoRateYet;

  /// No description provided for @fxEnteredToday.
  ///
  /// In en, this message translates to:
  /// **'Entered today'**
  String get fxEnteredToday;

  /// No description provided for @fxMissingToday.
  ///
  /// In en, this message translates to:
  /// **'Missing today'**
  String get fxMissingToday;

  /// No description provided for @fxSaveLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get fxSaveLabel;

  /// No description provided for @fxSavingLabel.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get fxSavingLabel;

  /// No description provided for @fxRateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number greater than zero.'**
  String get fxRateInvalid;

  /// No description provided for @fxRateSaved.
  ///
  /// In en, this message translates to:
  /// **'Today\'s rate saved for {code}'**
  String fxRateSaved(Object code);

  /// No description provided for @fxHistorySection.
  ///
  /// In en, this message translates to:
  /// **'Recent rates'**
  String get fxHistorySection;

  /// No description provided for @fxHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No rates recorded for this currency yet.'**
  String get fxHistoryEmpty;

  /// No description provided for @fxShowHistory.
  ///
  /// In en, this message translates to:
  /// **'Show history'**
  String get fxShowHistory;

  /// No description provided for @fxHideHistory.
  ///
  /// In en, this message translates to:
  /// **'Hide history'**
  String get fxHideHistory;

  /// No description provided for @fxAllComplete.
  ///
  /// In en, this message translates to:
  /// **'Today\'s rates are complete for all currencies'**
  String get fxAllComplete;

  /// No description provided for @fxMissingWarning.
  ///
  /// In en, this message translates to:
  /// **'Today\'s entry is incomplete — non-base invoices require a rate recorded for the day'**
  String get fxMissingWarning;

  /// No description provided for @sellScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'New sale invoice'**
  String get sellScreenTitle;

  /// No description provided for @sellNewInvoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'New invoice'**
  String get sellNewInvoiceLabel;

  /// No description provided for @sellClearCartTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear cart'**
  String get sellClearCartTooltip;

  /// No description provided for @sellClearCartTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the cart?'**
  String get sellClearCartTitle;

  /// No description provided for @sellClearCartBody.
  ///
  /// In en, this message translates to:
  /// **'All current cart lines will be removed and cannot be recovered.'**
  String get sellClearCartBody;

  /// No description provided for @sellEmptyCartTitle.
  ///
  /// In en, this message translates to:
  /// **'The cart is empty'**
  String get sellEmptyCartTitle;

  /// No description provided for @sellEmptyCartBody.
  ///
  /// In en, this message translates to:
  /// **'Add the first item by search or barcode scan to start the invoice.'**
  String get sellEmptyCartBody;

  /// No description provided for @sellAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get sellAddItem;

  /// No description provided for @sellBarcodeHint.
  ///
  /// In en, this message translates to:
  /// **'Scan or type the barcode then press Enter'**
  String get sellBarcodeHint;

  /// No description provided for @sellPickCustomer.
  ///
  /// In en, this message translates to:
  /// **'Choose customer'**
  String get sellPickCustomer;

  /// No description provided for @sellCashCustomer.
  ///
  /// In en, this message translates to:
  /// **'Walk-in customer'**
  String get sellCashCustomer;

  /// No description provided for @sellCashCustomerHint.
  ///
  /// In en, this message translates to:
  /// **'Immediate sale with no account — full cash payment'**
  String get sellCashCustomerHint;

  /// No description provided for @sellCurrencyBaseTag.
  ///
  /// In en, this message translates to:
  /// **'base'**
  String get sellCurrencyBaseTag;

  /// No description provided for @sellCurrencyNoRate.
  ///
  /// In en, this message translates to:
  /// **'no rate today'**
  String get sellCurrencyNoRate;

  /// No description provided for @sellLineAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available: {qty}'**
  String sellLineAvailable(Object qty);

  /// No description provided for @sellLineOverAvailable.
  ///
  /// In en, this message translates to:
  /// **'Quantity exceeds available ({qty})'**
  String sellLineOverAvailable(Object qty);

  /// No description provided for @sellLineTotal.
  ///
  /// In en, this message translates to:
  /// **'Line total'**
  String get sellLineTotal;

  /// No description provided for @sellUnitPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get sellUnitPriceLabel;

  /// No description provided for @sellEditPriceTitle.
  ///
  /// In en, this message translates to:
  /// **'Unit price: {name}'**
  String sellEditPriceTitle(Object name);

  /// No description provided for @sellLineDiscountTitle.
  ///
  /// In en, this message translates to:
  /// **'Line discount: {name}'**
  String sellLineDiscountTitle(Object name);

  /// No description provided for @sellLineDiscountNone.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get sellLineDiscountNone;

  /// No description provided for @sellLineDiscountPercent.
  ///
  /// In en, this message translates to:
  /// **'{value}% off'**
  String sellLineDiscountPercent(Object value);

  /// No description provided for @sellLineDiscountAmount.
  ///
  /// In en, this message translates to:
  /// **'{value} off'**
  String sellLineDiscountAmount(Object value);

  /// No description provided for @sellInvoiceDiscountTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice-level discount'**
  String get sellInvoiceDiscountTitle;

  /// No description provided for @sellInvoiceDiscountButton.
  ///
  /// In en, this message translates to:
  /// **'Invoice discount'**
  String get sellInvoiceDiscountButton;

  /// No description provided for @sellInvoiceDiscountPercent.
  ///
  /// In en, this message translates to:
  /// **'{value}% off'**
  String sellInvoiceDiscountPercent(Object value);

  /// No description provided for @sellInvoiceDiscountAmount.
  ///
  /// In en, this message translates to:
  /// **'{value} off'**
  String sellInvoiceDiscountAmount(Object value);

  /// No description provided for @sellDiscountAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get sellDiscountAmount;

  /// No description provided for @sellDiscountPercent.
  ///
  /// In en, this message translates to:
  /// **'Percent %'**
  String get sellDiscountPercent;

  /// No description provided for @sellDiscountAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Discount value as an amount'**
  String get sellDiscountAmountHint;

  /// No description provided for @sellDiscountPercentHint.
  ///
  /// In en, this message translates to:
  /// **'Discount percent from 0 to 100'**
  String get sellDiscountPercentHint;

  /// No description provided for @sellDiscountAmountError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid discount amount (≥ 0).'**
  String get sellDiscountAmountError;

  /// No description provided for @sellDiscountPercentError.
  ///
  /// In en, this message translates to:
  /// **'The percent must be between 0 and 100.'**
  String get sellDiscountPercentError;

  /// No description provided for @sellDiscountApply.
  ///
  /// In en, this message translates to:
  /// **'Apply discount'**
  String get sellDiscountApply;

  /// No description provided for @sellInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number.'**
  String get sellInvalidNumber;

  /// No description provided for @sellTotalsSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get sellTotalsSubtotal;

  /// No description provided for @sellTotalsLineDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Line discounts'**
  String get sellTotalsLineDiscounts;

  /// No description provided for @sellTotalsInvoiceDiscount.
  ///
  /// In en, this message translates to:
  /// **'Invoice discount'**
  String get sellTotalsInvoiceDiscount;

  /// No description provided for @sellTotalsGrandTotal.
  ///
  /// In en, this message translates to:
  /// **'Net total'**
  String get sellTotalsGrandTotal;

  /// No description provided for @sellPayButton.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get sellPayButton;

  /// No description provided for @sellPayButtonWithTotal.
  ///
  /// In en, this message translates to:
  /// **'Pay · {total}'**
  String sellPayButtonWithTotal(Object total);

  /// No description provided for @sellSaveQuotation.
  ///
  /// In en, this message translates to:
  /// **'Quotation'**
  String get sellSaveQuotation;

  /// No description provided for @sellQuotationSaved.
  ///
  /// In en, this message translates to:
  /// **'Quotation {no} saved'**
  String sellQuotationSaved(Object no);

  /// No description provided for @sellQuotationSavedOpen.
  ///
  /// In en, this message translates to:
  /// **'Quotations'**
  String get sellQuotationSavedOpen;

  /// No description provided for @sellFxGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s rate for {code}'**
  String sellFxGateTitle(Object code);

  /// No description provided for @sellFxGateBody.
  ///
  /// In en, this message translates to:
  /// **'No document is ever saved with a default rate — enter today\'s rate for this currency, then continue to payment.'**
  String get sellFxGateBody;

  /// No description provided for @sellFxGateFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Today\'s rate'**
  String get sellFxGateFieldLabel;

  /// No description provided for @sellFxGateFieldHelper.
  ///
  /// In en, this message translates to:
  /// **'Value of one unit against the base currency'**
  String get sellFxGateFieldHelper;

  /// No description provided for @sellFxGateSave.
  ///
  /// In en, this message translates to:
  /// **'Save and continue'**
  String get sellFxGateSave;

  /// No description provided for @sellFxSavedAndResumed.
  ///
  /// In en, this message translates to:
  /// **'Today\'s rate saved — you can complete the payment now.'**
  String get sellFxSavedAndResumed;

  /// No description provided for @sellPayMethodCash.
  ///
  /// In en, this message translates to:
  /// **'Full cash'**
  String get sellPayMethodCash;

  /// No description provided for @sellPayMethodCredit.
  ///
  /// In en, this message translates to:
  /// **'Full credit'**
  String get sellPayMethodCredit;

  /// No description provided for @sellPayMethodMixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get sellPayMethodMixed;

  /// No description provided for @sellPayNetTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Net total due'**
  String get sellPayNetTotalLabel;

  /// No description provided for @sellPayWalkInCustomer.
  ///
  /// In en, this message translates to:
  /// **'Walk-in customer'**
  String get sellPayWalkInCustomer;

  /// No description provided for @sellPayCashFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Cash received'**
  String get sellPayCashFieldLabel;

  /// No description provided for @sellPayCashFieldHelper.
  ///
  /// In en, this message translates to:
  /// **'May exceed the net — the difference is change due'**
  String get sellPayCashFieldHelper;

  /// No description provided for @sellPayNetPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid in cash'**
  String get sellPayNetPaid;

  /// No description provided for @sellPaySettledFully.
  ///
  /// In en, this message translates to:
  /// **'Fully settled'**
  String get sellPaySettledFully;

  /// No description provided for @sellPayInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount.'**
  String get sellPayInvalidAmount;

  /// No description provided for @sellPayCashShort.
  ///
  /// In en, this message translates to:
  /// **'Cash is below the net total ({total}) — choose mixed or credit.'**
  String sellPayCashShort(Object total);

  /// No description provided for @sellPayCreditNeedsCustomer.
  ///
  /// In en, this message translates to:
  /// **'Credit sales require selecting a customer first — walk-in pays in full cash.'**
  String get sellPayCreditNeedsCustomer;

  /// No description provided for @sellPayMixedRange.
  ///
  /// In en, this message translates to:
  /// **'For mixed payment enter an amount strictly between zero and the net total ({total}).'**
  String sellPayMixedRange(Object total);

  /// No description provided for @sellPayAnonymousCashOnly.
  ///
  /// In en, this message translates to:
  /// **'Anonymous walk-in customers can only pay the full amount in cash.'**
  String get sellPayAnonymousCashOnly;

  /// No description provided for @sellPayConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm posting'**
  String get sellPayConfirm;

  /// No description provided for @sellReceiptSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice posted'**
  String get sellReceiptSuccessTitle;

  /// No description provided for @sellReceiptTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get sellReceiptTotal;

  /// No description provided for @sellReceiptPaidCash.
  ///
  /// In en, this message translates to:
  /// **'Paid in cash'**
  String get sellReceiptPaidCash;

  /// No description provided for @sellReceiptChangeDue.
  ///
  /// In en, this message translates to:
  /// **'Change due to customer'**
  String get sellReceiptChangeDue;

  /// No description provided for @sellReceiptRemainingCredit.
  ///
  /// In en, this message translates to:
  /// **'Remaining on credit'**
  String get sellReceiptRemainingCredit;

  /// No description provided for @sellReceiptNewInvoice.
  ///
  /// In en, this message translates to:
  /// **'New invoice'**
  String get sellReceiptNewInvoice;

  /// No description provided for @sellFallbackRateBadge.
  ///
  /// In en, this message translates to:
  /// **'Estimated exchange rate'**
  String get sellFallbackRateBadge;

  /// No description provided for @sellPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an item'**
  String get sellPickerTitle;

  /// No description provided for @sellPickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or barcode'**
  String get sellPickerSearchHint;

  /// No description provided for @sellPickerBarcodeNotFound.
  ///
  /// In en, this message translates to:
  /// **'No item with barcode “{code}”'**
  String sellPickerBarcodeNotFound(Object code);

  /// No description provided for @sellPickerDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get sellPickerDone;

  /// No description provided for @sellPickerEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No items yet'**
  String get sellPickerEmptyTitle;

  /// No description provided for @sellPickerEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add your items in the inventory module, then sell them here.'**
  String get sellPickerEmptyBody;

  /// No description provided for @sellPickerNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching results'**
  String get sellPickerNoResultsTitle;

  /// No description provided for @sellPickerNoResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Try another name or barcode.'**
  String get sellPickerNoResultsBody;

  /// No description provided for @sellPickerOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get sellPickerOutOfStock;

  /// No description provided for @sellPickerAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available: {qty}'**
  String sellPickerAvailable(Object qty);

  /// No description provided for @sellCustomerPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice customer'**
  String get sellCustomerPickerTitle;

  /// No description provided for @sellCustomerPickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or phone'**
  String get sellCustomerPickerSearchHint;

  /// No description provided for @sellCustomerPickerEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No customers yet'**
  String get sellCustomerPickerEmptyTitle;

  /// No description provided for @sellCustomerPickerEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Register customers in the parties module to sell to them on credit.'**
  String get sellCustomerPickerEmptyBody;

  /// No description provided for @sellCustomerPickerNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching results'**
  String get sellCustomerPickerNoResultsTitle;

  /// No description provided for @sellCustomerPickerNoResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Try another name or phone.'**
  String get sellCustomerPickerNoResultsBody;

  /// No description provided for @sellCustomerPickerFooterNote.
  ///
  /// In en, this message translates to:
  /// **'Balances are shown per currency and never mixed'**
  String get sellCustomerPickerFooterNote;

  /// No description provided for @sellCustomerOwes.
  ///
  /// In en, this message translates to:
  /// **'owes'**
  String get sellCustomerOwes;

  /// No description provided for @sellCustomerCredit.
  ///
  /// In en, this message translates to:
  /// **'credit balance'**
  String get sellCustomerCredit;

  /// No description provided for @sellCustomerClear.
  ///
  /// In en, this message translates to:
  /// **'no balance'**
  String get sellCustomerClear;

  /// No description provided for @sellHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get sellHomeTitle;

  /// No description provided for @sellHomeHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Point of sale'**
  String get sellHomeHeroTitle;

  /// No description provided for @sellHomeTodaySales.
  ///
  /// In en, this message translates to:
  /// **'Today\'s sales'**
  String get sellHomeTodaySales;

  /// No description provided for @sellHomeTodayCash.
  ///
  /// In en, this message translates to:
  /// **'Today\'s net cash'**
  String get sellHomeTodayCash;

  /// No description provided for @sellHomeNewInvoice.
  ///
  /// In en, this message translates to:
  /// **'New sale invoice'**
  String get sellHomeNewInvoice;

  /// No description provided for @sellHomeNewInvoiceHint.
  ///
  /// In en, this message translates to:
  /// **'Start selling instantly — search, scan, discounts and payment'**
  String get sellHomeNewInvoiceHint;

  /// No description provided for @sellHomeRecentInvoices.
  ///
  /// In en, this message translates to:
  /// **'Recent invoices'**
  String get sellHomeRecentInvoices;

  /// No description provided for @sellInvoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales invoices'**
  String get sellInvoicesTitle;

  /// No description provided for @sellInvoicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Record of posted invoices'**
  String get sellInvoicesSubtitle;

  /// No description provided for @sellInvoicesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by invoice number or customer'**
  String get sellInvoicesSearchHint;

  /// No description provided for @sellInvoicesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No invoices yet'**
  String get sellInvoicesEmptyTitle;

  /// No description provided for @sellInvoicesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Post your first sale invoice to see it here with its lines and payment status.'**
  String get sellInvoicesEmptyBody;

  /// No description provided for @sellInvoicesNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching results'**
  String get sellInvoicesNoResultsTitle;

  /// No description provided for @sellInvoicesNoResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Try another number or name.'**
  String get sellInvoicesNoResultsBody;

  /// No description provided for @sellInvoicesPaidLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get sellInvoicesPaidLabel;

  /// No description provided for @sellInvoicesDueLabel.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get sellInvoicesDueLabel;

  /// No description provided for @sellInvoicesTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get sellInvoicesTotalLabel;

  /// No description provided for @sellInvoiceDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice details'**
  String get sellInvoiceDetailTitle;

  /// No description provided for @sellInvoiceNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice not found'**
  String get sellInvoiceNotFoundTitle;

  /// No description provided for @sellInvoiceNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'It may have been removed, or the link is incorrect.'**
  String get sellInvoiceNotFoundBody;

  /// No description provided for @sellDetailCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get sellDetailCustomer;

  /// No description provided for @sellDetailPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get sellDetailPhone;

  /// No description provided for @sellDetailCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get sellDetailCurrency;

  /// No description provided for @sellDetailExchangeRate.
  ///
  /// In en, this message translates to:
  /// **'Applied exchange rate'**
  String get sellDetailExchangeRate;

  /// No description provided for @sellDetailItemsSection.
  ///
  /// In en, this message translates to:
  /// **'Invoice lines'**
  String get sellDetailItemsSection;

  /// No description provided for @sellDetailUnknownItem.
  ///
  /// In en, this message translates to:
  /// **'Removed item'**
  String get sellDetailUnknownItem;

  /// No description provided for @sellDetailQtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get sellDetailQtyLabel;

  /// No description provided for @sellDetailDiscountLabel.
  ///
  /// In en, this message translates to:
  /// **'discount'**
  String get sellDetailDiscountLabel;

  /// No description provided for @sellDetailTotalDiscount.
  ///
  /// In en, this message translates to:
  /// **'Total discount'**
  String get sellDetailTotalDiscount;

  /// No description provided for @sellQuotationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quotations'**
  String get sellQuotationsTitle;

  /// No description provided for @sellQuotationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quotes convertible to invoices'**
  String get sellQuotationsSubtitle;

  /// No description provided for @sellQuotationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No quotations yet'**
  String get sellQuotationsEmptyTitle;

  /// No description provided for @sellQuotationsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Save the sale cart as a quotation to review it later before posting.'**
  String get sellQuotationsEmptyBody;

  /// No description provided for @sellQuotationFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get sellQuotationFilterAll;

  /// No description provided for @sellQuotationStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get sellQuotationStatusDraft;

  /// No description provided for @sellQuotationStatusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sellQuotationStatusSent;

  /// No description provided for @sellQuotationStatusConverted.
  ///
  /// In en, this message translates to:
  /// **'Converted'**
  String get sellQuotationStatusConverted;

  /// No description provided for @sellQuotationStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get sellQuotationStatusExpired;

  /// No description provided for @sellQuotationStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get sellQuotationStatusCancelled;

  /// No description provided for @sellQuotationValidUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String sellQuotationValidUntil(Object date);

  /// No description provided for @sellQuotationValidUntilLabel.
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get sellQuotationValidUntilLabel;

  /// No description provided for @sellQuotationMarkSent.
  ///
  /// In en, this message translates to:
  /// **'Mark sent'**
  String get sellQuotationMarkSent;

  /// No description provided for @sellQuotationCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get sellQuotationCancel;

  /// No description provided for @sellQuotationCancelConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this quotation?'**
  String get sellQuotationCancelConfirmTitle;

  /// No description provided for @sellQuotationCancelConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Quotation {no} will be cancelled and can no longer be converted to an invoice.'**
  String sellQuotationCancelConfirmBody(Object no);

  /// No description provided for @sellQuotationConvertedTo.
  ///
  /// In en, this message translates to:
  /// **'Converted to invoice #{id}'**
  String sellQuotationConvertedTo(Object id);

  /// No description provided for @sellQuotationDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Quotation details'**
  String get sellQuotationDetailTitle;

  /// No description provided for @sellQuotationNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Quotation not found'**
  String get sellQuotationNotFoundTitle;

  /// No description provided for @sellQuotationNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'It may have been cancelled, or the link is incorrect.'**
  String get sellQuotationNotFoundBody;

  /// No description provided for @sellQuotationRateLabel.
  ///
  /// In en, this message translates to:
  /// **'rate at creation'**
  String get sellQuotationRateLabel;

  /// No description provided for @sellQuotationNetTotal.
  ///
  /// In en, this message translates to:
  /// **'Quotation net'**
  String get sellQuotationNetTotal;

  /// No description provided for @sellQuotationPrintedNotes.
  ///
  /// In en, this message translates to:
  /// **'Printed note'**
  String get sellQuotationPrintedNotes;

  /// No description provided for @sellQuotationConvertButton.
  ///
  /// In en, this message translates to:
  /// **'Convert to invoice'**
  String get sellQuotationConvertButton;

  /// No description provided for @sellQuotationConvertedMessage.
  ///
  /// In en, this message translates to:
  /// **'The quotation was converted into a posted invoice successfully.'**
  String get sellQuotationConvertedMessage;

  /// No description provided for @sellQuotationSentMessage.
  ///
  /// In en, this message translates to:
  /// **'The quotation was marked as sent.'**
  String get sellQuotationSentMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
