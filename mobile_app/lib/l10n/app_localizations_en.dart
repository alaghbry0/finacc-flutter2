// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Personal Accountant';

  @override
  String get appBrand => 'FinAcc';

  @override
  String get brandTagline =>
      'Complete accounting & inventory system — works fully offline';

  @override
  String get commonNext => 'Next';

  @override
  String get commonBack => 'Back';

  @override
  String get commonDone => 'Done';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonDetails => 'Details';

  @override
  String get commonViewAll => 'View all';

  @override
  String get splashLoading => 'Preparing your local database…';

  @override
  String get onboardWelcomeTitle => 'Welcome to Personal Accountant';

  @override
  String get onboardWelcomeMessage =>
      'A complete accounting and inventory system for your shop — your data stays on your device, offline, no subscriptions.';

  @override
  String get onboardFeature1Title => 'Works 100% offline';

  @override
  String get onboardFeature1Desc =>
      'Sell, buy, stocktake and report — even with no network at all.';

  @override
  String get onboardFeature2Title => 'Numbers you can trust';

  @override
  String get onboardFeature2Desc =>
      'Atomic document numbering that never repeats, weighted-average cost, and hard protection against negative stock.';

  @override
  String get onboardFeature3Title => 'Full privacy';

  @override
  String get onboardFeature3Desc =>
      'No data ever leaves to any server — your backups belong to you.';

  @override
  String get onboardStepCompany => 'Company details';

  @override
  String get onboardStepSecurity => 'Security';

  @override
  String get onboardStepReview => 'Ready';

  @override
  String get companyNameLabel => 'Company name';

  @override
  String get companyNameHint => 'As it appears to customers on invoices';

  @override
  String get companyPhoneLabel => 'Phone (optional)';

  @override
  String get companyPhoneHint => 'For WhatsApp support and reminders later';

  @override
  String get baseCurrencyLabel => 'Base currency';

  @override
  String get baseCurrencyHint =>
      'Fixed after setup — other currencies get daily rates';

  @override
  String baseCurrencyDecimalsNote(num decimals) {
    String _temp0 = intl.Intl.pluralLogic(
      decimals,
      locale: localeName,
      other: 'decimal places: $decimals',
      one: 'one decimal place',
      zero: 'no decimals',
    );
    return '$_temp0';
  }

  @override
  String get companyFormInvalid =>
      'Complete the company name and choose a base currency';

  @override
  String get pinSetupTitle => 'Your PIN code';

  @override
  String get pinSetupSubtitle =>
      '4 to 6 digits — asked every time the app opens';

  @override
  String get pinConfirmTitle => 'Confirm the code';

  @override
  String get pinConfirmSubtitle => 'Re-enter the same code to confirm';

  @override
  String get pinMismatch => 'The codes do not match. Try again.';

  @override
  String get pinInvalidLength => 'The code must be 4 to 6 digits.';

  @override
  String get passphraseTitle => 'Recovery passphrase';

  @override
  String get passphraseSubtitle =>
      'Recovery gate when the PIN is forgotten (after 10 wrong attempts) — it can never be recovered';

  @override
  String get passphraseLabel => 'Passphrase (8 characters or more)';

  @override
  String get passphraseConfirmLabel => 'Confirm passphrase';

  @override
  String get passphraseMismatch => 'The passphrases do not match. Try again.';

  @override
  String get passphraseWarningTitle => 'Important — read before continuing';

  @override
  String get passphraseWarningBody =>
      'Forgetting the passphrase means permanent loss of access; the only recovery is a backup file you keep. Store it safely and enable backups early.';

  @override
  String get passphraseShort => 'The passphrase must be at least 8 characters.';

  @override
  String get creatingTitle => 'Setting up your shop…';

  @override
  String get creatingMessage =>
      'Creating the company, main warehouse, main cashbox and fiscal year inside one safe transaction — any failure rolls everything back.';

  @override
  String get createdTitle => 'Setup complete';

  @override
  String createdMessage(Object cashbox, Object warehouse) {
    return 'We created “$warehouse” and “$cashbox”, ready for your first invoice — no mandatory setup remains.';
  }

  @override
  String get startUsing => 'Start using';

  @override
  String get setupFailedTitle => 'Setup could not complete';

  @override
  String get setupFailedBody =>
      'Review the details and try again — nothing was written to the database.';

  @override
  String get lockTitle => 'Enter your PIN';

  @override
  String get lockSubtitle => 'The app is locked to protect your financial data';

  @override
  String get lockWrong => 'Incorrect code';

  @override
  String lockAttemptsBeforeLock(Object count) {
    return '$count attempts left before a temporary delay';
  }

  @override
  String lockDelayedMessage(Object duration) {
    return 'Wait $duration then try again';
  }

  @override
  String get lockPassphraseTitle => 'Passphrase required';

  @override
  String get lockPassphraseMessage =>
      'All ten PIN attempts are used. Enter the passphrase you chose during setup to regain access.';

  @override
  String get lockPassphraseFieldLabel => 'Passphrase';

  @override
  String get lockPassphraseFailed => 'Incorrect passphrase.';

  @override
  String get lockUnlockButton => 'Unlock';

  @override
  String get lockUsePassphrase => 'Use passphrase';

  @override
  String get lockBackToPin => 'Back to PIN';

  @override
  String get lockVerifying => 'Verifying…';

  @override
  String get wipeDialogTitle => 'Wipe all data?';

  @override
  String get wipeDialogBody =>
      'Everything will be permanently erased — invoices, items, balances and settings — and the app returns to first-install state. This cannot be undone.';

  @override
  String get wipeConfirmWord => 'wipe';

  @override
  String get wipeFinalTitle => 'Final confirmation';

  @override
  String get wipeFinalBody =>
      'Type “wipe” exactly to confirm erasing the whole database. If you have a backup file it stays safe outside the app.';

  @override
  String get wipeDoneTitle => 'Data wiped';

  @override
  String get wipeDoneBody => 'The app will now reopen on the setup screen.';

  @override
  String get dashboardTitle => 'Home';

  @override
  String get morningGreeting => 'Good morning';

  @override
  String get eveningGreeting => 'Good evening';

  @override
  String get todaySales => 'Today\'s sales';

  @override
  String get todayProfit => 'Today\'s profit';

  @override
  String get todayInvoices => 'Today\'s invoices';

  @override
  String get netCash => 'Net cash';

  @override
  String get last30DaysTitle => 'Last 30 days of sales';

  @override
  String get chartEmptyMessage =>
      'Your sales will appear here after the first invoice';

  @override
  String get stockAlertsTitle => 'Stock alerts';

  @override
  String get stockAlertsEmpty =>
      'No alerts — all items are above their minimum';

  @override
  String stockAlertsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: 'one item',
      zero: 'no items',
    );
    return '$_temp0 below minimum';
  }

  @override
  String get tabHome => 'Home';

  @override
  String get tabSell => 'Sell';

  @override
  String get tabInventory => 'Inventory';

  @override
  String get tabCash => 'Cash';

  @override
  String get tabMore => 'More';

  @override
  String get comingSoonTitle => 'Coming in the next slices';

  @override
  String comingSoonBody(Object feature) {
    return 'The “$feature” module is built in its dedicated slice after phase one approval — the architecture and database are already ready for it.';
  }

  @override
  String get comingGatedBadge => 'Awaiting phase-one approval';

  @override
  String get featureSell => 'Selling & POS';

  @override
  String get featureInventory => 'Items, stock & batches';

  @override
  String get featureCash => 'Cashboxes & cash';

  @override
  String get featureMore => 'Parties, reports & settings';

  @override
  String get comingSellH1 => 'A fast POS — one or two taps per item';

  @override
  String get comingSellH2 =>
      'Credit invoices and full installment plans with guard policies';

  @override
  String get comingInventoryH1 =>
      'Items with weighted-average cost and barcode cards';

  @override
  String get comingInventoryH2 =>
      'Supply batches, FEFO expiry dates, and negative-stock protection';

  @override
  String get comingCashH1 =>
      'Receipt and payment movements across multiple cashboxes';

  @override
  String get comingCashH2 =>
      'Reconciliations and end-of-day balances in all currencies';

  @override
  String get comingMoreH1 =>
      'Parties (customers/suppliers) with governed credit limits';

  @override
  String get comingMoreH2 => 'Reports, analytics, and scheduled backups';

  @override
  String get settingsBaseCurrency => 'Base currency';

  @override
  String get settingsAdmin => 'Admin';

  @override
  String get settingsAutolock => 'Auto-lock after';

  @override
  String settingsAutolackValue(num minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: 'one minute',
    );
    return '$_temp0 of inactivity';
  }

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsChangePin => 'Change PIN';

  @override
  String get settingsChangePinDesc =>
      'Verify your current PIN, then set a new one';

  @override
  String get settingsLockNow => 'Lock the app now';

  @override
  String get settingsLockNowDesc => 'Returns to the sign-in screen immediately';

  @override
  String get settingsTheme => 'Appearance';

  @override
  String get themeSystem => 'Auto (follow system)';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsThemeNote =>
      'Your choice is stored in your local database and survives restarts.';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsWipe => 'Erase all data';

  @override
  String get settingsWipeDesc =>
      'Resets the app to first-install state — irreversible';

  @override
  String get settingsAboutPhase1 => 'Phase 1 complete';

  @override
  String get settingsAboutVersion => 'Version 1.0.0 — Slice 0 + Slice 1';

  @override
  String get settingsAboutSrs =>
      'Built per the approved SRS v1.5 specification';

  @override
  String get changePinStep1Label => 'Current';

  @override
  String get changePinStep2Label => 'New';

  @override
  String get changePinStep3Label => 'Confirm';

  @override
  String get changePinStepCurrent => 'Enter your current PIN to continue';

  @override
  String get changePinStepNew => 'Choose a new PIN of 4 to 6 digits';

  @override
  String get changePinStepConfirm => 'Re-enter the new PIN to confirm';

  @override
  String get changePinDoneTitle => 'PIN changed successfully';

  @override
  String get changePinDoneBody =>
      'Use the new PIN to unlock the app from now on — the change has been recorded in the audit log.';

  @override
  String get changePinWrongCurrent => 'Current PIN is incorrect — try again';

  @override
  String get changePinSameAsCurrent =>
      'The new PIN matches the current one — choose a different PIN';

  @override
  String get changePinNoPin => 'No PIN is configured — set up the app again';

  @override
  String get dbOpenErrorTitle => 'Could not open the database';

  @override
  String get dbOpenErrorMessage =>
      'The database file may be busy or storage is full. Try again — your data is unaffected.';

  @override
  String get genericErrorTitle => 'An unexpected error occurred';

  @override
  String get loadingData => 'Loading…';

  @override
  String get settingsAutolockSheetTitle => 'Auto-lock delay';

  @override
  String get settingsAutolockSheetSubtitle =>
      'The app locks after this idle period — allowed range is 1 to 60 minutes.';

  @override
  String get settingsNumerals => 'Numerals';

  @override
  String get numeralsWestern => 'Western';

  @override
  String get numeralsArabicIndic => 'Eastern Arabic';

  @override
  String get settingsNumeralsNote =>
      'Applies instantly to amounts and dates across the app — storage always stays in western digits.';

  @override
  String get settingsAuditLog => 'Audit log';

  @override
  String get settingsAuditLogDesc => 'Extended security events — append-only';

  @override
  String get auditTitle => 'Audit log';

  @override
  String get auditProtectedTitle => 'Protected inside your database';

  @override
  String get auditProtectedBody =>
      'Critical security events are recorded here and can never be edited or deleted from the app — the protection itself lives inside the database file (triggers block updates and deletes from any tool).';

  @override
  String get auditAppendOnlyBadge => 'Append-only';

  @override
  String get auditEmptyTitle => 'No events recorded yet';

  @override
  String get auditEmptyBody =>
      'Critical security events appear here: setup, PIN changes, lockout thresholds, and security settings changes.';

  @override
  String get auditDayToday => 'Today';

  @override
  String get auditDayYesterday => 'Yesterday';

  @override
  String get auditActionAppSetup => 'App setup';

  @override
  String get auditActionPinChange => 'PIN changed';

  @override
  String get auditActionLockoutDelay =>
      'Attempt limit exceeded — temporary delay';

  @override
  String get auditActionLockoutPassphrase =>
      'Attempts exhausted — passphrase required';

  @override
  String get auditActionSettingsChange => 'Security setting changed';

  @override
  String auditActionUnknown(Object action) {
    return 'Event: $action';
  }

  @override
  String auditLoadMore(Object shown, Object total) {
    return 'Load more ($shown of $total)';
  }
}
