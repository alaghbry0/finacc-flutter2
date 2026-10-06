# Data Layer

Isolates all data access behind the Repository pattern.

- `models/` — API/transfer models (raw shapes returned by services).
- `services/` — stateless wrappers around external sources (HTTP clients,
  local databases, platform plugins).
- `repositories/` — consume one or more services, transform raw API models
  into clean Domain models and handle caching/retries. They are the single
  source of truth exposed to ViewModels.
