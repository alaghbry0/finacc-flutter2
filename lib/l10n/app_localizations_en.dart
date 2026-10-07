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
  String get dashboardQuickAccess => 'Quick access';

  @override
  String get dashboardQuickRates => 'Rates';

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

  @override
  String get auditFilterAll => 'All';

  @override
  String get auditFilterSetup => 'Setup';

  @override
  String get auditFilterSecurity => 'Security';

  @override
  String get auditFilterSettings => 'Settings';

  @override
  String get auditFilterOther => 'Other';

  @override
  String get auditFilterEmptyTitle => 'No events in this category';

  @override
  String get auditFilterEmptyBody =>
      'Pick another category or clear the filter to see all recorded events.';

  @override
  String auditCountsAll(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
      zero: 'No events',
    );
    return '$_temp0';
  }

  @override
  String get settingsLicenses => 'Open-source licenses';

  @override
  String get settingsLicensesDesc => 'Open-source components inside the app';

  @override
  String get dateSheetTitle => 'Today\'s date';

  @override
  String get dateSheetTodayBadge => 'Today';

  @override
  String get dateSheetHijriLabel => 'Hijri calendar';

  @override
  String get dateSheetGregorianLabel => 'Gregorian calendar';

  @override
  String get dateSheetWeekdayLabel => 'Weekday';

  @override
  String get commonAdd => 'Add';

  @override
  String get inventoryHomeHeroTitle => 'Inventory management';

  @override
  String get inventoryHomeHeroSubtitle =>
      'Your items, batches and stock in one place — classify, track and get alerted before running out';

  @override
  String get inventoryHubAddItem => 'Add a new item';

  @override
  String get inventoryHubAddItemDesc =>
      'Name, barcode, category and prices in all currencies';

  @override
  String get inventoryHubItems => 'Available items';

  @override
  String get inventoryHubItemsDesc =>
      'Instant search by name or barcode with category filters';

  @override
  String get inventoryHubLowStock => 'Items running low';

  @override
  String get inventoryHubLowStockDesc =>
      'Every item at or below its reorder level — full outages included';

  @override
  String get inventoryHubBatches => 'Batches & expiry dates';

  @override
  String get inventoryHubBatchesDesc =>
      'FEFO alerts for expired and soon-to-expire batches';

  @override
  String get inventoryHubImport => 'Import items from a file';

  @override
  String get inventoryHubImportDesc =>
      'CSV or Excel with validation and review before insert';

  @override
  String get inventoryHubCategoriesUnits => 'Categories & units';

  @override
  String get inventoryHubCategoriesUnitsDesc =>
      'Two-level category tree and units with conversion factors';

  @override
  String get itemsListTitle => 'Available items';

  @override
  String itemsListSubtitleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'No items yet',
    );
    return '$_temp0';
  }

  @override
  String itemsListSubtitleApprox(Object count) {
    return 'More than $count items';
  }

  @override
  String get itemsListSearchHint => 'Search by name or barcode';

  @override
  String get itemsListFilterAll => 'All';

  @override
  String get itemsListStockLabel => 'In stock';

  @override
  String get itemsListPriceLabel => 'Price';

  @override
  String get itemsListOutOfStockBadge => 'Out of stock';

  @override
  String get itemsListLowStockBadge => 'Running low';

  @override
  String get itemServiceBadge => 'Service';

  @override
  String get itemBatchesBadge => 'Batches';

  @override
  String get itemsListAddTooltip => 'Add a new item';

  @override
  String itemsListLoadMore(Object shown) {
    return 'Load more ($shown)';
  }

  @override
  String get itemsListEmptyTitle => 'No items yet';

  @override
  String get itemsListEmptyBody =>
      'Create your first item to track its stock and prices, or import a ready list from a CSV or Excel file.';

  @override
  String get itemsListEmptyAction => 'Add first item';

  @override
  String get itemsListSearchEmptyTitle => 'No matching results';

  @override
  String get itemsListSearchEmptyBody =>
      'Try another keyword or clear the search to see all items.';

  @override
  String get itemFormAddTitle => 'Add a new item';

  @override
  String get itemFormEditTitle => 'Edit item';

  @override
  String get itemFormEditNote =>
      'Stock is not edited here — the opening quantity is entered on creation only; afterwards it changes through purchase, sale and stocktake movements.';

  @override
  String get itemFormNameLabel => 'Item name';

  @override
  String get itemFormNameHint => 'As it appears on invoices and in search';

  @override
  String get itemFormNameRequired => 'Item name is required';

  @override
  String get itemFormBarcodeLabel => 'Barcode';

  @override
  String get itemFormBarcodeHint =>
      'Leave empty to auto-generate an EAN-13 on save';

  @override
  String get itemFormBarcodeGenerate => 'Generate';

  @override
  String get itemFormBarcodeRegenerate => 'Regenerate';

  @override
  String get itemFormBarcodeQrToggle => 'QR';

  @override
  String get itemFormBarcodeEanToggle => 'EAN';

  @override
  String get itemFormCode128Caption => 'Code128 — supplier barcode';

  @override
  String get itemFormCategoryLabel => 'Category';

  @override
  String get itemFormCategoryNone => 'No category';

  @override
  String get itemFormCategoryAdd => 'New category…';

  @override
  String get itemFormUnitLabel => 'Unit of measure';

  @override
  String get itemFormUnitNone => 'No unit';

  @override
  String get itemFormUnitAdd => 'New unit…';

  @override
  String get itemFormCostLabel => 'Cost price';

  @override
  String get itemFormCostInvalid => 'Enter a valid cost price (zero or more)';

  @override
  String get itemFormMinStockLabel => 'Reorder level';

  @override
  String get itemFormMinStockHint => 'Alert when stock falls below this level';

  @override
  String get itemFormMinStockInvalid => 'Enter a valid level (zero or more)';

  @override
  String get itemFormOpeningQtyLabel => 'Opening quantity';

  @override
  String get itemFormOpeningQtyHint =>
      'Recorded as an opening balance in the main warehouse';

  @override
  String get itemFormOpeningQtyInvalid =>
      'Enter a valid quantity (zero or more)';

  @override
  String get itemFormServiceLabel => 'Service item';

  @override
  String get itemFormServiceDesc =>
      'No stock or quantity — e.g. delivery or installation';

  @override
  String get itemFormTrackBatchesLabel => 'Track batches & expiry';

  @override
  String get itemFormTrackBatchesDesc =>
      'Quantity is managed in FEFO-ordered batches with expiry dates — record batches from the item card after saving.';

  @override
  String get itemFormPricesSection => 'Sale prices';

  @override
  String itemFormPriceLabel(Object currency) {
    return 'Sale price — $currency';
  }

  @override
  String get itemFormPriceInvalid => 'Enter a valid price (zero or more)';

  @override
  String get itemFormNotesLabel => 'Notes';

  @override
  String get itemFormNotesHint => 'Optional — shown on the item card';

  @override
  String get itemFormSave => 'Save data';

  @override
  String get itemFormSaving => 'Saving…';

  @override
  String get itemFormSavedMessage => 'Item saved successfully';

  @override
  String get categoryNameLabel => 'Category name';

  @override
  String get categoryParentLabel => 'Parent category';

  @override
  String get categoryParentNone => '— top-level —';

  @override
  String get unitNameLabel => 'Unit name';

  @override
  String get unitFactorLabel => 'Conversion factor';

  @override
  String get unitFactorHint => 'Example: 1 carton = 24 pieces → enter 24';

  @override
  String get unitFactorInvalid =>
      'The conversion factor must be a number greater than zero';

  @override
  String get itemDetailTitle => 'Item card';

  @override
  String get itemDetailArchivedBadge => 'Archived';

  @override
  String get itemDetailBatchesBadge => 'FEFO batches';

  @override
  String get itemDetailCostLabel => 'Cost';

  @override
  String get itemDetailPricesSection => 'Sale prices';

  @override
  String get itemDetailStockSection => 'Stock';

  @override
  String get itemDetailTotalLabel => 'Total';

  @override
  String get itemDetailMinStockLabel => 'Reorder level';

  @override
  String get itemDetailServiceNote =>
      'Service item — no stock or quantities are tracked.';

  @override
  String get itemDetailBatchesSection =>
      'Batches — earliest expiry first (FEFO)';

  @override
  String get itemDetailNoBatches =>
      'No batches recorded yet — batches are created with purchase invoices.';

  @override
  String get itemDetailMovementsSection => 'Recent movements';

  @override
  String get itemDetailNoMovements => 'No movements yet';

  @override
  String get itemDetailRemainingLabel => 'Balance';

  @override
  String get itemDetailBarcodeNote =>
      'Printing and sharing arrive with the printing module later — the barcode is ready to scan from the screen.';

  @override
  String get itemDetailQrTitle => 'Item QR code';

  @override
  String get itemDetailEditAction => 'Edit item';

  @override
  String get itemDetailArchiveAction => 'Archive item';

  @override
  String get itemDetailArchiveTitle => 'Archive this item?';

  @override
  String get itemDetailArchiveBody =>
      'Archiving instead of deleting — the item disappears from search and sales while its movements and prices remain in history. An item with movements is never deleted.';

  @override
  String get itemDetailArchivedMessage =>
      'Item archived — its history is fully preserved';

  @override
  String get itemDetailNotFound =>
      'The item does not exist or was removed from the database.';

  @override
  String batchDaysLeft(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
      zero: 'expires today',
    );
    return '$_temp0';
  }

  @override
  String get batchExpired => 'Expired';

  @override
  String get batchNoExpiry => 'No expiry';

  @override
  String get itemMovementOpening => 'Opening balance';

  @override
  String get itemMovementPurchase => 'Purchase';

  @override
  String get itemMovementSale => 'Sale';

  @override
  String get itemMovementSaleReturn => 'Sales return';

  @override
  String get itemMovementPurchaseReturn => 'Purchase return';

  @override
  String get itemMovementStocktakeAdjust => 'Stocktake adjustment';

  @override
  String get itemMovementManualAdjust => 'Manual adjustment';

  @override
  String get itemMovementTransferIn => 'Transfer in';

  @override
  String get itemMovementTransferOut => 'Transfer out';

  @override
  String get itemMovementUnknown => 'Movement';

  @override
  String get lowStockTitle => 'Items running low';

  @override
  String get lowStockThresholdLabel => 'Minimum level';

  @override
  String get lowStockSearchHint => 'Search by name';

  @override
  String lowStockResultCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get lowStockEmptyTitle => 'No items match these criteria';

  @override
  String get lowStockEmptyBody =>
      'All items are above the set level — raise the level to see more, or change the search keyword.';

  @override
  String get batchesTitle => 'Batches & expiry dates';

  @override
  String get batchesFilterAll => 'All';

  @override
  String get batchesBucketExpired => 'Expired';

  @override
  String get batchesBucket30 => '≤ 30 days';

  @override
  String get batchesBucket60 => '≤ 60 days';

  @override
  String get batchesBucket90 => '≤ 90 days';

  @override
  String batchesResultCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count batches',
      one: '1 batch',
      zero: 'No batches',
    );
    return '$_temp0';
  }

  @override
  String get batchesEmptyTitle => 'No batches in this bucket';

  @override
  String get batchesEmptyBody =>
      'Batches are created with purchase invoices for tracked items and are listed here ordered by earliest expiry.';

  @override
  String get batchesQtyLabel => 'Quantity';

  @override
  String get batchesExpiryLabel => 'Expiry';

  @override
  String get importTitle => 'Import items';

  @override
  String get importModeFile => 'File (CSV / Excel)';

  @override
  String get importModePaste => 'Paste CSV';

  @override
  String get importPickFile => 'Choose a file';

  @override
  String get importPickFileDesc =>
      'A CSV or Excel (xlsx) file — the first sheet is read';

  @override
  String get importPasteHint =>
      'Paste CSV content here — the first line is the header row';

  @override
  String get importPasteFieldHint => 'Name,Barcode,Cost,Qty,Min,Category,Unit';

  @override
  String get importClearSource => 'Clear';

  @override
  String get importContinue => 'Continue to column mapping';

  @override
  String get importMappingSection => 'Column mapping';

  @override
  String get importMappingDesc =>
      'We guessed the mapping from the header row — review and correct as needed.';

  @override
  String get importMappingIgnore => '— ignore —';

  @override
  String get importColumnName => 'Name';

  @override
  String get importColumnBarcode => 'Barcode';

  @override
  String get importColumnCost => 'Cost';

  @override
  String get importColumnQty => 'Opening quantity';

  @override
  String get importColumnMinStock => 'Reorder level';

  @override
  String get importColumnCategory => 'Category';

  @override
  String get importColumnUnit => 'Unit';

  @override
  String get importColumnNotes => 'Notes';

  @override
  String importColumnPrice(Object code) {
    return 'Price $code';
  }

  @override
  String get importAnalyze => 'Analyze the file';

  @override
  String get importAnalyzing => 'Analyzing…';

  @override
  String get importNoSource => 'Pick a file or paste CSV content first';

  @override
  String get importNameNotMapped =>
      'Map the “Name” column first — it is required';

  @override
  String importValidRows(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valid rows',
      one: '1 valid row',
    );
    return '$_temp0';
  }

  @override
  String importFailedRows(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count failed rows',
      one: '1 failed row',
    );
    return '$_temp0';
  }

  @override
  String importFailuresExpand(Object count) {
    return 'Show failed rows ($count)';
  }

  @override
  String get importFailuresCollapse => 'Hide failed rows';

  @override
  String importFailureRow(Object row) {
    return 'Row $row';
  }

  @override
  String importNewCategories(Object names) {
    return 'Categories to be created: $names';
  }

  @override
  String importNewUnits(Object names) {
    return 'Units to be created: $names';
  }

  @override
  String get importAckLabel =>
      'I acknowledge inserting only the valid rows and skipping the failed ones';

  @override
  String get importCommit => 'Insert valid rows';

  @override
  String get importCommitClean => 'Insert all rows';

  @override
  String get importCommitting => 'Inserting…';

  @override
  String get importResultTitle => 'Import result';

  @override
  String importResultInserted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items inserted',
      one: '1 item inserted',
    );
    return '$_temp0';
  }

  @override
  String importResultFailed(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows failed',
      one: '1 row failed',
      zero: 'No failed rows',
    );
    return '$_temp0';
  }

  @override
  String importResultCategories(Object count) {
    return 'Categories created: $count';
  }

  @override
  String importResultUnits(Object count) {
    return 'Units created: $count';
  }

  @override
  String importResultSnackbar(Object failed, Object inserted) {
    return 'Inserted $inserted, failed $failed';
  }

  @override
  String get importFileReadError =>
      'Could not read the file — make sure it is a valid CSV or Excel file';

  @override
  String get importRestart => 'Import another file';

  @override
  String get categoriesUnitsTitle => 'Categories & units';

  @override
  String get categoriesSectionTitle => 'Item categories';

  @override
  String get categoriesAdd => 'Add category';

  @override
  String get categoriesEmptyTitle => 'No categories yet';

  @override
  String get categoriesEmptyBody =>
      'Organize your items with top-level and sub categories — they appear in the items list filter.';

  @override
  String get categoriesRootBadge => 'Top-level';

  @override
  String categoriesChildCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sub-categories',
      one: '1 sub-category',
    );
    return '$_temp0';
  }

  @override
  String get unitsSectionTitle => 'Units of measure';

  @override
  String get unitsAdd => 'Add unit';

  @override
  String get unitsEmptyTitle => 'No units yet';

  @override
  String get unitsEmptyBody =>
      'Piece, carton, kilogram — with a conversion factor for converting between units.';

  @override
  String unitFactorTimes(Object factor) {
    return '× $factor';
  }

  @override
  String get partiesTabTitle => 'Parties';

  @override
  String get partiesHomeHeroTitle => 'Parties management';

  @override
  String get partiesHomeHeroSubtitle =>
      'Customers and suppliers with their balances — each currency on its own, never mixed';

  @override
  String get partiesHubCustomers => 'Customers';

  @override
  String get partiesHubCustomersDesc =>
      'Customer files, balances and account statements';

  @override
  String get partiesHubSuppliers => 'Suppliers';

  @override
  String get partiesHubSuppliersDesc => 'Supplier files and what you owe them';

  @override
  String get partiesHubReceivables => 'Outstanding at customers';

  @override
  String get partiesHubReceivablesDesc =>
      'Open receivables ordered by oldest invoice';

  @override
  String get partiesHubPayables => 'Outstanding to suppliers';

  @override
  String get partiesHubPayablesDesc => 'Payables on the business, per currency';

  @override
  String get partiesHubRates => 'Daily exchange rates';

  @override
  String get partiesHubRatesDesc =>
      'Update today\'s rates before issuing any non-base invoice';

  @override
  String get partiesFxChipComplete => 'Today\'s rates complete';

  @override
  String partiesFxChipMissing(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count currencies without today\'s rate',
      one: '1 currency without today\'s rate',
    );
    return '$_temp0';
  }

  @override
  String get partiesHomeEmptyTitle => 'No parties yet';

  @override
  String get partiesHomeEmptyBody =>
      'Register your first customer or supplier to start tracking balances and statements per currency.';

  @override
  String get partiesHomeEmptyAction => 'Register customer';

  @override
  String partiesCountCustomers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count customers',
      one: '1 customer',
      zero: 'No customers yet',
    );
    return '$_temp0';
  }

  @override
  String partiesCountSuppliers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count suppliers',
      one: '1 supplier',
      zero: 'No suppliers yet',
    );
    return '$_temp0';
  }

  @override
  String partiesDuesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parties',
      one: '1 party',
      zero: 'No parties',
    );
    return '$_temp0';
  }

  @override
  String get partiesListCustomersTitle => 'All customers';

  @override
  String get partiesListSuppliersTitle => 'All suppliers';

  @override
  String get partiesListSearchHint => 'Search by name or phone';

  @override
  String get partiesListSearchEmptyTitle => 'No matching results';

  @override
  String get partiesListSearchEmptyBody =>
      'Try another name or clear the search.';

  @override
  String get partiesListEmptyCustomersTitle => 'No customers yet';

  @override
  String get partiesListEmptyCustomersBody =>
      'Register your customers so the app tracks their balances and statements per currency.';

  @override
  String get partiesListEmptySuppliersTitle => 'No suppliers yet';

  @override
  String get partiesListEmptySuppliersBody =>
      'Register your suppliers so the app tracks what you owe them per currency.';

  @override
  String get partiesListAddCustomersAction => 'Register customer';

  @override
  String get partiesListAddSuppliersAction => 'Register supplier';

  @override
  String get partiesListAddTooltip => 'Add';

  @override
  String get partiesFilterAll => 'All';

  @override
  String get partiesFilterWithBalance => 'With balances';

  @override
  String get partiesFilterZeroBalance => 'Zero balance';

  @override
  String get partiesFilterArchived => 'Archived';

  @override
  String get partiesArchivedBadge => 'Archived';

  @override
  String get partiesBalanceLabel => 'Balance';

  @override
  String get partiesBalanceOwed => 'Due';

  @override
  String get partiesBalanceCredit => 'Credit';

  @override
  String get partiesSwipeArchiveLabel => 'Archive';

  @override
  String partiesArchiveConfirmTitle(Object name) {
    return 'Archive $name?';
  }

  @override
  String get partiesArchiveConfirmBody =>
      'They will be excluded from new sales and purchases, while their history and balances remain in reports.';

  @override
  String partiesArchiveHasMovements(Object name) {
    return '$name cannot be archived — they have recorded financial movements kept in their reports.';
  }

  @override
  String get partiesArchivedDone => 'Archived';

  @override
  String get partiesNoPhone => 'No phone on file';

  @override
  String get partyFormAddCustomerTitle => 'New customer';

  @override
  String get partyFormEditCustomerTitle => 'Edit customer';

  @override
  String get partyFormAddSupplierTitle => 'New supplier';

  @override
  String get partyFormEditSupplierTitle => 'Edit supplier';

  @override
  String get partyFormNameLabel => 'Full name';

  @override
  String get partyFormNameHint => 'e.g. Abdullah Mohammed';

  @override
  String get partyFormNameRequired => 'Name is required — enter it then save.';

  @override
  String get partyFormPhoneLabel => 'Phone number';

  @override
  String get partyFormWhatsappLabel => 'WhatsApp number';

  @override
  String get partyFormWhatsappHint => 'Leave empty if same as phone';

  @override
  String get partyFormAddressLabel => 'Address';

  @override
  String get partyFormAreaLabel => 'Neighborhood / area';

  @override
  String get partyFormCreditLimitLabel => 'Credit limit';

  @override
  String get partyFormCreditLimitHint => 'Empty or a number';

  @override
  String get partyFormCreditLimitHelp =>
      'Empty = no limit at all · Zero = credit sales forbidden · Number = maximum allowed debt';

  @override
  String get partyFormCreditLimitInvalid =>
      'Credit limit must be a number of zero or more — or leave it empty.';

  @override
  String get partyFormOpeningSection => 'Opening balance';

  @override
  String get partyFormOpeningAmountLabel => 'Amount';

  @override
  String get partyFormOpeningAmountHint => '0 if no prior balance';

  @override
  String get partyFormOpeningAmountInvalid =>
      'Opening balance must be a positive number.';

  @override
  String get partyFormOpeningCurrencyLabel => 'Currency';

  @override
  String get partyFormOpeningCurrencyRequired =>
      'A non-zero opening balance requires a currency.';

  @override
  String get partyFormOpeningCurrencyNone =>
      'No currency — pick one for a non-zero amount';

  @override
  String get partyFormOpeningDateLabel => 'Balance date';

  @override
  String get partyFormOpeningLockedNote =>
      'This party has financial movements — the opening balance is locked once any movement exists.';

  @override
  String get partyFormNoRateError =>
      'No exchange rate recorded for this currency — enter today\'s rate in «Exchange rates» first.';

  @override
  String get partyFormNoUserError =>
      'Could not save — no active admin user in the database.';

  @override
  String get partyFormNotesLabel => 'Notes';

  @override
  String get partyFormNotesHint => 'Internal notes, never printed on invoices';

  @override
  String get partyFormSaveLabel => 'Save';

  @override
  String get partyFormSavedCustomer => 'Customer saved';

  @override
  String get partyFormSavedSupplier => 'Supplier saved';

  @override
  String get partiesCreditLimitLabel => 'Credit limit';

  @override
  String get partiesCreditUnlimited => 'No limit';

  @override
  String get partiesCreditForbidden => 'No credit';

  @override
  String partiesCreditLimitValue(Object amount) {
    return 'Limit $amount';
  }

  @override
  String get partyDetailInfoSection => 'Party details';

  @override
  String get partyDetailBalancesSection => 'Balances by currency';

  @override
  String get partyDetailBalancesEmpty =>
      'No balances yet — appears with the first credit invoice or voucher.';

  @override
  String get partyDetailStatementSection => 'Account statement';

  @override
  String get partyDetailStatementCurrency => 'Statement currency';

  @override
  String get partyDetailStatementFrom => 'From date';

  @override
  String get partyDetailStatementTo => 'To date';

  @override
  String get partyDetailPeriodAll => 'All periods';

  @override
  String get partyDetailPeriodThisMonth => 'This month';

  @override
  String get partyDetailPeriodThisYear => 'This year';

  @override
  String get partyDetailFinalBalance => 'Final balance';

  @override
  String get partyDetailCarryInBalance => 'Prior balance at period start';

  @override
  String get partyDetailNoEntries =>
      'No entries in this currency for the selected period.';

  @override
  String get partyDetailNotFoundTitle => 'Party not found';

  @override
  String get partyDetailEditAction => 'Edit details';

  @override
  String get partyDetailNotFoundBody =>
      'The id may be wrong or the record missing.';

  @override
  String get partyDetailArchivedBanner =>
      'Archived party — shown for reports only, not used in new operations.';

  @override
  String partyDetailOpeningRow(Object date) {
    return 'Opening balance recorded on $date';
  }

  @override
  String get partyDetailNotesLabel => 'Notes';

  @override
  String get statementKindInvoice => 'Sales invoice';

  @override
  String get statementKindReceipt => 'Receipt voucher';

  @override
  String get statementKindSaleReturn => 'Sales return';

  @override
  String get statementKindPurchase => 'Purchase invoice';

  @override
  String get statementKindPayment => 'Payment voucher';

  @override
  String get statementKindPurchaseReturn => 'Purchase return';

  @override
  String get statementKindOpening => 'Opening balance';

  @override
  String get statementKindCarryIn => 'Prior balance';

  @override
  String get statementBalanceColumn => 'Balance';

  @override
  String get statementAmountColumn => 'Amount';

  @override
  String get receivablesTitle => 'Outstanding at customers';

  @override
  String get payablesTitle => 'Outstanding to suppliers';

  @override
  String get receivablesEmptyTitle => 'Nothing outstanding';

  @override
  String get receivablesEmptyBody =>
      'No open receivables on any customer right now.';

  @override
  String get payablesEmptyBody => 'No open payables to any supplier right now.';

  @override
  String get partiesBalancesSearchHint => 'Search by name or phone';

  @override
  String get partiesBalancesSearchEmptyTitle => 'No matching results';

  @override
  String get partiesBalancesSearchEmptyBody =>
      'Try another name or clear the search.';

  @override
  String get partiesBalancesTotalLabel => 'Total due';

  @override
  String partiesDaysLateChip(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return 'Late by $_temp0';
  }

  @override
  String partiesLastPaymentLabel(Object date) {
    return 'Last payment $date';
  }

  @override
  String get partiesNoMixNote =>
      'Every balance is held in its own currency — a party with balances in two currencies appears as two separate rows, never summed.';

  @override
  String get fxRatesTitle => 'Daily exchange rates';

  @override
  String get fxTodayCardTitle => 'Today\'s rates';

  @override
  String fxTodayHijriDate(Object date) {
    return 'Rates for $date';
  }

  @override
  String fxBaseNote(Object code) {
    return 'Base currency $code — always 1, never entered.';
  }

  @override
  String fxAgainstBase(Object code) {
    return 'per $code';
  }

  @override
  String get fxRateFieldLabel => 'Today\'s rate';

  @override
  String fxLastKnownRate(Object date, Object rate) {
    return 'Last known rate: $rate on $date';
  }

  @override
  String get fxNoRateYet => 'No rate recorded for this currency yet';

  @override
  String get fxEnteredToday => 'Entered today';

  @override
  String get fxMissingToday => 'Missing today';

  @override
  String get fxSaveLabel => 'Save';

  @override
  String get fxSavingLabel => 'Saving…';

  @override
  String get fxRateInvalid => 'Enter a number greater than zero.';

  @override
  String fxRateSaved(Object code) {
    return 'Today\'s rate saved for $code';
  }

  @override
  String get fxHistorySection => 'Recent rates';

  @override
  String get fxHistoryEmpty => 'No rates recorded for this currency yet.';

  @override
  String get fxShowHistory => 'Show history';

  @override
  String get fxHideHistory => 'Hide history';

  @override
  String get fxAllComplete => 'Today\'s rates are complete for all currencies';

  @override
  String get fxMissingWarning =>
      'Today\'s entry is incomplete — non-base invoices require a rate recorded for the day';

  @override
  String get sellScreenTitle => 'New sale invoice';

  @override
  String get sellNewInvoiceLabel => 'New invoice';

  @override
  String get sellClearCartTooltip => 'Clear cart';

  @override
  String get sellClearCartTitle => 'Clear the cart?';

  @override
  String get sellClearCartBody =>
      'All current cart lines will be removed and cannot be recovered.';

  @override
  String get sellEmptyCartTitle => 'The cart is empty';

  @override
  String get sellEmptyCartBody =>
      'Add the first item by search or barcode scan to start the invoice.';

  @override
  String get sellAddItem => 'Add item';

  @override
  String get sellBarcodeHint => 'Scan or type the barcode then press Enter';

  @override
  String get sellPickCustomer => 'Choose customer';

  @override
  String get sellCashCustomer => 'Walk-in customer';

  @override
  String get sellCashCustomerHint =>
      'Immediate sale with no account — full cash payment';

  @override
  String get sellCurrencyBaseTag => 'base';

  @override
  String get sellCurrencyNoRate => 'no rate today';

  @override
  String sellLineAvailable(Object qty) {
    return 'Available: $qty';
  }

  @override
  String sellLineOverAvailable(Object qty) {
    return 'Quantity exceeds available ($qty)';
  }

  @override
  String get sellLineTotal => 'Line total';

  @override
  String get sellUnitPriceLabel => 'Price';

  @override
  String sellEditPriceTitle(Object name) {
    return 'Unit price: $name';
  }

  @override
  String sellLineDiscountTitle(Object name) {
    return 'Line discount: $name';
  }

  @override
  String get sellLineDiscountNone => 'Discount';

  @override
  String sellLineDiscountPercent(Object value) {
    return '$value% off';
  }

  @override
  String sellLineDiscountAmount(Object value) {
    return '$value off';
  }

  @override
  String get sellInvoiceDiscountTitle => 'Invoice-level discount';

  @override
  String get sellInvoiceDiscountButton => 'Invoice discount';

  @override
  String sellInvoiceDiscountPercent(Object value) {
    return '$value% off';
  }

  @override
  String sellInvoiceDiscountAmount(Object value) {
    return '$value off';
  }

  @override
  String get sellDiscountAmount => 'Amount';

  @override
  String get sellDiscountPercent => 'Percent %';

  @override
  String get sellDiscountAmountHint => 'Discount value as an amount';

  @override
  String get sellDiscountPercentHint => 'Discount percent from 0 to 100';

  @override
  String get sellDiscountAmountError => 'Enter a valid discount amount (≥ 0).';

  @override
  String get sellDiscountPercentError =>
      'The percent must be between 0 and 100.';

  @override
  String get sellDiscountApply => 'Apply discount';

  @override
  String get sellInvalidNumber => 'Enter a valid number.';

  @override
  String get sellTotalsSubtotal => 'Subtotal';

  @override
  String get sellTotalsLineDiscounts => 'Line discounts';

  @override
  String get sellTotalsInvoiceDiscount => 'Invoice discount';

  @override
  String get sellTotalsGrandTotal => 'Net total';

  @override
  String get sellPayButton => 'Pay';

  @override
  String sellPayButtonWithTotal(Object total) {
    return 'Pay · $total';
  }

  @override
  String get sellSaveQuotation => 'Quotation';

  @override
  String sellQuotationSaved(Object no) {
    return 'Quotation $no saved';
  }

  @override
  String get sellQuotationSavedOpen => 'Quotations';

  @override
  String sellFxGateTitle(Object code) {
    return 'Today\'s rate for $code';
  }

  @override
  String get sellFxGateBody =>
      'No document is ever saved with a default rate — enter today\'s rate for this currency, then continue to payment.';

  @override
  String get sellFxGateFieldLabel => 'Today\'s rate';

  @override
  String get sellFxGateFieldHelper =>
      'Value of one unit against the base currency';

  @override
  String get sellFxGateSave => 'Save and continue';

  @override
  String get sellFxSavedAndResumed =>
      'Today\'s rate saved — you can complete the payment now.';

  @override
  String get sellPayMethodCash => 'Full cash';

  @override
  String get sellPayMethodCredit => 'Full credit';

  @override
  String get sellPayMethodMixed => 'Mixed';

  @override
  String get sellPayNetTotalLabel => 'Net total due';

  @override
  String get sellPayWalkInCustomer => 'Walk-in customer';

  @override
  String get sellPayCashFieldLabel => 'Cash received';

  @override
  String get sellPayCashFieldHelper =>
      'May exceed the net — the difference is change due';

  @override
  String get sellPayNetPaid => 'Paid in cash';

  @override
  String get sellPaySettledFully => 'Fully settled';

  @override
  String get sellPayInvalidAmount => 'Enter a valid amount.';

  @override
  String sellPayCashShort(Object total) {
    return 'Cash is below the net total ($total) — choose mixed or credit.';
  }

  @override
  String get sellPayCreditNeedsCustomer =>
      'Credit sales require selecting a customer first — walk-in pays in full cash.';

  @override
  String sellPayMixedRange(Object total) {
    return 'For mixed payment enter an amount strictly between zero and the net total ($total).';
  }

  @override
  String get sellPayAnonymousCashOnly =>
      'Anonymous walk-in customers can only pay the full amount in cash.';

  @override
  String get sellPayConfirm => 'Confirm posting';

  @override
  String get sellReceiptSuccessTitle => 'Invoice posted';

  @override
  String get sellReceiptTotal => 'Total';

  @override
  String get sellReceiptPaidCash => 'Paid in cash';

  @override
  String get sellReceiptChangeDue => 'Change due to customer';

  @override
  String get sellReceiptRemainingCredit => 'Remaining on credit';

  @override
  String get sellReceiptNewInvoice => 'New invoice';

  @override
  String get sellFallbackRateBadge => 'Estimated exchange rate';

  @override
  String get sellPickerTitle => 'Choose an item';

  @override
  String get sellPickerSearchHint => 'Search by name or barcode';

  @override
  String sellPickerBarcodeNotFound(Object code) {
    return 'No item with barcode “$code”';
  }

  @override
  String get sellPickerDone => 'Done';

  @override
  String get sellPickerEmptyTitle => 'No items yet';

  @override
  String get sellPickerEmptyBody =>
      'Add your items in the inventory module, then sell them here.';

  @override
  String get sellPickerNoResultsTitle => 'No matching results';

  @override
  String get sellPickerNoResultsBody => 'Try another name or barcode.';

  @override
  String get sellPickerOutOfStock => 'Out of stock';

  @override
  String sellPickerAvailable(Object qty) {
    return 'Available: $qty';
  }

  @override
  String get sellCustomerPickerTitle => 'Invoice customer';

  @override
  String get sellCustomerPickerSearchHint => 'Search by name or phone';

  @override
  String get sellCustomerPickerEmptyTitle => 'No customers yet';

  @override
  String get sellCustomerPickerEmptyBody =>
      'Register customers in the parties module to sell to them on credit.';

  @override
  String get sellCustomerPickerNoResultsTitle => 'No matching results';

  @override
  String get sellCustomerPickerNoResultsBody => 'Try another name or phone.';

  @override
  String get sellCustomerPickerFooterNote =>
      'Balances are shown per currency and never mixed';

  @override
  String get sellCustomerOwes => 'owes';

  @override
  String get sellCustomerCredit => 'credit balance';

  @override
  String get sellCustomerClear => 'no balance';

  @override
  String get sellHomeTitle => 'Sell';

  @override
  String get sellHomeHeroTitle => 'Point of sale';

  @override
  String get sellHomeTodaySales => 'Today\'s sales';

  @override
  String get sellHomeTodayCash => 'Today\'s net cash';

  @override
  String get sellHomeNewInvoice => 'New sale invoice';

  @override
  String get sellHomeNewInvoiceHint =>
      'Start selling instantly — search, scan, discounts and payment';

  @override
  String get sellHomeRecentInvoices => 'Recent invoices';

  @override
  String get sellInvoicesTitle => 'Sales invoices';

  @override
  String get sellInvoicesSubtitle => 'Record of posted invoices';

  @override
  String get sellInvoicesSearchHint => 'Search by invoice number or customer';

  @override
  String get sellInvoicesEmptyTitle => 'No invoices yet';

  @override
  String get sellInvoicesEmptyBody =>
      'Post your first sale invoice to see it here with its lines and payment status.';

  @override
  String get sellInvoicesNoResultsTitle => 'No matching results';

  @override
  String get sellInvoicesNoResultsBody => 'Try another number or name.';

  @override
  String get sellInvoicesPaidLabel => 'Paid';

  @override
  String get sellInvoicesDueLabel => 'Due';

  @override
  String get sellInvoicesTotalLabel => 'Total';

  @override
  String get sellInvoiceDetailTitle => 'Invoice details';

  @override
  String get sellInvoiceNotFoundTitle => 'Invoice not found';

  @override
  String get sellInvoiceNotFoundBody =>
      'It may have been removed, or the link is incorrect.';

  @override
  String get sellDetailCustomer => 'Customer';

  @override
  String get sellDetailPhone => 'Phone';

  @override
  String get sellDetailCurrency => 'Currency';

  @override
  String get sellDetailExchangeRate => 'Applied exchange rate';

  @override
  String get sellDetailItemsSection => 'Invoice lines';

  @override
  String get sellDetailUnknownItem => 'Removed item';

  @override
  String get sellDetailQtyLabel => 'Qty';

  @override
  String get sellDetailDiscountLabel => 'discount';

  @override
  String get sellDetailTotalDiscount => 'Total discount';

  @override
  String get sellQuotationsTitle => 'Quotations';

  @override
  String get sellQuotationsSubtitle => 'Quotes convertible to invoices';

  @override
  String get sellQuotationsEmptyTitle => 'No quotations yet';

  @override
  String get sellQuotationsEmptyBody =>
      'Save the sale cart as a quotation to review it later before posting.';

  @override
  String get sellQuotationFilterAll => 'All';

  @override
  String get sellQuotationStatusDraft => 'Draft';

  @override
  String get sellQuotationStatusSent => 'Sent';

  @override
  String get sellQuotationStatusConverted => 'Converted';

  @override
  String get sellQuotationStatusExpired => 'Expired';

  @override
  String get sellQuotationStatusCancelled => 'Cancelled';

  @override
  String sellQuotationValidUntil(Object date) {
    return 'Valid until $date';
  }

  @override
  String get sellQuotationValidUntilLabel => 'Valid until';

  @override
  String get sellQuotationMarkSent => 'Mark sent';

  @override
  String get sellQuotationCancel => 'Cancel';

  @override
  String get sellQuotationCancelConfirmTitle => 'Cancel this quotation?';

  @override
  String sellQuotationCancelConfirmBody(Object no) {
    return 'Quotation $no will be cancelled and can no longer be converted to an invoice.';
  }

  @override
  String sellQuotationConvertedTo(Object id) {
    return 'Converted to invoice #$id';
  }

  @override
  String get sellQuotationDetailTitle => 'Quotation details';

  @override
  String get sellQuotationNotFoundTitle => 'Quotation not found';

  @override
  String get sellQuotationNotFoundBody =>
      'It may have been cancelled, or the link is incorrect.';

  @override
  String get sellQuotationRateLabel => 'rate at creation';

  @override
  String get sellQuotationNetTotal => 'Quotation net';

  @override
  String get sellQuotationPrintedNotes => 'Printed note';

  @override
  String get sellQuotationConvertButton => 'Convert to invoice';

  @override
  String get sellQuotationConvertedMessage =>
      'The quotation was converted into a posted invoice successfully.';

  @override
  String get sellQuotationSentMessage => 'The quotation was marked as sent.';

  @override
  String get purHomeTitle => 'Purchases';

  @override
  String get purHubSubtitle => 'Buy, return, and WAC engine';

  @override
  String get purHomeHeroTitle => 'Purchasing & intake';

  @override
  String get purHomeTodayCount => 'Today\'s purchase invoices';

  @override
  String get purHomeTodayTotal => 'Today\'s purchases value';

  @override
  String get purHomeNewInvoice => 'New purchase invoice';

  @override
  String get purHomeNewInvoiceHint =>
      'Enter stock at cost with batch expiry — posting updates the average cost';

  @override
  String get purHomeRecent => 'Recent purchases';

  @override
  String get purInvoicesTitle => 'Purchase invoices';

  @override
  String get purInvoicesSubtitle => 'Posted PUR register';

  @override
  String get purInvoicesSearchHint => 'Search by number or supplier';

  @override
  String get purInvoicesEmptyTitle => 'No purchases yet';

  @override
  String get purInvoicesEmptyBody =>
      'Post your first purchase invoice to add stock and update costs.';

  @override
  String get purInvoicesNoResultsTitle => 'No matches';

  @override
  String get purInvoicesNoResultsBody => 'Try another number or supplier name.';

  @override
  String get purInvoicesPaidLabel => 'Paid';

  @override
  String get purInvoicesDueLabel => 'Remaining';

  @override
  String get purInvoicesTotalLabel => 'Total';

  @override
  String get purDetailTitle => 'Purchase invoice details';

  @override
  String get purDetailNotFoundTitle => 'Invoice not found';

  @override
  String get purDetailNotFoundBody =>
      'It may have been removed or the link is wrong.';

  @override
  String get purDetailSupplier => 'Supplier';

  @override
  String get purDetailStockValue => 'Intake value at cost';

  @override
  String get purDetailStockValueNote =>
      'In base currency — the weighted-average cost basis';

  @override
  String get purDetailReturnAction => 'Return to supplier (purchase return)';

  @override
  String get purSupplierRequired => 'Select a supplier';

  @override
  String get purSupplierOwes => 'We owe';

  @override
  String get purSupplierCredit => 'Credit with us';

  @override
  String get purSupplierPickerTitle => 'Invoice supplier';

  @override
  String get purSupplierPickerSearchHint => 'Search by name or phone';

  @override
  String get purSupplierPickerEmptyTitle => 'No suppliers yet';

  @override
  String get purSupplierPickerEmptyBody =>
      'Register suppliers in the parties module to buy from them.';

  @override
  String get purSupplierPickerNoResultsTitle => 'No matches';

  @override
  String get purSupplierPickerNoResultsBody => 'Try another name or phone.';

  @override
  String get purScreenTitle => 'New purchase invoice';

  @override
  String get purNewInvoiceLabel => 'Next PUR number';

  @override
  String get purPickSupplier => 'Select supplier';

  @override
  String get purClearCartTooltip => 'Clear invoice';

  @override
  String get purClearCartTitle => 'Clear the purchase invoice?';

  @override
  String get purClearCartBody =>
      'Unposted lines will be removed — nothing is written to the database.';

  @override
  String get purEmptyCartTitle => 'Invoice is empty';

  @override
  String get purEmptyCartBody =>
      'Add intake items at purchase cost — batches are created per tracked line with its expiry.';

  @override
  String get purAddItem => 'Add item';

  @override
  String purLineStock(Object qty) {
    return 'In stock now: $qty';
  }

  @override
  String get purUnitCostLabel => 'Cost';

  @override
  String purEditCostTitle(Object name) {
    return 'Unit cost: $name';
  }

  @override
  String get purIncomingBatchTitle => 'Incoming batch';

  @override
  String get purBatchNoHint => 'Supplier batch number';

  @override
  String get purExpiryPick => 'Pick expiry date';

  @override
  String purExpiryValue(Object date) {
    return 'Expires $date';
  }

  @override
  String get purExpiryQuickMonth => '+30 days';

  @override
  String get purExpiryQuick3Months => '+90 days';

  @override
  String get purExpiryQuick6Months => '+180 days';

  @override
  String get purExpiryQuickYear => '+1 year';

  @override
  String get purExpiryDialogTitle => 'Expiry date';

  @override
  String get purInvoiceDiscountButton => 'Invoice discount';

  @override
  String get purInvoiceDiscountTitle => 'Purchase invoice discount';

  @override
  String get purPayButton => 'Post purchase';

  @override
  String purPayButtonWithTotal(Object total) {
    return 'Pay · $total';
  }

  @override
  String get purPayCashFieldLabel => 'Cash paid to supplier';

  @override
  String get purPayCashFieldHelper =>
      'Leaves the cashbox — never above the net';

  @override
  String purPayCashShort(Object total) {
    return 'Cash is below the net ($total) — choose mixed or credit.';
  }

  @override
  String purPayMixedRange(Object total) {
    return 'In mixed payment enter an amount strictly between zero and the net ($total).';
  }

  @override
  String get purPayConfirm => 'Confirm posting';

  @override
  String get purReceiptSuccessTitle => 'Purchase invoice posted';

  @override
  String get purReceiptSupplierCredit => 'Remaining on credit (supplier debt)';

  @override
  String get purReceiptNewInvoice => 'New purchase';

  @override
  String get purPickerTitle => 'Pick item to purchase';

  @override
  String get purPickerSearchHint => 'Search by name or barcode';

  @override
  String get purPickerEmptyTitle => 'No items yet';

  @override
  String get purPickerEmptyBody =>
      'Add items in the inventory module then buy their stock here.';

  @override
  String purPickerAvailable(Object qty) {
    return 'In stock: $qty';
  }

  @override
  String purPickerLastCost(Object cost) {
    return 'Last cost: $cost';
  }

  @override
  String get retSaleTitle => 'Sale return';

  @override
  String get retSaleSubtitle => 'Return sales with an SRN';

  @override
  String get retPurchaseTitle => 'Purchase return';

  @override
  String get retPurchaseSubtitle => 'Return intake to supplier with a PRN';

  @override
  String get retPickInvoiceSearchHint => 'Search by invoice number or customer';

  @override
  String get retPickPurchaseSearchHint => 'Search by PUR number or supplier';

  @override
  String get retPickInvoiceEmptyTitle => 'No completed invoices';

  @override
  String get retPickInvoiceEmptyBody =>
      'Returns are strictly linked to a completed original invoice.';

  @override
  String get retPickInvoiceNoResultsTitle => 'No matches';

  @override
  String get retPickInvoiceNoResultsBody => 'Try another number or name.';

  @override
  String get retChangeInvoice => 'Change invoice';

  @override
  String get retLinesTitle => 'Returnable lines';

  @override
  String get retNoLinesTitle => 'No returnable lines';

  @override
  String get retNoLinesBody =>
      'All quantities of this invoice may have been returned already.';

  @override
  String retOriginalQty(Object qty) {
    return 'Original: $qty';
  }

  @override
  String retReturnedQty(Object qty) {
    return 'Returned before: $qty';
  }

  @override
  String retAvailableQty(Object qty) {
    return 'Available to return: $qty';
  }

  @override
  String get retQtyLabel => 'Return qty';

  @override
  String get retLineRefundLabel => 'Refund';

  @override
  String get retRefundTotalLabel => 'Return value';

  @override
  String get retRefundCash => 'Cash refund';

  @override
  String get retRefundCredit => 'Deduct from account';

  @override
  String get retRefundCashOnlyNote =>
      'Original invoice has an anonymous cash customer — refund in cash only.';

  @override
  String get retRefundCashFieldLabel => 'Cash refunded now';

  @override
  String retRefundCashShort(Object total) {
    return 'Cash is below the return value ($total) — choose deduction or mixed.';
  }

  @override
  String retRefundMixedRange(Object total) {
    return 'In a mixed refund enter an amount strictly between zero and the return value ($total).';
  }

  @override
  String get retPostButton => 'Post return';

  @override
  String get retNewReturn => 'New return';

  @override
  String get retReceiptSuccessTitle => 'Return posted';

  @override
  String retReceiptOriginal(Object no) {
    return 'Against original invoice $no';
  }

  @override
  String get retReceiptRefundCash => 'Cash refunded';

  @override
  String get retReceiptRefundCredit => 'Deducted from account';
}
