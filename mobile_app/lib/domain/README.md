# Domain Layer

Pure business logic with no framework or IO dependencies.

- `models/` — clean, immutable domain entities.
- `use_cases/` — optional interactors extracted only when logic is complex
  or shared across multiple ViewModels.
