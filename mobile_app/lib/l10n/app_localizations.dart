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
