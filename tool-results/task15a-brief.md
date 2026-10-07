# Task 15-a Brief: كشف حساب الطرف PDF (Statement PDF) — FinAcc

## Identity & Protocol
- Task ID: **15-a**. You are a Flutter sub-agent inside the FinAcc project.
- FIRST read /home/z/my-project/worklog.md (sections Task 13, 14) and /home/z/my-project/mobile_app/AGENTS.md (sections 4-7 methodology).
- When done, APPEND your worklog section to /home/z/my-project/worklog.md using the exact template from AGENTS.md (--- separator, Task ID: 15-a, Agent, Task, Work Log bullets, Stage Summary).
- Working dir: /home/z/my-project/mobile_app. Flutter SDK: export PATH="/home/z/flutter/bin:$PATH".
- Do NOT touch: test/ folder (just restored, 414 green), core/printing legacy module, pubspec dependencies (pdf/printing/url_launcher already present).
- Use `dart format` on every file you create/modify. Gate: `dart analyze` must be 0 errors 0 warnings.

## Objective
Build **كشف حساب الطرف (Party Statement) PDF** — SRS slice 7 document #3 — and wire it into the customer detail screen.

## Existing architecture facts (verified)
- Printing module lives in `lib/ui/features/printing/`:
  - `core/print_fonts.dart` — PrintFonts class loading Almarai from assets.
  - `core/print_palette.dart` — PrintPalette (teal 00695C seed).
  - `print_docs.dart` — pure projections (InvoicePrintDoc, VoucherPrintDoc...). Labels are passed in from l10n — NO literal strings inside templates.
  - `services/invoice_pdf_builder.dart` + `services/voucher_pdf_builder.dart` — study these as your pattern (A4 RTL, TextDirection.rle on every Arabic text, identity band, totals card, footer).
  - `views/pdf_preview_dialog.dart` — the preview dialog (raster 150dpi + طباعة/مشاركة/واتساب defensive buttons + NEW file-size bar). Reuse it exactly like invoice detail does.
- Wiring example: `lib/ui/features/sell/views/sales_invoice_detail_screen.dart` — AppBar PDF icon calling the dialog with the built doc.
- Voucher wiring example: cash movements ledger row → movement detail (look at how voucher_pdf_builder is invoked for RVT/PMT rows).
- l10n: add keys to BOTH `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb` (place them in the printing section next to printingPreviewTitle; follow existing naming style "printingStatement*"). Then run `flutter gen-l10n`.
- Party detail screen: `lib/ui/features/parties/views/party_detail_screen.dart` — add a PDF icon button in its AppBar (RTL: actions side) to print the statement for that party.

## Statement document design (A4 RTL)
- Header: company name + document title «كشف حساب» + party name/phone + generated-at date + period covered (from earliest movement to now).
- Opening balance row (رصيد افتتاحي) if party has one (opening balance from party creation).
- Table of movements affecting that party's balance, chronological: date | description (invoice/voucher/return + its number) | مدين (debit, increases what they owe us — sales invoice) | دائن (credit — receipts/payments/returns) | running balance (الرصيد).
- Totals row: sum debit / sum credit / closing balance (الرصيد الختامي) big bold like invoice totals card.
- Footer: thank-you line + generated-by FinAcc line (match invoice footer style).
- Numbers: use the same amount formatting helpers the invoice builder uses (look for how it formats amounts; currency = company currency code).

## Data sourcing
- Explore `lib/data/repositories/` for what can produce party movements: customer repository (balance + opening), sale_repository (invoices by customer), return_repository, voucher repositories (RVT/PMT by party), purchase side only if party is supplier (statement is generic for both kinds — check party model's kind field).
- Build a pure projection class `StatementPrintDoc` in `print_docs.dart` style (its own file `statement_print_doc.dart` is fine inside printing module) + an assembler function that takes party + repositories data and returns the doc. Keep it pure/testable (no BuildContext inside).
- If a repository lacks a "by party" query, ADD the query to the repository (follow existing repository method patterns; keep SQL parameterized).
- The screen-side loader: async function gathering data then `showDialog` with the existing preview dialog — mirror sales_invoice_detail_screen.dart's PDF flow (loading state + error state defensive).

## Definition of done
1. `dart analyze` 0/0 after `flutter gen-l10n`.
2. `dart format` clean on all touched files.
3. Statement PDF compiles: doc.save() works (the preview dialog handles rasterization; you do NOT need to run a browser — the coordinator will verify live).
4. Worklog section appended (Task ID 15-a).
5. Report back: files created/modified list + any data-source decisions + exact AppBar wiring location + l10n key names added.

## Report format (your final message)
Return: (1) list of created/modified files with one-line purpose each, (2) l10n keys added, (3) repository queries added, (4) any deviations from this brief and why, (5) analyze result line.
