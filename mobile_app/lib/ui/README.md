# UI Layer (Presentation)

MVVM presentation layer built from lean, reusable widgets.

- `core/` — shared building blocks: themes, typography, router, common widgets.
- `features/<name>/views/` — screens for the feature (dumb widgets).
- `features/<name>/view_models/` — ChangeNotifier classes owning state and
  interaction logic; Repositories are injected via constructors.
