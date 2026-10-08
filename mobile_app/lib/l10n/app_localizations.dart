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

  /// No description provided for @purHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get purHomeTitle;

  /// No description provided for @purHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Buy, return, and WAC engine'**
  String get purHubSubtitle;

  /// No description provided for @purHomeHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchasing & intake'**
  String get purHomeHeroTitle;

  /// No description provided for @purHomeTodayCount.
  ///
  /// In en, this message translates to:
  /// **'Today\'s purchase invoices'**
  String get purHomeTodayCount;

  /// No description provided for @purHomeTodayTotal.
  ///
  /// In en, this message translates to:
  /// **'Today\'s purchases value'**
  String get purHomeTodayTotal;

  /// No description provided for @purHomeNewInvoice.
  ///
  /// In en, this message translates to:
  /// **'New purchase invoice'**
  String get purHomeNewInvoice;

  /// No description provided for @purHomeNewInvoiceHint.
  ///
  /// In en, this message translates to:
  /// **'Enter stock at cost with batch expiry — posting updates the average cost'**
  String get purHomeNewInvoiceHint;

  /// No description provided for @purHomeRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent purchases'**
  String get purHomeRecent;

  /// No description provided for @purInvoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase invoices'**
  String get purInvoicesTitle;

  /// No description provided for @purInvoicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Posted PUR register'**
  String get purInvoicesSubtitle;

  /// No description provided for @purInvoicesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by number or supplier'**
  String get purInvoicesSearchHint;

  /// No description provided for @purInvoicesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No purchases yet'**
  String get purInvoicesEmptyTitle;

  /// No description provided for @purInvoicesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Post your first purchase invoice to add stock and update costs.'**
  String get purInvoicesEmptyBody;

  /// No description provided for @purInvoicesNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get purInvoicesNoResultsTitle;

  /// No description provided for @purInvoicesNoResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Try another number or supplier name.'**
  String get purInvoicesNoResultsBody;

  /// No description provided for @purInvoicesPaidLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get purInvoicesPaidLabel;

  /// No description provided for @purInvoicesDueLabel.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get purInvoicesDueLabel;

  /// No description provided for @purInvoicesTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get purInvoicesTotalLabel;

  /// No description provided for @purDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase invoice details'**
  String get purDetailTitle;

  /// No description provided for @purDetailNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice not found'**
  String get purDetailNotFoundTitle;

  /// No description provided for @purDetailNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'It may have been removed or the link is wrong.'**
  String get purDetailNotFoundBody;

  /// No description provided for @purDetailSupplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get purDetailSupplier;

  /// No description provided for @purDetailStockValue.
  ///
  /// In en, this message translates to:
  /// **'Intake value at cost'**
  String get purDetailStockValue;

  /// No description provided for @purDetailStockValueNote.
  ///
  /// In en, this message translates to:
  /// **'In base currency — the weighted-average cost basis'**
  String get purDetailStockValueNote;

  /// No description provided for @purDetailReturnAction.
  ///
  /// In en, this message translates to:
  /// **'Return to supplier (purchase return)'**
  String get purDetailReturnAction;

  /// No description provided for @purSupplierRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a supplier'**
  String get purSupplierRequired;

  /// No description provided for @purSupplierOwes.
  ///
  /// In en, this message translates to:
  /// **'We owe'**
  String get purSupplierOwes;

  /// No description provided for @purSupplierCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit with us'**
  String get purSupplierCredit;

  /// No description provided for @purSupplierPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice supplier'**
  String get purSupplierPickerTitle;

  /// No description provided for @purSupplierPickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or phone'**
  String get purSupplierPickerSearchHint;

  /// No description provided for @purSupplierPickerEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No suppliers yet'**
  String get purSupplierPickerEmptyTitle;

  /// No description provided for @purSupplierPickerEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Register suppliers in the parties module to buy from them.'**
  String get purSupplierPickerEmptyBody;

  /// No description provided for @purSupplierPickerNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get purSupplierPickerNoResultsTitle;

  /// No description provided for @purSupplierPickerNoResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Try another name or phone.'**
  String get purSupplierPickerNoResultsBody;

  /// No description provided for @purScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'New purchase invoice'**
  String get purScreenTitle;

  /// No description provided for @purNewInvoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Next PUR number'**
  String get purNewInvoiceLabel;

  /// No description provided for @purPickSupplier.
  ///
  /// In en, this message translates to:
  /// **'Select supplier'**
  String get purPickSupplier;

  /// No description provided for @purClearCartTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear invoice'**
  String get purClearCartTooltip;

  /// No description provided for @purClearCartTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the purchase invoice?'**
  String get purClearCartTitle;

  /// No description provided for @purClearCartBody.
  ///
  /// In en, this message translates to:
  /// **'Unposted lines will be removed — nothing is written to the database.'**
  String get purClearCartBody;

  /// No description provided for @purEmptyCartTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice is empty'**
  String get purEmptyCartTitle;

  /// No description provided for @purEmptyCartBody.
  ///
  /// In en, this message translates to:
  /// **'Add intake items at purchase cost — batches are created per tracked line with its expiry.'**
  String get purEmptyCartBody;

  /// No description provided for @purAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get purAddItem;

  /// No description provided for @purLineStock.
  ///
  /// In en, this message translates to:
  /// **'In stock now: {qty}'**
  String purLineStock(Object qty);

  /// No description provided for @purUnitCostLabel.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get purUnitCostLabel;

  /// No description provided for @purEditCostTitle.
  ///
  /// In en, this message translates to:
  /// **'Unit cost: {name}'**
  String purEditCostTitle(Object name);

  /// No description provided for @purIncomingBatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Incoming batch'**
  String get purIncomingBatchTitle;

  /// No description provided for @purBatchNoHint.
  ///
  /// In en, this message translates to:
  /// **'Supplier batch number'**
  String get purBatchNoHint;

  /// No description provided for @purExpiryPick.
  ///
  /// In en, this message translates to:
  /// **'Pick expiry date'**
  String get purExpiryPick;

  /// No description provided for @purExpiryValue.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String purExpiryValue(Object date);

  /// No description provided for @purExpiryQuickMonth.
  ///
  /// In en, this message translates to:
  /// **'+30 days'**
  String get purExpiryQuickMonth;

  /// No description provided for @purExpiryQuick3Months.
  ///
  /// In en, this message translates to:
  /// **'+90 days'**
  String get purExpiryQuick3Months;

  /// No description provided for @purExpiryQuick6Months.
  ///
  /// In en, this message translates to:
  /// **'+180 days'**
  String get purExpiryQuick6Months;

  /// No description provided for @purExpiryQuickYear.
  ///
  /// In en, this message translates to:
  /// **'+1 year'**
  String get purExpiryQuickYear;

  /// No description provided for @purExpiryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Expiry date'**
  String get purExpiryDialogTitle;

  /// No description provided for @purInvoiceDiscountButton.
  ///
  /// In en, this message translates to:
  /// **'Invoice discount'**
  String get purInvoiceDiscountButton;

  /// No description provided for @purInvoiceDiscountTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase invoice discount'**
  String get purInvoiceDiscountTitle;

  /// No description provided for @purPayButton.
  ///
  /// In en, this message translates to:
  /// **'Post purchase'**
  String get purPayButton;

  /// No description provided for @purPayButtonWithTotal.
  ///
  /// In en, this message translates to:
  /// **'Pay · {total}'**
  String purPayButtonWithTotal(Object total);

  /// No description provided for @purPayCashFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Cash paid to supplier'**
  String get purPayCashFieldLabel;

  /// No description provided for @purPayCashFieldHelper.
  ///
  /// In en, this message translates to:
  /// **'Leaves the cashbox — never above the net'**
  String get purPayCashFieldHelper;

  /// No description provided for @purPayCashShort.
  ///
  /// In en, this message translates to:
  /// **'Cash is below the net ({total}) — choose mixed or credit.'**
  String purPayCashShort(Object total);

  /// No description provided for @purPayMixedRange.
  ///
  /// In en, this message translates to:
  /// **'In mixed payment enter an amount strictly between zero and the net ({total}).'**
  String purPayMixedRange(Object total);

  /// No description provided for @purPayConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm posting'**
  String get purPayConfirm;

  /// No description provided for @purReceiptSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase invoice posted'**
  String get purReceiptSuccessTitle;

  /// No description provided for @purReceiptSupplierCredit.
  ///
  /// In en, this message translates to:
  /// **'Remaining on credit (supplier debt)'**
  String get purReceiptSupplierCredit;

  /// No description provided for @purReceiptNewInvoice.
  ///
  /// In en, this message translates to:
  /// **'New purchase'**
  String get purReceiptNewInvoice;

  /// No description provided for @purPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick item to purchase'**
  String get purPickerTitle;

  /// No description provided for @purPickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or barcode'**
  String get purPickerSearchHint;

  /// No description provided for @purPickerEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No items yet'**
  String get purPickerEmptyTitle;

  /// No description provided for @purPickerEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add items in the inventory module then buy their stock here.'**
  String get purPickerEmptyBody;

  /// No description provided for @purPickerAvailable.
  ///
  /// In en, this message translates to:
  /// **'In stock: {qty}'**
  String purPickerAvailable(Object qty);

  /// No description provided for @purPickerLastCost.
  ///
  /// In en, this message translates to:
  /// **'Last cost: {cost}'**
  String purPickerLastCost(Object cost);

  /// No description provided for @retSaleTitle.
  ///
  /// In en, this message translates to:
  /// **'Sale return'**
  String get retSaleTitle;

  /// No description provided for @retSaleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Return sales with an SRN'**
  String get retSaleSubtitle;

  /// No description provided for @retPurchaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase return'**
  String get retPurchaseTitle;

  /// No description provided for @retPurchaseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Return intake to supplier with a PRN'**
  String get retPurchaseSubtitle;

  /// No description provided for @retPickInvoiceSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by invoice number or customer'**
  String get retPickInvoiceSearchHint;

  /// No description provided for @retPickPurchaseSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by PUR number or supplier'**
  String get retPickPurchaseSearchHint;

  /// No description provided for @retPickInvoiceEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No completed invoices'**
  String get retPickInvoiceEmptyTitle;

  /// No description provided for @retPickInvoiceEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Returns are strictly linked to a completed original invoice.'**
  String get retPickInvoiceEmptyBody;

  /// No description provided for @retPickInvoiceNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get retPickInvoiceNoResultsTitle;

  /// No description provided for @retPickInvoiceNoResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Try another number or name.'**
  String get retPickInvoiceNoResultsBody;

  /// No description provided for @retChangeInvoice.
  ///
  /// In en, this message translates to:
  /// **'Change invoice'**
  String get retChangeInvoice;

  /// No description provided for @retLinesTitle.
  ///
  /// In en, this message translates to:
  /// **'Returnable lines'**
  String get retLinesTitle;

  /// No description provided for @retNoLinesTitle.
  ///
  /// In en, this message translates to:
  /// **'No returnable lines'**
  String get retNoLinesTitle;

  /// No description provided for @retNoLinesBody.
  ///
  /// In en, this message translates to:
  /// **'All quantities of this invoice may have been returned already.'**
  String get retNoLinesBody;

  /// No description provided for @retOriginalQty.
  ///
  /// In en, this message translates to:
  /// **'Original: {qty}'**
  String retOriginalQty(Object qty);

  /// No description provided for @retReturnedQty.
  ///
  /// In en, this message translates to:
  /// **'Returned before: {qty}'**
  String retReturnedQty(Object qty);

  /// No description provided for @retAvailableQty.
  ///
  /// In en, this message translates to:
  /// **'Available to return: {qty}'**
  String retAvailableQty(Object qty);

  /// No description provided for @retQtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Return qty'**
  String get retQtyLabel;

  /// No description provided for @retLineRefundLabel.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get retLineRefundLabel;

  /// No description provided for @retRefundTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Return value'**
  String get retRefundTotalLabel;

  /// No description provided for @retRefundCash.
  ///
  /// In en, this message translates to:
  /// **'Cash refund'**
  String get retRefundCash;

  /// No description provided for @retRefundCredit.
  ///
  /// In en, this message translates to:
  /// **'Deduct from account'**
  String get retRefundCredit;

  /// No description provided for @retRefundCashOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Original invoice has an anonymous cash customer — refund in cash only.'**
  String get retRefundCashOnlyNote;

  /// No description provided for @retRefundCashFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Cash refunded now'**
  String get retRefundCashFieldLabel;

  /// No description provided for @retRefundCashShort.
  ///
  /// In en, this message translates to:
  /// **'Cash is below the return value ({total}) — choose deduction or mixed.'**
  String retRefundCashShort(Object total);

  /// No description provided for @retRefundMixedRange.
  ///
  /// In en, this message translates to:
  /// **'In a mixed refund enter an amount strictly between zero and the return value ({total}).'**
  String retRefundMixedRange(Object total);

  /// No description provided for @retPostButton.
  ///
  /// In en, this message translates to:
  /// **'Post return'**
  String get retPostButton;

  /// No description provided for @retNewReturn.
  ///
  /// In en, this message translates to:
  /// **'New return'**
  String get retNewReturn;

  /// No description provided for @retReceiptSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Return posted'**
  String get retReceiptSuccessTitle;

  /// No description provided for @retReceiptOriginal.
  ///
  /// In en, this message translates to:
  /// **'Against original invoice {no}'**
  String retReceiptOriginal(Object no);

  /// No description provided for @retReceiptRefundCash.
  ///
  /// In en, this message translates to:
  /// **'Cash refunded'**
  String get retReceiptRefundCash;

  /// No description provided for @retReceiptRefundCredit.
  ///
  /// In en, this message translates to:
  /// **'Deducted from account'**
  String get retReceiptRefundCredit;

  /// No description provided for @cashHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cashHomeTitle;

  /// No description provided for @cashHomeHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Net cash'**
  String get cashHomeHeroTitle;

  /// No description provided for @cashHomeHeroHint.
  ///
  /// In en, this message translates to:
  /// **'One line per currency — currencies never mix'**
  String get cashHomeHeroHint;

  /// No description provided for @cashHomeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No cash movements yet'**
  String get cashHomeEmptyTitle;

  /// No description provided for @cashHomeEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Start from the quick actions below — every movement is recorded here instantly.'**
  String get cashHomeEmptyBody;

  /// No description provided for @cashHomeBoxesSection.
  ///
  /// In en, this message translates to:
  /// **'Cash boxes'**
  String get cashHomeBoxesSection;

  /// No description provided for @cashHomeNoBoxesTitle.
  ///
  /// In en, this message translates to:
  /// **'No boxes yet'**
  String get cashHomeNoBoxesTitle;

  /// No description provided for @cashHomeNoBoxesBody.
  ///
  /// In en, this message translates to:
  /// **'Create a box from the boxes manager to start tracking cash.'**
  String get cashHomeNoBoxesBody;

  /// No description provided for @cashHomeRecentSection.
  ///
  /// In en, this message translates to:
  /// **'Recent movements'**
  String get cashHomeRecentSection;

  /// No description provided for @cashHomeManageBoxes.
  ///
  /// In en, this message translates to:
  /// **'Manage boxes'**
  String get cashHomeManageBoxes;

  /// No description provided for @cashDefaultChip.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get cashDefaultChip;

  /// No description provided for @cashNegativeBalance.
  ///
  /// In en, this message translates to:
  /// **'Negative balance'**
  String get cashNegativeBalance;

  /// No description provided for @cashQuickReceiptVoucher.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get cashQuickReceiptVoucher;

  /// No description provided for @cashQuickPaymentVoucher.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get cashQuickPaymentVoucher;

  /// No description provided for @cashQuickExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get cashQuickExpense;

  /// No description provided for @cashQuickOwnerDraw.
  ///
  /// In en, this message translates to:
  /// **'Owner draw'**
  String get cashQuickOwnerDraw;

  /// No description provided for @cashQuickCapitalIn.
  ///
  /// In en, this message translates to:
  /// **'Capital in'**
  String get cashQuickCapitalIn;

  /// No description provided for @cashQuickTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get cashQuickTransfer;

  /// No description provided for @cashQuickBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get cashQuickBank;

  /// No description provided for @cashQuickBoxes.
  ///
  /// In en, this message translates to:
  /// **'Boxes'**
  String get cashQuickBoxes;

  /// No description provided for @cashQuickMovements.
  ///
  /// In en, this message translates to:
  /// **'Movements'**
  String get cashQuickMovements;

  /// No description provided for @cashQuickCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get cashQuickCategories;

  /// No description provided for @cashQmSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash movement'**
  String get cashQmSheetTitle;

  /// No description provided for @cashQmKindExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get cashQmKindExpense;

  /// No description provided for @cashQmKindOwnerDraw.
  ///
  /// In en, this message translates to:
  /// **'Owner draw'**
  String get cashQmKindOwnerDraw;

  /// No description provided for @cashQmKindCapitalIn.
  ///
  /// In en, this message translates to:
  /// **'Capital in'**
  String get cashQmKindCapitalIn;

  /// No description provided for @cashQmKindTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get cashQmKindTransfer;

  /// No description provided for @cashQmKindBankDeposit.
  ///
  /// In en, this message translates to:
  /// **'Bank deposit'**
  String get cashQmKindBankDeposit;

  /// No description provided for @cashQmKindBankWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Bank withdrawal'**
  String get cashQmKindBankWithdraw;

  /// No description provided for @cashQmAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get cashQmAmountLabel;

  /// No description provided for @cashQmAmountHint.
  ///
  /// In en, this message translates to:
  /// **'In the source box currency'**
  String get cashQmAmountHint;

  /// No description provided for @cashQmSourceBoxLabel.
  ///
  /// In en, this message translates to:
  /// **'From box'**
  String get cashQmSourceBoxLabel;

  /// No description provided for @cashQmTargetBoxLabel.
  ///
  /// In en, this message translates to:
  /// **'To box'**
  String get cashQmTargetBoxLabel;

  /// No description provided for @cashQmDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get cashQmDateLabel;

  /// No description provided for @cashQmCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Expense category'**
  String get cashQmCategoryLabel;

  /// No description provided for @cashQmCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'Required for expenses only'**
  String get cashQmCategoryHint;

  /// No description provided for @cashQmDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get cashQmDescriptionLabel;

  /// No description provided for @cashQmDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — shows in the movements log'**
  String get cashQmDescriptionHint;

  /// No description provided for @cashQmProjectedSource.
  ///
  /// In en, this message translates to:
  /// **'Source balance afterwards'**
  String get cashQmProjectedSource;

  /// No description provided for @cashQmNegativeWarning.
  ///
  /// In en, this message translates to:
  /// **'The source balance will go negative after this movement — posting is allowed, this is a heads-up only.'**
  String get cashQmNegativeWarning;

  /// No description provided for @cashQmArrivesAtTarget.
  ///
  /// In en, this message translates to:
  /// **'Arrives at “{box}”: {amount} {code}'**
  String cashQmArrivesAtTarget(Object amount, Object box, Object code);

  /// No description provided for @cashQmSave.
  ///
  /// In en, this message translates to:
  /// **'Post movement'**
  String get cashQmSave;

  /// No description provided for @cashQmReceiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Movement posted'**
  String get cashQmReceiptTitle;

  /// No description provided for @cashQmReceiptArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived at target'**
  String get cashQmReceiptArrived;

  /// No description provided for @cashQmNewMovement.
  ///
  /// In en, this message translates to:
  /// **'Another movement'**
  String get cashQmNewMovement;

  /// No description provided for @cashQmNoBoxesTitle.
  ///
  /// In en, this message translates to:
  /// **'No boxes yet'**
  String get cashQmNoBoxesTitle;

  /// No description provided for @cashQmNoBoxesBody.
  ///
  /// In en, this message translates to:
  /// **'Create a box first from “Boxes”, then come back.'**
  String get cashQmNoBoxesBody;

  /// No description provided for @cashVoucherReceiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt voucher'**
  String get cashVoucherReceiptTitle;

  /// No description provided for @cashVoucherReceiptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Collect from a customer — RVT number'**
  String get cashVoucherReceiptSubtitle;

  /// No description provided for @cashVoucherPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment voucher'**
  String get cashVoucherPaymentTitle;

  /// No description provided for @cashVoucherPaymentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pay a supplier — PMT number'**
  String get cashVoucherPaymentSubtitle;

  /// No description provided for @cashVoucherPartySection.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get cashVoucherPartySection;

  /// No description provided for @cashVoucherPickParty.
  ///
  /// In en, this message translates to:
  /// **'Select party'**
  String get cashVoucherPickParty;

  /// No description provided for @cashVoucherChangeParty.
  ///
  /// In en, this message translates to:
  /// **'Change party'**
  String get cashVoucherChangeParty;

  /// No description provided for @cashVoucherPartyBalance.
  ///
  /// In en, this message translates to:
  /// **'Party balance'**
  String get cashVoucherPartyBalance;

  /// No description provided for @cashVoucherAmountSection.
  ///
  /// In en, this message translates to:
  /// **'Amount & currency'**
  String get cashVoucherAmountSection;

  /// No description provided for @cashVoucherCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Voucher currency'**
  String get cashVoucherCurrencyLabel;

  /// No description provided for @cashVoucherBoxSection.
  ///
  /// In en, this message translates to:
  /// **'Box & date'**
  String get cashVoucherBoxSection;

  /// No description provided for @cashVoucherAllocationSection.
  ///
  /// In en, this message translates to:
  /// **'Allocation'**
  String get cashVoucherAllocationSection;

  /// No description provided for @cashVoucherAllocFifo.
  ///
  /// In en, this message translates to:
  /// **'FIFO allocation'**
  String get cashVoucherAllocFifo;

  /// No description provided for @cashVoucherAllocOnAccount.
  ///
  /// In en, this message translates to:
  /// **'On account'**
  String get cashVoucherAllocOnAccount;

  /// No description provided for @cashVoucherOpenDuesTotal.
  ///
  /// In en, this message translates to:
  /// **'Open dues'**
  String get cashVoucherOpenDuesTotal;

  /// No description provided for @cashVoucherOpenRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get cashVoucherOpenRemaining;

  /// No description provided for @cashVoucherNoOpenDues.
  ///
  /// In en, this message translates to:
  /// **'No open dues in the voucher currency for this party — choose “on account” or change the currency.'**
  String get cashVoucherNoOpenDues;

  /// No description provided for @cashVoucherPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Will be allocated to'**
  String get cashVoucherPlanTitle;

  /// No description provided for @cashVoucherUnallocated.
  ///
  /// In en, this message translates to:
  /// **'Remainder on account'**
  String get cashVoucherUnallocated;

  /// No description provided for @cashVoucherLoadingInvoices.
  ///
  /// In en, this message translates to:
  /// **'Loading open invoices…'**
  String get cashVoucherLoadingInvoices;

  /// No description provided for @cashVoucherCrossDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposited into the box: {amount} {code}'**
  String cashVoucherCrossDeposit(Object amount, Object code);

  /// No description provided for @cashVoucherNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get cashVoucherNotesLabel;

  /// No description provided for @cashVoucherNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — stored with the voucher'**
  String get cashVoucherNotesHint;

  /// No description provided for @cashVoucherPost.
  ///
  /// In en, this message translates to:
  /// **'Post voucher'**
  String get cashVoucherPost;

  /// No description provided for @cashVoucherPostedSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Voucher {no} posted — {amount} {code}'**
  String cashVoucherPostedSnackBar(Object amount, Object code, Object no);

  /// No description provided for @cashVoucherPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select party'**
  String get cashVoucherPickerTitle;

  /// No description provided for @cashVoucherPickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or phone'**
  String get cashVoucherPickerSearchHint;

  /// No description provided for @cashVoucherPickerEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No parties yet'**
  String get cashVoucherPickerEmptyTitle;

  /// No description provided for @cashVoucherPickerEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Register customers or suppliers in the parties module first, then come back.'**
  String get cashVoucherPickerEmptyBody;

  /// No description provided for @cashVoucherPickerNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get cashVoucherPickerNoResultsTitle;

  /// No description provided for @cashVoucherPickerNoResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Try another name or phone.'**
  String get cashVoucherPickerNoResultsBody;

  /// No description provided for @cashVoucherPartyOwesYou.
  ///
  /// In en, this message translates to:
  /// **'Owes you'**
  String get cashVoucherPartyOwesYou;

  /// No description provided for @cashVoucherPartyWeOwe.
  ///
  /// In en, this message translates to:
  /// **'We owe'**
  String get cashVoucherPartyWeOwe;

  /// No description provided for @cashVoucherPartyCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit balance'**
  String get cashVoucherPartyCredit;

  /// No description provided for @cashMovementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash movements log'**
  String get cashMovementsTitle;

  /// No description provided for @cashMovementsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search description, voucher no., or party'**
  String get cashMovementsSearchHint;

  /// No description provided for @cashMovementsAllBoxes.
  ///
  /// In en, this message translates to:
  /// **'All boxes'**
  String get cashMovementsAllBoxes;

  /// No description provided for @cashMovementsAllTypes.
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get cashMovementsAllTypes;

  /// No description provided for @cashMovementsPeriodAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get cashMovementsPeriodAll;

  /// No description provided for @cashMovementsPeriodToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get cashMovementsPeriodToday;

  /// No description provided for @cashMovementsPeriodWeek.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get cashMovementsPeriodWeek;

  /// No description provided for @cashMovementsPeriodMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get cashMovementsPeriodMonth;

  /// No description provided for @cashMovementsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No movements yet'**
  String get cashMovementsEmptyTitle;

  /// No description provided for @cashMovementsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Every cash movement — vouchers, expenses, transfers — appears here once posted.'**
  String get cashMovementsEmptyBody;

  /// No description provided for @cashMovementsNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get cashMovementsNoResultsTitle;

  /// No description provided for @cashMovementsNoResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Change the box, type, period, or search.'**
  String get cashMovementsNoResultsBody;

  /// No description provided for @cashMovementsVoidedChip.
  ///
  /// In en, this message translates to:
  /// **'Voided'**
  String get cashMovementsVoidedChip;

  /// No description provided for @cashMovementsReversalChip.
  ///
  /// In en, this message translates to:
  /// **'Reversal entry'**
  String get cashMovementsReversalChip;

  /// No description provided for @cashTypeReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get cashTypeReceipt;

  /// No description provided for @cashTypePayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get cashTypePayment;

  /// No description provided for @cashTypeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get cashTypeExpense;

  /// No description provided for @cashTypeOwnerDraw.
  ///
  /// In en, this message translates to:
  /// **'Owner draw'**
  String get cashTypeOwnerDraw;

  /// No description provided for @cashTypeCapitalIn.
  ///
  /// In en, this message translates to:
  /// **'Capital in'**
  String get cashTypeCapitalIn;

  /// No description provided for @cashTypeBoxTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get cashTypeBoxTransfer;

  /// No description provided for @cashTypeBankDeposit.
  ///
  /// In en, this message translates to:
  /// **'Bank deposit'**
  String get cashTypeBankDeposit;

  /// No description provided for @cashTypeBankWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Bank withdrawal'**
  String get cashTypeBankWithdraw;

  /// No description provided for @cashTypeOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get cashTypeOpening;

  /// No description provided for @cashMovementDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Movement details'**
  String get cashMovementDetailTitle;

  /// No description provided for @cashMovementFieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get cashMovementFieldDate;

  /// No description provided for @cashMovementFieldBox.
  ///
  /// In en, this message translates to:
  /// **'Box'**
  String get cashMovementFieldBox;

  /// No description provided for @cashMovementFieldTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get cashMovementFieldTo;

  /// No description provided for @cashMovementFieldVoucher.
  ///
  /// In en, this message translates to:
  /// **'Voucher no.'**
  String get cashMovementFieldVoucher;

  /// No description provided for @cashMovementFieldParty.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get cashMovementFieldParty;

  /// No description provided for @cashMovementFieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get cashMovementFieldCategory;

  /// No description provided for @cashMovementFieldRate.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate'**
  String get cashMovementFieldRate;

  /// No description provided for @cashMovementFieldSettlement.
  ///
  /// In en, this message translates to:
  /// **'Settlement rate'**
  String get cashMovementFieldSettlement;

  /// No description provided for @cashMovementFieldFx.
  ///
  /// In en, this message translates to:
  /// **'FX difference'**
  String get cashMovementFieldFx;

  /// No description provided for @cashMovementFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get cashMovementFieldDescription;

  /// No description provided for @cashMovementAllocationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Allocations'**
  String get cashMovementAllocationsTitle;

  /// No description provided for @cashAllocSaleInvoice.
  ///
  /// In en, this message translates to:
  /// **'Sales invoice'**
  String get cashAllocSaleInvoice;

  /// No description provided for @cashAllocPurchaseInvoice.
  ///
  /// In en, this message translates to:
  /// **'Purchase invoice'**
  String get cashAllocPurchaseInvoice;

  /// No description provided for @cashMovementVoidButton.
  ///
  /// In en, this message translates to:
  /// **'Void movement'**
  String get cashMovementVoidButton;

  /// No description provided for @cashMovementVoidTitle.
  ///
  /// In en, this message translates to:
  /// **'Void this movement?'**
  String get cashMovementVoidTitle;

  /// No description provided for @cashMovementVoidBody.
  ///
  /// In en, this message translates to:
  /// **'Voiding does not delete: a reversing entry is created in one transaction restoring every balance, and the original stays in the log marked “voided”. The voucher number is never reused.'**
  String get cashMovementVoidBody;

  /// No description provided for @cashMovementVoidReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get cashMovementVoidReasonLabel;

  /// No description provided for @cashMovementVoidConfirm.
  ///
  /// In en, this message translates to:
  /// **'Void permanently'**
  String get cashMovementVoidConfirm;

  /// No description provided for @cashMovementVoidedSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Movement voided — reversing entry recorded.'**
  String get cashMovementVoidedSnackBar;

  /// No description provided for @cashMovementNotVoidableNote.
  ///
  /// In en, this message translates to:
  /// **'This movement is tied to another document (invoice collection or return refund) — void it from its original document.'**
  String get cashMovementNotVoidableNote;

  /// No description provided for @cashBoxesTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage cash boxes'**
  String get cashBoxesTitle;

  /// No description provided for @cashBoxesAddBox.
  ///
  /// In en, this message translates to:
  /// **'New box'**
  String get cashBoxesAddBox;

  /// No description provided for @cashBoxesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No boxes yet'**
  String get cashBoxesEmptyTitle;

  /// No description provided for @cashBoxesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Create a box per currency or cash location you use — a bank is just a box named after the bank.'**
  String get cashBoxesEmptyBody;

  /// No description provided for @cashBoxesArchivedSection.
  ///
  /// In en, this message translates to:
  /// **'Archived boxes'**
  String get cashBoxesArchivedSection;

  /// No description provided for @cashBoxesSetDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get cashBoxesSetDefault;

  /// No description provided for @cashBoxesEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit box'**
  String get cashBoxesEditTooltip;

  /// No description provided for @cashBoxesArchiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Archive box'**
  String get cashBoxesArchiveTooltip;

  /// No description provided for @cashBoxesUnarchiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get cashBoxesUnarchiveTooltip;

  /// No description provided for @cashBoxesArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive “{name}”?'**
  String cashBoxesArchiveTitle(Object name);

  /// No description provided for @cashBoxesArchiveBody.
  ///
  /// In en, this message translates to:
  /// **'The box disappears from daily screens while its full history stays in the movements log.'**
  String get cashBoxesArchiveBody;

  /// No description provided for @cashBoxesArchiveNonZeroTitle.
  ///
  /// In en, this message translates to:
  /// **'“{name}” has a non-zero balance'**
  String cashBoxesArchiveNonZeroTitle(Object name);

  /// No description provided for @cashBoxesArchiveNonZeroBody.
  ///
  /// In en, this message translates to:
  /// **'A non-zero balance keeps counting in net cash after archiving. Prefer clearing the balance first — or explicitly confirm archiving.'**
  String get cashBoxesArchiveNonZeroBody;

  /// No description provided for @cashBoxesArchiveForce.
  ///
  /// In en, this message translates to:
  /// **'Archive with balance'**
  String get cashBoxesArchiveForce;

  /// No description provided for @cashBoxesDefaultDone.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is now the default box.'**
  String cashBoxesDefaultDone(Object name);

  /// No description provided for @cashBoxFormNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New cash box'**
  String get cashBoxFormNewTitle;

  /// No description provided for @cashBoxFormEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit cash box'**
  String get cashBoxFormEditTitle;

  /// No description provided for @cashBoxFormNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Box name'**
  String get cashBoxFormNameLabel;

  /// No description provided for @cashBoxFormNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Main drawer, Savings bank'**
  String get cashBoxFormNameHint;

  /// No description provided for @cashBoxFormCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Box currency'**
  String get cashBoxFormCurrencyLabel;

  /// No description provided for @cashBoxFormCurrencyLocked.
  ///
  /// In en, this message translates to:
  /// **'A box currency is fixed at creation and never changes — edit the name or default only.'**
  String get cashBoxFormCurrencyLocked;

  /// No description provided for @cashBoxFormMakeDefault.
  ///
  /// In en, this message translates to:
  /// **'Default box'**
  String get cashBoxFormMakeDefault;

  /// No description provided for @cashBoxFormMakeDefaultHint.
  ///
  /// In en, this message translates to:
  /// **'Cash forms open it automatically'**
  String get cashBoxFormMakeDefaultHint;

  /// No description provided for @cashBoxFormSave.
  ///
  /// In en, this message translates to:
  /// **'Save box'**
  String get cashBoxFormSave;

  /// No description provided for @cashBoxFormSaved.
  ///
  /// In en, this message translates to:
  /// **'Box saved.'**
  String get cashBoxFormSaved;

  /// No description provided for @cashBoxFormNotFound.
  ///
  /// In en, this message translates to:
  /// **'The requested box does not exist.'**
  String get cashBoxFormNotFound;

  /// No description provided for @cashCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Expense categories'**
  String get cashCategoriesTitle;

  /// No description provided for @cashCategoriesAdd.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get cashCategoriesAdd;

  /// No description provided for @cashCategoriesNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get cashCategoriesNameLabel;

  /// No description provided for @cashCategoriesNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Electricity, Rent, Transport'**
  String get cashCategoriesNameHint;

  /// No description provided for @cashCategoriesAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get cashCategoriesAddButton;

  /// No description provided for @cashCategoriesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get cashCategoriesEmptyTitle;

  /// No description provided for @cashCategoriesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Categories classify expenses for later reports — the “Salaries” category is system-protected.'**
  String get cashCategoriesEmptyBody;

  /// No description provided for @cashCategoriesProtected.
  ///
  /// In en, this message translates to:
  /// **'Protected'**
  String get cashCategoriesProtected;

  /// No description provided for @cashCategoriesProtectedTooltip.
  ///
  /// In en, this message translates to:
  /// **'System category — cannot be archived'**
  String get cashCategoriesProtectedTooltip;

  /// No description provided for @cashCategoriesRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get cashCategoriesRename;

  /// No description provided for @cashCategoriesRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename category'**
  String get cashCategoriesRenameTitle;

  /// No description provided for @cashCategoriesArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get cashCategoriesArchive;

  /// No description provided for @cashCategoriesArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive “{name}”?'**
  String cashCategoriesArchiveTitle(Object name);

  /// No description provided for @cashCategoriesArchiveBody.
  ///
  /// In en, this message translates to:
  /// **'It disappears from new-expense pickers while its history stays in the log.'**
  String get cashCategoriesArchiveBody;

  /// No description provided for @cashCategoriesUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get cashCategoriesUnarchive;

  /// No description provided for @cashCategoriesArchivedSection.
  ///
  /// In en, this message translates to:
  /// **'Archived categories'**
  String get cashCategoriesArchivedSection;

  /// No description provided for @printingPdfTooltip.
  ///
  /// In en, this message translates to:
  /// **'Print PDF'**
  String get printingPdfTooltip;

  /// No description provided for @printingPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Print preview'**
  String get printingPreviewTitle;

  /// No description provided for @printingPreviewFileSize.
  ///
  /// In en, this message translates to:
  /// **'Size: {sizeKb} KB'**
  String printingPreviewFileSize(int sizeKb);

  /// No description provided for @printingPrint.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get printingPrint;

  /// No description provided for @printingShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get printingShare;

  /// No description provided for @printingWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get printingWhatsApp;

  /// No description provided for @printingClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get printingClose;

  /// No description provided for @printingBuildError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t prepare the document'**
  String get printingBuildError;

  /// No description provided for @printingBuildErrorBody.
  ///
  /// In en, this message translates to:
  /// **'The PDF file didn’t finish generating. Retry, or close this window and open the document again.'**
  String get printingBuildErrorBody;

  /// No description provided for @printingPrintFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open the print dialog'**
  String get printingPrintFailed;

  /// No description provided for @printingShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open sharing'**
  String get printingShareFailed;

  /// No description provided for @printingWhatsAppFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open WhatsApp'**
  String get printingWhatsAppFailed;

  /// No description provided for @printingInvoiceDocTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales invoice'**
  String get printingInvoiceDocTitle;

  /// No description provided for @printingVoucherReceiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt voucher'**
  String get printingVoucherReceiptTitle;

  /// No description provided for @printingVoucherPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment voucher'**
  String get printingVoucherPaymentTitle;

  /// No description provided for @printingLblCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get printingLblCustomer;

  /// No description provided for @printingLblParty.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get printingLblParty;

  /// No description provided for @printingLblAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get printingLblAmount;

  /// No description provided for @printingLblDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get printingLblDate;

  /// No description provided for @printingLblCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get printingLblCurrency;

  /// No description provided for @printingLblItem.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get printingLblItem;

  /// No description provided for @printingLblQty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get printingLblQty;

  /// No description provided for @printingLblPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get printingLblPrice;

  /// No description provided for @printingLblDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get printingLblDiscount;

  /// No description provided for @printingLblSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get printingLblSubtotal;

  /// No description provided for @printingLblTotalDiscount.
  ///
  /// In en, this message translates to:
  /// **'Total discount'**
  String get printingLblTotalDiscount;

  /// No description provided for @printingLblGrandTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get printingLblGrandTotal;

  /// No description provided for @printingLblPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get printingLblPaid;

  /// No description provided for @printingLblDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get printingLblDue;

  /// No description provided for @printingLblItemsSection.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get printingLblItemsSection;

  /// No description provided for @printingLblDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get printingLblDescription;

  /// No description provided for @printingLblBox.
  ///
  /// In en, this message translates to:
  /// **'Cash box'**
  String get printingLblBox;

  /// No description provided for @printingLblSignature.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get printingLblSignature;

  /// No description provided for @printingFooterThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your business'**
  String get printingFooterThanks;

  /// No description provided for @printingCashCustomer.
  ///
  /// In en, this message translates to:
  /// **'Cash customer'**
  String get printingCashCustomer;

  /// No description provided for @printingShareMessageInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice {docNo} — total {total}'**
  String printingShareMessageInvoice(Object docNo, Object total);

  /// No description provided for @printingShareMessageVoucher.
  ///
  /// In en, this message translates to:
  /// **'Voucher {voucherNo} — amount {amount}'**
  String printingShareMessageVoucher(Object amount, Object voucherNo);

  /// No description provided for @printingVoucherPdfButton.
  ///
  /// In en, this message translates to:
  /// **'Print voucher PDF'**
  String get printingVoucherPdfButton;

  /// No description provided for @printingStatementDocTitle.
  ///
  /// In en, this message translates to:
  /// **'Account statement'**
  String get printingStatementDocTitle;

  /// No description provided for @printingLblGeneratedAt.
  ///
  /// In en, this message translates to:
  /// **'Issue date'**
  String get printingLblGeneratedAt;

  /// No description provided for @printingLblPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get printingLblPeriod;

  /// No description provided for @printingStatementPeriodRange.
  ///
  /// In en, this message translates to:
  /// **'From {from} to {to}'**
  String printingStatementPeriodRange(Object from, Object to);

  /// No description provided for @printingStatementDebit.
  ///
  /// In en, this message translates to:
  /// **'Debit'**
  String get printingStatementDebit;

  /// No description provided for @printingStatementCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get printingStatementCredit;

  /// No description provided for @printingStatementBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get printingStatementBalance;

  /// No description provided for @printingStatementTotalDebit.
  ///
  /// In en, this message translates to:
  /// **'Total debit'**
  String get printingStatementTotalDebit;

  /// No description provided for @printingStatementTotalCredit.
  ///
  /// In en, this message translates to:
  /// **'Total credit'**
  String get printingStatementTotalCredit;

  /// No description provided for @printingStatementClosing.
  ///
  /// In en, this message translates to:
  /// **'Closing balance'**
  String get printingStatementClosing;

  /// No description provided for @printingStatementEmpty.
  ///
  /// In en, this message translates to:
  /// **'No entries in this period'**
  String get printingStatementEmpty;

  /// No description provided for @printingShareMessageStatement.
  ///
  /// In en, this message translates to:
  /// **'Account statement for {party} — closing balance {balance}'**
  String printingShareMessageStatement(Object balance, Object party);

  /// No description provided for @backupScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupScreenTitle;

  /// No description provided for @backupWebPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Web preview'**
  String get backupWebPreviewTitle;

  /// No description provided for @backupWebPreviewBody.
  ///
  /// In en, this message translates to:
  /// **'This preview keeps its data inside your browser. Actual file backup — creating, restoring, and sharing — is available in the Android app.'**
  String get backupWebPreviewBody;

  /// No description provided for @backupLastBackupLabel.
  ///
  /// In en, this message translates to:
  /// **'Last successful backup'**
  String get backupLastBackupLabel;

  /// No description provided for @backupLastNever.
  ///
  /// In en, this message translates to:
  /// **'No backup yet'**
  String get backupLastNever;

  /// No description provided for @backupSavedCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Stored backups'**
  String get backupSavedCountLabel;

  /// No description provided for @backupCreateNow.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get backupCreateNow;

  /// No description provided for @backupCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating backup…'**
  String get backupCreating;

  /// No description provided for @backupCreateHint.
  ///
  /// In en, this message translates to:
  /// **'One dated, compressed file stored in the app\'s backups folder'**
  String get backupCreateHint;

  /// No description provided for @backupCreateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup created: {fileName}'**
  String backupCreateSuccess(String fileName);

  /// No description provided for @backupCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the backup'**
  String get backupCreateFailed;

  /// No description provided for @backupScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic schedule'**
  String get backupScheduleTitle;

  /// No description provided for @backupScheduleDesc.
  ///
  /// In en, this message translates to:
  /// **'A silent backup runs when you open the app once the interval has passed'**
  String get backupScheduleDesc;

  /// No description provided for @backupScheduleDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get backupScheduleDaily;

  /// No description provided for @backupScheduleWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get backupScheduleWeekly;

  /// No description provided for @backupScheduleOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get backupScheduleOff;

  /// No description provided for @backupRetentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Retention'**
  String get backupRetentionTitle;

  /// No description provided for @backupRetentionDesc.
  ///
  /// In en, this message translates to:
  /// **'Keeps the last {count} backups and deletes older ones automatically'**
  String backupRetentionDesc(int count);

  /// No description provided for @backupLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup history'**
  String get backupLogTitle;

  /// No description provided for @backupLogEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No backups yet'**
  String get backupLogEmptyTitle;

  /// No description provided for @backupLogEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Create your first backup with one tap — a single file that holds all your data.'**
  String get backupLogEmptyBody;

  /// No description provided for @backupKindManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get backupKindManual;

  /// No description provided for @backupKindAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get backupKindAuto;

  /// No description provided for @backupKindSafety.
  ///
  /// In en, this message translates to:
  /// **'Safety (before restore)'**
  String get backupKindSafety;

  /// No description provided for @backupKindGeneric.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backupKindGeneric;

  /// No description provided for @backupStatusOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get backupStatusOk;

  /// No description provided for @backupStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get backupStatusFailed;

  /// No description provided for @backupFileMissing.
  ///
  /// In en, this message translates to:
  /// **'File deleted'**
  String get backupFileMissing;

  /// No description provided for @backupRestoreTooltip.
  ///
  /// In en, this message translates to:
  /// **'Restore this backup'**
  String get backupRestoreTooltip;

  /// No description provided for @backupShareTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share the file'**
  String get backupShareTooltip;

  /// No description provided for @backupRestoreFromFile.
  ///
  /// In en, this message translates to:
  /// **'Restore from external file'**
  String get backupRestoreFromFile;

  /// No description provided for @backupRestoreFromFileDesc.
  ///
  /// In en, this message translates to:
  /// **'Pick a .finbak file you received via sharing or a manual copy'**
  String get backupRestoreFromFileDesc;

  /// No description provided for @backupSizeKb.
  ///
  /// In en, this message translates to:
  /// **'{value} KB'**
  String backupSizeKb(String value);

  /// No description provided for @backupSizeMb.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String backupSizeMb(String value);

  /// No description provided for @backupShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not share the file'**
  String get backupShareFailed;

  /// No description provided for @backupSettingSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the setting'**
  String get backupSettingSaveFailed;

  /// No description provided for @backupRestoreDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore a backup'**
  String get backupRestoreDialogTitle;

  /// No description provided for @backupRestoreWarnBody.
  ///
  /// In en, this message translates to:
  /// **'This will replace ALL current data with the backup\'s data. A safety copy of your current data is created automatically before the replacement.'**
  String get backupRestoreWarnBody;

  /// No description provided for @backupRestoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'Replace data'**
  String get backupRestoreConfirm;

  /// No description provided for @backupRestoreRunning.
  ///
  /// In en, this message translates to:
  /// **'Restoring…'**
  String get backupRestoreRunning;

  /// No description provided for @backupRestoreSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore completed'**
  String get backupRestoreSuccessTitle;

  /// No description provided for @backupRestoreSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'The backup\'s data is back in the app. You will now be asked for that backup\'s PIN.'**
  String get backupRestoreSuccessBody;

  /// No description provided for @backupRestoreFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore failed'**
  String get backupRestoreFailedTitle;

  /// No description provided for @backupRestoreClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get backupRestoreClose;

  /// No description provided for @backupInspectFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get backupInspectFile;

  /// No description provided for @backupInspectCreated.
  ///
  /// In en, this message translates to:
  /// **'Backup date'**
  String get backupInspectCreated;

  /// No description provided for @backupInspectSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get backupInspectSize;

  /// No description provided for @backupInspectSchema.
  ///
  /// In en, this message translates to:
  /// **'Schema version'**
  String get backupInspectSchema;

  /// No description provided for @backupInspectChecksum.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint (SHA-256)'**
  String get backupInspectChecksum;

  /// No description provided for @backupInspectKind.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get backupInspectKind;

  /// No description provided for @backupErrNotFile.
  ///
  /// In en, this message translates to:
  /// **'The selected file is not a valid FinAcc backup (.finbak).'**
  String get backupErrNotFile;

  /// No description provided for @backupErrChecksum.
  ///
  /// In en, this message translates to:
  /// **'Integrity check failed — the file is corrupted or was modified after creation.'**
  String get backupErrChecksum;

  /// No description provided for @backupErrNewerSchema.
  ///
  /// In en, this message translates to:
  /// **'This backup uses a newer schema (v{fileVersion}) than this app (v{appVersion}) — update the app first.'**
  String backupErrNewerSchema(int fileVersion, int appVersion);

  /// No description provided for @backupErrSafety.
  ///
  /// In en, this message translates to:
  /// **'Could not create the safety backup before restoring — the operation was cancelled and your data is untouched.'**
  String get backupErrSafety;

  /// No description provided for @backupErrOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the restored database — your current data was restored as it was.'**
  String get backupErrOpenFailed;

  /// No description provided for @backupErrUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Restore is available in the Android app only.'**
  String get backupErrUnsupported;

  /// No description provided for @backupBannerAutoDone.
  ///
  /// In en, this message translates to:
  /// **'An automatic backup was created successfully at {time}'**
  String backupBannerAutoDone(String time);

  /// No description provided for @backupBannerAutoFailed.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup failed — create one manually from settings.'**
  String get backupBannerAutoFailed;

  /// No description provided for @backupBannerWebDue.
  ///
  /// In en, this message translates to:
  /// **'A backup is due — full backup features are in the Android app.'**
  String get backupBannerWebDue;

  /// No description provided for @backupBannerOpen.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get backupBannerOpen;

  /// No description provided for @settingsBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingsBackupTitle;

  /// No description provided for @settingsBackupDesc.
  ///
  /// In en, this message translates to:
  /// **'One-tap local backup, scheduling, restore, and sharing'**
  String get settingsBackupDesc;

  /// No description provided for @settingsAboutDbSize.
  ///
  /// In en, this message translates to:
  /// **'Database size: {size}'**
  String settingsAboutDbSize(String size);

  /// No description provided for @shiftTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get shiftTitle;

  /// No description provided for @shiftOpenNoneTitle.
  ///
  /// In en, this message translates to:
  /// **'No open shift'**
  String get shiftOpenNoneTitle;

  /// No description provided for @shiftOpenNoneBody.
  ///
  /// In en, this message translates to:
  /// **'Open the shift by entering the box opening count, then track sales and collections until you close it with the comprehensive equation.'**
  String get shiftOpenNoneBody;

  /// No description provided for @shiftOpeningCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Opening count'**
  String get shiftOpeningCountLabel;

  /// No description provided for @shiftOpenButton.
  ///
  /// In en, this message translates to:
  /// **'Open shift'**
  String get shiftOpenButton;

  /// No description provided for @shiftInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number (zero or more).'**
  String get shiftInvalidAmount;

  /// No description provided for @shiftLiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Open shift'**
  String get shiftLiveTitle;

  /// No description provided for @shiftOpenedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Opened at'**
  String get shiftOpenedAtLabel;

  /// No description provided for @shiftRunningIn.
  ///
  /// In en, this message translates to:
  /// **'In so far'**
  String get shiftRunningIn;

  /// No description provided for @shiftRunningOut.
  ///
  /// In en, this message translates to:
  /// **'Out so far'**
  String get shiftRunningOut;

  /// No description provided for @shiftExpectedSoFar.
  ///
  /// In en, this message translates to:
  /// **'Expected so far'**
  String get shiftExpectedSoFar;

  /// No description provided for @shiftAutoRefreshNote.
  ///
  /// In en, this message translates to:
  /// **'Auto-refreshes every 30 seconds'**
  String get shiftAutoRefreshNote;

  /// No description provided for @shiftCloseButton.
  ///
  /// In en, this message translates to:
  /// **'Close shift'**
  String get shiftCloseButton;

  /// No description provided for @shiftHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent shifts'**
  String get shiftHistoryTitle;

  /// No description provided for @shiftHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No closed shifts yet — close your first shift to see its report here.'**
  String get shiftHistoryEmpty;

  /// No description provided for @shiftCountedLabel.
  ///
  /// In en, this message translates to:
  /// **'Counted amount'**
  String get shiftCountedLabel;

  /// No description provided for @shiftCountedHint.
  ///
  /// In en, this message translates to:
  /// **'The amount actually counted in the box right now'**
  String get shiftCountedHint;

  /// No description provided for @shiftExpectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get shiftExpectedLabel;

  /// No description provided for @shiftDifferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get shiftDifferenceLabel;

  /// No description provided for @shiftSurplus.
  ///
  /// In en, this message translates to:
  /// **'Surplus'**
  String get shiftSurplus;

  /// No description provided for @shiftDeficit.
  ///
  /// In en, this message translates to:
  /// **'Deficit'**
  String get shiftDeficit;

  /// No description provided for @shiftMatched.
  ///
  /// In en, this message translates to:
  /// **'Matched'**
  String get shiftMatched;

  /// No description provided for @shiftNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get shiftNotesLabel;

  /// No description provided for @shiftNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — e.g. the reason for a surplus or deficit'**
  String get shiftNotesHint;

  /// No description provided for @shiftConfirmClose.
  ///
  /// In en, this message translates to:
  /// **'Confirm closing'**
  String get shiftConfirmClose;

  /// No description provided for @shiftCloseSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift closed'**
  String get shiftCloseSuccessTitle;

  /// No description provided for @shiftEquationTitle.
  ///
  /// In en, this message translates to:
  /// **'Comprehensive equation breakdown'**
  String get shiftEquationTitle;

  /// No description provided for @shiftChequesDeferredNote.
  ///
  /// In en, this message translates to:
  /// **'Cheques are deferred to v1.1 — shown as zero in the equation.'**
  String get shiftChequesDeferredNote;

  /// No description provided for @shiftCompCashSales.
  ///
  /// In en, this message translates to:
  /// **'Cash sales'**
  String get shiftCompCashSales;

  /// No description provided for @shiftCompCollections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get shiftCompCollections;

  /// No description provided for @shiftCompOwnerDeposits.
  ///
  /// In en, this message translates to:
  /// **'Owner deposits'**
  String get shiftCompOwnerDeposits;

  /// No description provided for @shiftCompTransfersIn.
  ///
  /// In en, this message translates to:
  /// **'Transfers & deposits in'**
  String get shiftCompTransfersIn;

  /// No description provided for @shiftCompBankIn.
  ///
  /// In en, this message translates to:
  /// **'Bank deposits in'**
  String get shiftCompBankIn;

  /// No description provided for @shiftCompChequesCleared.
  ///
  /// In en, this message translates to:
  /// **'Cheques cleared'**
  String get shiftCompChequesCleared;

  /// No description provided for @shiftCompSupplierPayments.
  ///
  /// In en, this message translates to:
  /// **'Supplier payments'**
  String get shiftCompSupplierPayments;

  /// No description provided for @shiftCompExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get shiftCompExpenses;

  /// No description provided for @shiftCompOwnerDraws.
  ///
  /// In en, this message translates to:
  /// **'Owner draws'**
  String get shiftCompOwnerDraws;

  /// No description provided for @shiftCompTransfersOut.
  ///
  /// In en, this message translates to:
  /// **'Transfers & withdrawals out'**
  String get shiftCompTransfersOut;

  /// No description provided for @shiftCompBankOut.
  ///
  /// In en, this message translates to:
  /// **'Bank withdrawals'**
  String get shiftCompBankOut;

  /// No description provided for @shiftCompChequesPaid.
  ///
  /// In en, this message translates to:
  /// **'Cheques paid'**
  String get shiftCompChequesPaid;

  /// No description provided for @shiftCompOther.
  ///
  /// In en, this message translates to:
  /// **'Other items (net)'**
  String get shiftCompOther;

  /// No description provided for @shiftPdfPreviewAction.
  ///
  /// In en, this message translates to:
  /// **'Preview PDF report'**
  String get shiftPdfPreviewAction;

  /// No description provided for @shiftPrintTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift Report'**
  String get shiftPrintTitle;

  /// No description provided for @shiftPrintBox.
  ///
  /// In en, this message translates to:
  /// **'Box'**
  String get shiftPrintBox;

  /// No description provided for @shiftPrintUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get shiftPrintUser;

  /// No description provided for @shiftPrintOpened.
  ///
  /// In en, this message translates to:
  /// **'Opened'**
  String get shiftPrintOpened;

  /// No description provided for @shiftPrintClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get shiftPrintClosed;

  /// No description provided for @shiftPrintItemCol.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get shiftPrintItemCol;

  /// No description provided for @shiftPrintDirectionCol.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get shiftPrintDirectionCol;

  /// No description provided for @shiftPrintValueCol.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get shiftPrintValueCol;

  /// No description provided for @shiftPrintDirIn.
  ///
  /// In en, this message translates to:
  /// **'In (+)'**
  String get shiftPrintDirIn;

  /// No description provided for @shiftPrintDirOut.
  ///
  /// In en, this message translates to:
  /// **'Out (−)'**
  String get shiftPrintDirOut;

  /// No description provided for @shiftPrintTotalIn.
  ///
  /// In en, this message translates to:
  /// **'Total in'**
  String get shiftPrintTotalIn;

  /// No description provided for @shiftPrintTotalOut.
  ///
  /// In en, this message translates to:
  /// **'Total out'**
  String get shiftPrintTotalOut;

  /// No description provided for @shiftPrintNotesRow.
  ///
  /// In en, this message translates to:
  /// **'Closing notes'**
  String get shiftPrintNotesRow;

  /// No description provided for @shiftPrintShareMessage.
  ///
  /// In en, this message translates to:
  /// **'Shift report for {box} — expected {expected}, difference {difference}'**
  String shiftPrintShareMessage(String box, String expected, String difference);

  /// No description provided for @agingTitle.
  ///
  /// In en, this message translates to:
  /// **'Debt aging'**
  String get agingTitle;

  /// No description provided for @agingHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customer dues by age: 0–30 / 31–60 / 61–90 / 90+ days (FIFO)'**
  String get agingHubSubtitle;

  /// No description provided for @agingAsOfLabel.
  ///
  /// In en, this message translates to:
  /// **'As of {date}'**
  String agingAsOfLabel(String date);

  /// No description provided for @agingCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Report currency'**
  String get agingCurrencyLabel;

  /// No description provided for @agingBucket0to30.
  ///
  /// In en, this message translates to:
  /// **'0–30 days'**
  String get agingBucket0to30;

  /// No description provided for @agingBucket31to60.
  ///
  /// In en, this message translates to:
  /// **'31–60 days'**
  String get agingBucket31to60;

  /// No description provided for @agingBucket61to90.
  ///
  /// In en, this message translates to:
  /// **'61–90 days'**
  String get agingBucket61to90;

  /// No description provided for @agingBucket90plus.
  ///
  /// In en, this message translates to:
  /// **'Over 90 days'**
  String get agingBucket90plus;

  /// No description provided for @agingTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Grand total'**
  String get agingTotalLabel;

  /// No description provided for @agingCustomersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No debtors} one{1 debtor} other{{count} debtors}}'**
  String agingCustomersCount(num count);

  /// No description provided for @agingNotYetDueLabel.
  ///
  /// In en, this message translates to:
  /// **'Not yet due:'**
  String get agingNotYetDueLabel;

  /// No description provided for @agingNoDebtsTitle.
  ///
  /// In en, this message translates to:
  /// **'No outstanding debts'**
  String get agingNoDebtsTitle;

  /// No description provided for @agingNoDebtsBody.
  ///
  /// In en, this message translates to:
  /// **'No unsettled credit amounts on any customer in this currency — everything is settled. Excellent!'**
  String get agingNoDebtsBody;

  /// No description provided for @agingInvoicesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 open invoice} other{{count} open invoices}}'**
  String agingInvoicesCount(num count);

  /// No description provided for @agingDueDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get agingDueDateLabel;

  /// No description provided for @agingDaysOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue by {count, plural, one{1 day} other{{count} days}}'**
  String agingDaysOverdue(num count);

  /// No description provided for @agingDueInDays.
  ///
  /// In en, this message translates to:
  /// **'Due in {count, plural, one{1 day} other{{count} days}}'**
  String agingDueInDays(num count);

  /// No description provided for @agingDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get agingDueToday;

  /// No description provided for @agingRemindTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send WhatsApp reminder'**
  String get agingRemindTooltip;

  /// No description provided for @agingNoPhone.
  ///
  /// In en, this message translates to:
  /// **'This customer has no WhatsApp or phone number — update their details first.'**
  String get agingNoPhone;

  /// No description provided for @agingWhatsAppFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open WhatsApp — make sure it is installed.'**
  String get agingWhatsAppFailed;

  /// No description provided for @agingStaleWarning.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed — showing the last successful report.'**
  String get agingStaleWarning;

  /// No description provided for @agingReminderCompanyFallback.
  ///
  /// In en, this message translates to:
  /// **'our company'**
  String get agingReminderCompanyFallback;

  /// No description provided for @agingReminderMessage.
  ///
  /// In en, this message translates to:
  /// **'Hello {name}, this is a kind reminder of the outstanding balance on your account with {company}, totaling {total}. Thank you for your understanding.'**
  String agingReminderMessage(String name, String company, String total);

  /// No description provided for @monthSalesTitle.
  ///
  /// In en, this message translates to:
  /// **'This month\'s sales'**
  String get monthSalesTitle;

  /// No description provided for @monthChangeUp.
  ///
  /// In en, this message translates to:
  /// **'Up {pct}% vs last month'**
  String monthChangeUp(String pct);

  /// No description provided for @monthChangeDown.
  ///
  /// In en, this message translates to:
  /// **'Down {pct}% vs last month'**
  String monthChangeDown(String pct);

  /// No description provided for @monthChangeFlat.
  ///
  /// In en, this message translates to:
  /// **'Level with last month'**
  String get monthChangeFlat;

  /// No description provided for @monthNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get monthNew;

  /// No description provided for @monthInvoices.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no invoices yet} one{one invoice} other{{count} invoices}}'**
  String monthInvoices(num count);

  /// No description provided for @topItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Top-selling items'**
  String get topItemsTitle;

  /// No description provided for @topItemsScope.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get topItemsScope;

  /// No description provided for @topItemsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sales this month yet'**
  String get topItemsEmpty;

  /// No description provided for @topItemsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Best sellers will appear here as soon as the first sale of this month is completed.'**
  String get topItemsEmptyBody;

  /// No description provided for @topItemsQtyCount.
  ///
  /// In en, this message translates to:
  /// **'Qty: {qty}'**
  String topItemsQtyCount(String qty);

  /// No description provided for @creditLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Credit limit exceeded'**
  String get creditLimitTitle;

  /// No description provided for @creditLimitExceeded.
  ///
  /// In en, this message translates to:
  /// **'This invoice will push the customer\'s balance beyond their allowed credit limit.'**
  String get creditLimitExceeded;

  /// No description provided for @creditLimitBlocked.
  ///
  /// In en, this message translates to:
  /// **'This credit sale cannot proceed: the resulting balance exceeds the credit limit (block mode is on).'**
  String get creditLimitBlocked;

  /// No description provided for @creditLimitLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Credit limit'**
  String get creditLimitLimitLabel;

  /// No description provided for @creditLimitCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current balance'**
  String get creditLimitCurrentLabel;

  /// No description provided for @creditLimitResultingLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance after this invoice'**
  String get creditLimitResultingLabel;

  /// No description provided for @creditLimitContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue anyway'**
  String get creditLimitContinue;

  /// No description provided for @creditLimitCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get creditLimitCancel;

  /// No description provided for @creditLimitBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get creditLimitBack;

  /// No description provided for @stocktakeTitle.
  ///
  /// In en, this message translates to:
  /// **'Physical stocktake'**
  String get stocktakeTitle;

  /// No description provided for @stocktakeHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Count & reconcile stock'**
  String get stocktakeHeroTitle;

  /// No description provided for @stocktakeHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Compare book stock with your physical count; differences are valued at the snapshot cost at posting time, and balances lock to the counted quantities.'**
  String get stocktakeHeroSubtitle;

  /// No description provided for @stocktakeWarehouseLabel.
  ///
  /// In en, this message translates to:
  /// **'Warehouse'**
  String get stocktakeWarehouseLabel;

  /// No description provided for @stocktakeCountedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Count date'**
  String get stocktakeCountedAtLabel;

  /// No description provided for @stocktakeCountedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Counted by'**
  String get stocktakeCountedByLabel;

  /// No description provided for @stocktakeCountedByHint.
  ///
  /// In en, this message translates to:
  /// **'The stocktake is signed with this name'**
  String get stocktakeCountedByHint;

  /// No description provided for @stocktakeNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get stocktakeNotesLabel;

  /// No description provided for @stocktakeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search items by name…'**
  String get stocktakeSearchHint;

  /// No description provided for @stocktakeBookQty.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get stocktakeBookQty;

  /// No description provided for @stocktakeCountedQty.
  ///
  /// In en, this message translates to:
  /// **'Counted'**
  String get stocktakeCountedQty;

  /// No description provided for @stocktakeUnitCost.
  ///
  /// In en, this message translates to:
  /// **'Unit cost'**
  String get stocktakeUnitCost;

  /// No description provided for @stocktakeSetBook.
  ///
  /// In en, this message translates to:
  /// **'Copy book qty'**
  String get stocktakeSetBook;

  /// No description provided for @stocktakeMatched.
  ///
  /// In en, this message translates to:
  /// **'Matched'**
  String get stocktakeMatched;

  /// No description provided for @stocktakeSurplus.
  ///
  /// In en, this message translates to:
  /// **'Surplus'**
  String get stocktakeSurplus;

  /// No description provided for @stocktakeShortage.
  ///
  /// In en, this message translates to:
  /// **'Shortage'**
  String get stocktakeShortage;

  /// No description provided for @stocktakeNetDiff.
  ///
  /// In en, this message translates to:
  /// **'Net difference'**
  String get stocktakeNetDiff;

  /// No description provided for @stocktakeCountedProgress.
  ///
  /// In en, this message translates to:
  /// **'Counted {counted} of {total}'**
  String stocktakeCountedProgress(int counted, int total);

  /// No description provided for @stocktakePost.
  ///
  /// In en, this message translates to:
  /// **'Approve stocktake'**
  String get stocktakePost;

  /// No description provided for @stocktakeHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Stocktake history'**
  String get stocktakeHistoryTitle;

  /// No description provided for @stocktakeHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No stocktakes for this warehouse yet — the first one will appear here.'**
  String get stocktakeHistoryEmpty;

  /// No description provided for @stocktakeHistoryLines.
  ///
  /// In en, this message translates to:
  /// **'{count} lines'**
  String stocktakeHistoryLines(int count);

  /// No description provided for @stocktakeReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review stocktake differences'**
  String get stocktakeReviewTitle;

  /// No description provided for @stocktakeReviewNoDiffs.
  ///
  /// In en, this message translates to:
  /// **'No differences — everything counted matches the books.'**
  String get stocktakeReviewNoDiffs;

  /// No description provided for @stocktakeReviewWarning.
  ///
  /// In en, this message translates to:
  /// **'After approval, balances lock to the counted quantities and differences post as stocktake movements at snapshot cost — this cannot be undone.'**
  String get stocktakeReviewWarning;

  /// No description provided for @stocktakeReviewSkipNote.
  ///
  /// In en, this message translates to:
  /// **'{count} uncounted item(s) will be skipped from this stocktake.'**
  String stocktakeReviewSkipNote(int count);

  /// No description provided for @stocktakeConfirmPost.
  ///
  /// In en, this message translates to:
  /// **'Confirm & post'**
  String get stocktakeConfirmPost;

  /// No description provided for @stocktakeSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Stocktake approved'**
  String get stocktakeSuccessTitle;

  /// No description provided for @stocktakeSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Balances locked to the counted quantities and adjustments posted as signed stocktake movements.'**
  String get stocktakeSuccessBody;

  /// No description provided for @stocktakeSuccessDiffs.
  ///
  /// In en, this message translates to:
  /// **'Difference lines'**
  String get stocktakeSuccessDiffs;

  /// No description provided for @stocktakeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Warehouse is empty'**
  String get stocktakeEmptyTitle;

  /// No description provided for @stocktakeEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No stock items in this warehouse — add items first, then run a stocktake.'**
  String get stocktakeEmptyBody;

  /// No description provided for @stocktakeNoWarehouseTitle.
  ///
  /// In en, this message translates to:
  /// **'No warehouses'**
  String get stocktakeNoWarehouseTitle;

  /// No description provided for @stocktakeNoWarehouseBody.
  ///
  /// In en, this message translates to:
  /// **'Create a warehouse first, then start counting.'**
  String get stocktakeNoWarehouseBody;

  /// No description provided for @stocktakeSearchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get stocktakeSearchEmptyTitle;

  /// No description provided for @stocktakeSearchEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try another name or clear the search.'**
  String get stocktakeSearchEmptyBody;

  /// No description provided for @profitTitle.
  ///
  /// In en, this message translates to:
  /// **'Profit & loss'**
  String get profitTitle;

  /// No description provided for @profitSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get profitSales;

  /// No description provided for @profitSalesReturns.
  ///
  /// In en, this message translates to:
  /// **'Sales returns'**
  String get profitSalesReturns;

  /// No description provided for @profitCogs.
  ///
  /// In en, this message translates to:
  /// **'Cost of goods sold (COGS)'**
  String get profitCogs;

  /// No description provided for @profitReturnCost.
  ///
  /// In en, this message translates to:
  /// **'Returned goods cost'**
  String get profitReturnCost;

  /// No description provided for @profitStockSurplus.
  ///
  /// In en, this message translates to:
  /// **'Stock surplus'**
  String get profitStockSurplus;

  /// No description provided for @profitStockShortage.
  ///
  /// In en, this message translates to:
  /// **'Stock shortage'**
  String get profitStockShortage;

  /// No description provided for @profitExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get profitExpenses;

  /// No description provided for @profitFx.
  ///
  /// In en, this message translates to:
  /// **'Realized FX gains/losses'**
  String get profitFx;

  /// No description provided for @profitOwnerDrawings.
  ///
  /// In en, this message translates to:
  /// **'Owner drawings'**
  String get profitOwnerDrawings;

  /// No description provided for @profitOwnerSection.
  ///
  /// In en, this message translates to:
  /// **'Owner drawings (outside expenses)'**
  String get profitOwnerSection;

  /// No description provided for @profitNetSales.
  ///
  /// In en, this message translates to:
  /// **'Net sales'**
  String get profitNetSales;

  /// No description provided for @profitNetCogs.
  ///
  /// In en, this message translates to:
  /// **'Net cost'**
  String get profitNetCogs;

  /// No description provided for @profitTotal.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get profitTotal;

  /// No description provided for @profitNetForOwner.
  ///
  /// In en, this message translates to:
  /// **'Net left for the owner'**
  String get profitNetForOwner;

  /// No description provided for @profitSectionRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get profitSectionRevenue;

  /// No description provided for @profitSectionCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get profitSectionCost;

  /// No description provided for @profitSectionAdjustments.
  ///
  /// In en, this message translates to:
  /// **'Adjustments (stock & FX)'**
  String get profitSectionAdjustments;

  /// No description provided for @profitSectionExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get profitSectionExpenses;

  /// No description provided for @profitEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No activity in this period'**
  String get profitEmptyTitle;

  /// No description provided for @profitEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No sales, expenses or adjustments were recorded within this period — try widening it or record your first activity.'**
  String get profitEmptyBody;

  /// No description provided for @profitBaseCurrencyNote.
  ///
  /// In en, this message translates to:
  /// **'All amounts are in the base currency'**
  String get profitBaseCurrencyNote;

  /// No description provided for @profitGeneratedAt.
  ///
  /// In en, this message translates to:
  /// **'Generated at {time}'**
  String profitGeneratedAt(Object time);

  /// No description provided for @profitPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Period: {from} → {to}'**
  String profitPeriodLabel(Object from, Object to);

  /// No description provided for @profitInvoicesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no invoices} one{one invoice} other{{count} invoices}}'**
  String profitInvoicesCount(num count);

  /// No description provided for @profitStaleWarning.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed — showing the last loaded copy'**
  String get profitStaleWarning;

  /// No description provided for @profitPdfButton.
  ///
  /// In en, this message translates to:
  /// **'PDF report'**
  String get profitPdfButton;

  /// No description provided for @profitPdfTitle.
  ///
  /// In en, this message translates to:
  /// **'Profit & loss report'**
  String get profitPdfTitle;

  /// No description provided for @profitPrintItemCol.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get profitPrintItemCol;

  /// No description provided for @profitPrintValueCol.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get profitPrintValueCol;

  /// No description provided for @profitPrintFooterNote.
  ///
  /// In en, this message translates to:
  /// **'Derived exclusively from the Posting Map (Annex W)'**
  String get profitPrintFooterNote;

  /// No description provided for @profitPrintShareMessage.
  ///
  /// In en, this message translates to:
  /// **'Profit & loss report ({from} → {to}) — profit {profit} {currency}'**
  String profitPrintShareMessage(
    Object currency,
    Object from,
    Object profit,
    Object to,
  );

  /// No description provided for @periodToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get periodToday;

  /// No description provided for @periodWeek.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get periodMonth;

  /// No description provided for @periodQuarter.
  ///
  /// In en, this message translates to:
  /// **'This quarter'**
  String get periodQuarter;

  /// No description provided for @periodYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get periodYear;

  /// No description provided for @periodCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom range'**
  String get periodCustom;

  /// No description provided for @periodCustomHint.
  ///
  /// In en, this message translates to:
  /// **'Pick the start and end dates'**
  String get periodCustomHint;

  /// No description provided for @periodFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get periodFrom;

  /// No description provided for @periodTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get periodTo;

  /// No description provided for @periodCustomRange.
  ///
  /// In en, this message translates to:
  /// **'{from} → {to}'**
  String periodCustomRange(Object from, Object to);

  /// No description provided for @invoiceProfitSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice profit'**
  String get invoiceProfitSectionTitle;

  /// No description provided for @invoiceProfitManagerHint.
  ///
  /// In en, this message translates to:
  /// **'Manager only'**
  String get invoiceProfitManagerHint;

  /// No description provided for @invoiceCostLabel.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get invoiceCostLabel;

  /// No description provided for @invoiceProfitLabel.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get invoiceProfitLabel;

  /// No description provided for @invoiceMarginLabel.
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get invoiceMarginLabel;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @reportsHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports & Control Center'**
  String get reportsHeroTitle;

  /// No description provided for @reportsHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Numbers from a single source of truth — derived exclusively via the Posting Map'**
  String get reportsHeroSubtitle;

  /// No description provided for @reportsSectionFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance & Profit'**
  String get reportsSectionFinance;

  /// No description provided for @reportsSectionDebts.
  ///
  /// In en, this message translates to:
  /// **'Debts & Collection'**
  String get reportsSectionDebts;

  /// No description provided for @reportsSectionInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory & Control'**
  String get reportsSectionInventory;

  /// No description provided for @reportsPnlDesc.
  ///
  /// In en, this message translates to:
  /// **'The binding formula via the Posting Map with net-remaining-for-owner'**
  String get reportsPnlDesc;

  /// No description provided for @reportsStocktakeDesc.
  ///
  /// In en, this message translates to:
  /// **'Compare book vs counted and settle diffs at snapshot cost'**
  String get reportsStocktakeDesc;

  /// No description provided for @itemMovementTitle.
  ///
  /// In en, this message translates to:
  /// **'Item movement'**
  String get itemMovementTitle;

  /// No description provided for @itemMovementPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a product first'**
  String get itemMovementPickTitle;

  /// No description provided for @itemMovementPickBody.
  ///
  /// In en, this message translates to:
  /// **'Show every movement of the product in the period with the running balance after each entry.'**
  String get itemMovementPickBody;

  /// No description provided for @itemMovementPickButton.
  ///
  /// In en, this message translates to:
  /// **'Choose product'**
  String get itemMovementPickButton;

  /// No description provided for @itemMovementChangeProduct.
  ///
  /// In en, this message translates to:
  /// **'Change product'**
  String get itemMovementChangeProduct;

  /// No description provided for @itemMovementPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose product'**
  String get itemMovementPickerTitle;

  /// No description provided for @itemMovementPickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or barcode'**
  String get itemMovementPickerSearchHint;

  /// No description provided for @itemMovementPickerNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching results'**
  String get itemMovementPickerNoResults;

  /// No description provided for @itemMovementOpeningBalance.
  ///
  /// In en, this message translates to:
  /// **'Opening balance (before period)'**
  String get itemMovementOpeningBalance;

  /// No description provided for @itemMovementTotalIn.
  ///
  /// In en, this message translates to:
  /// **'Total in'**
  String get itemMovementTotalIn;

  /// No description provided for @itemMovementTotalOut.
  ///
  /// In en, this message translates to:
  /// **'Total out'**
  String get itemMovementTotalOut;

  /// No description provided for @itemMovementWacNow.
  ///
  /// In en, this message translates to:
  /// **'Current unit cost'**
  String get itemMovementWacNow;

  /// No description provided for @itemMovementBalanceAfter.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get itemMovementBalanceAfter;

  /// No description provided for @itemMovementMovementCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No movements} one{One movement} two{Two movements} few{{count} movements} many{{count} movements} other{{count} movements}}'**
  String itemMovementMovementCount(num count);

  /// No description provided for @itemMovementUnitCost.
  ///
  /// In en, this message translates to:
  /// **'Unit cost'**
  String get itemMovementUnitCost;

  /// No description provided for @itemMovementPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Period: {from} to {to}'**
  String itemMovementPeriodLabel(Object from, Object to);

  /// No description provided for @itemMovementEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No movements in this period'**
  String get itemMovementEmptyTitle;

  /// No description provided for @itemMovementEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'This product did not move between the selected dates — try widening the period.'**
  String get itemMovementEmptyBody;

  /// No description provided for @stockSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock movement summary'**
  String get stockSummaryTitle;

  /// No description provided for @stockSummaryTotalItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No moving products} one{One moving product} two{Two moving products} few{{count} moving products} many{{count} moving products} other{{count} moving products}}'**
  String stockSummaryTotalItems(num count);

  /// No description provided for @stockSummaryTotalValue.
  ///
  /// In en, this message translates to:
  /// **'Total inventory value at cost'**
  String get stockSummaryTotalValue;

  /// No description provided for @stockSummaryQtyIn.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get stockSummaryQtyIn;

  /// No description provided for @stockSummaryQtyOut.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get stockSummaryQtyOut;

  /// No description provided for @stockSummaryQtyReturns.
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get stockSummaryQtyReturns;

  /// No description provided for @stockSummaryQtyAdjust.
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get stockSummaryQtyAdjust;

  /// No description provided for @stockSummaryEndBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get stockSummaryEndBalance;

  /// No description provided for @stockSummaryValueAtCost.
  ///
  /// In en, this message translates to:
  /// **'Value at cost'**
  String get stockSummaryValueAtCost;

  /// No description provided for @stockSummaryPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Period: {from} to {to}'**
  String stockSummaryPeriodLabel(Object from, Object to);

  /// No description provided for @stockSummaryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No stock movement in this period'**
  String get stockSummaryEmptyTitle;

  /// No description provided for @stockSummaryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No stock movements recorded between the selected dates — try widening the period.'**
  String get stockSummaryEmptyBody;

  /// No description provided for @salesByTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales by'**
  String get salesByTitle;

  /// No description provided for @salesByCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get salesByCustomer;

  /// No description provided for @salesByCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get salesByCategory;

  /// No description provided for @salesByItem.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get salesByItem;

  /// No description provided for @salesByDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get salesByDay;

  /// No description provided for @salesByNoCustomer.
  ///
  /// In en, this message translates to:
  /// **'Walk-in (no customer)'**
  String get salesByNoCustomer;

  /// No description provided for @salesByUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get salesByUncategorized;

  /// No description provided for @salesByInvoicesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No invoices} one{One invoice} two{Two invoices} few{{count} invoices} many{{count} invoices} other{{count} invoices}}'**
  String salesByInvoicesCount(num count);

  /// No description provided for @salesByTotal.
  ///
  /// In en, this message translates to:
  /// **'Total sales'**
  String get salesByTotal;

  /// No description provided for @salesByChangeNote.
  ///
  /// In en, this message translates to:
  /// **'Percentages compare against an equal-length period immediately before the selected one.'**
  String get salesByChangeNote;

  /// No description provided for @salesByPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Period: {from} to {to}'**
  String salesByPeriodLabel(Object from, Object to);

  /// No description provided for @salesByEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No sales in this period'**
  String get salesByEmptyTitle;

  /// No description provided for @salesByEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No completed sale invoices between the selected dates — try widening the period.'**
  String get salesByEmptyBody;

  /// No description provided for @changeUp.
  ///
  /// In en, this message translates to:
  /// **'Up {pct}%'**
  String changeUp(Object pct);

  /// No description provided for @changeDown.
  ///
  /// In en, this message translates to:
  /// **'Down {pct}%'**
  String changeDown(Object pct);

  /// No description provided for @changeNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get changeNew;

  /// No description provided for @movementTypePurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get movementTypePurchase;

  /// No description provided for @movementTypeSale.
  ///
  /// In en, this message translates to:
  /// **'Sale'**
  String get movementTypeSale;

  /// No description provided for @movementTypeSaleReturn.
  ///
  /// In en, this message translates to:
  /// **'Sale return'**
  String get movementTypeSaleReturn;

  /// No description provided for @movementTypePurchaseReturn.
  ///
  /// In en, this message translates to:
  /// **'Purchase return'**
  String get movementTypePurchaseReturn;

  /// No description provided for @movementTypeAdjust.
  ///
  /// In en, this message translates to:
  /// **'Stocktake adjustment'**
  String get movementTypeAdjust;

  /// No description provided for @movementTypeOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get movementTypeOpening;

  /// No description provided for @movementTypeTransferIn.
  ///
  /// In en, this message translates to:
  /// **'Transfer in'**
  String get movementTypeTransferIn;

  /// No description provided for @movementTypeTransferOut.
  ///
  /// In en, this message translates to:
  /// **'Transfer out'**
  String get movementTypeTransferOut;

  /// No description provided for @reportsSectionFlows.
  ///
  /// In en, this message translates to:
  /// **'Inventory & Sales Flows'**
  String get reportsSectionFlows;

  /// No description provided for @reportsItemMovementDesc.
  ///
  /// In en, this message translates to:
  /// **'Full item card with running balance per movement'**
  String get reportsItemMovementDesc;

  /// No description provided for @reportsStockSummaryDesc.
  ///
  /// In en, this message translates to:
  /// **'In/out/returns/adjustments per item with stock value'**
  String get reportsStockSummaryDesc;

  /// No description provided for @reportsSalesByDesc.
  ///
  /// In en, this message translates to:
  /// **'Customer/category/item/day with change vs previous period'**
  String get reportsSalesByDesc;
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
