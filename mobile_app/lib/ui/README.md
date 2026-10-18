# UI Layer (Presentation)

MVVM presentation layer built from lean, reusable widgets.

- `core/` — shared building blocks: themes, typography, router, common widgets.
- `features/<name>/views/` — screens for the feature (dumb widgets).
- `features/<name>/view_models/` — ChangeNotifier classes owning state and
  interaction logic; Repositories are injected via constructors.
- `features/printing/` — **the single home for everything printed (PDF)** —
  R19-D1 rule: all print code lives here, nowhere else:
  - `docs/` — print-document projections (pure data, labels pre-translated by
    callers) + the invoice doc-builder that assembles the projection from
    live sale details (labels from l10n, numbers via AmountText — R20-D1,
    moved in from sell to close the settings→sell edge).
  - `core/` — print primitives (fonts, palette, text styles).
  - `services/` — PDF builders (invoice, voucher, shift, statement, profit).
  - `templates/` — customizable invoice template engine + layouts.
  - `views/` — the shared PDF preview dialog + the live invoice template
    preview entry (R20-D1 — consumed by the settings print-templates
    screen directly, no feature import).
  Other features may import from `features/printing/`, but `features/printing/`
  itself must stay generic — it never imports another feature.
