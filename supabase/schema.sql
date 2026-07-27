-- =====================================================================
-- Prospera Finance — Esquema Supabase (Postgres)
-- =====================================================================
-- Diseño intencionalmente MÍNIMO ("código enxuto"): en vez de modelar
-- una tabla relacional por entidad (transactions/budget_items/debts/
-- goals/categories), se guarda un único snapshot JSON por usuario —
-- exactamente el mismo formato que ya produce
-- `AppState.exportSnapshot()` / consume `AppState.importSnapshot()`.
--
-- Ventajas de este enfoque para este proyecto:
--   - Cero cambios en los modelos Dart (Txn/BudgetItem/Debt/Goal) ni en
--     su serialización — se reutiliza tal cual.
--   - Cero necesidad de resolver conflictos fila por fila: solo hay UN
--     usuario por cuenta (regla del proyecto), así que "el último
--     guardado gana" es suficiente y correcto.
--   - Acoplamiento mínimo: `AppState` no sabe nada de Supabase, solo
--     expone `exportSnapshot()`/`importSnapshot()` (ya existían).
--
-- Regla del proyecto: un usuario de Google = una cuenta. No existe
-- ningún concepto de cuenta compartida, membresías ni invitaciones.
-- =====================================================================

create table if not exists user_data (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  data        jsonb not null default '{}',
  updated_at  timestamptz not null default now()
);

alter table user_data enable row level security;

create policy user_data_all on user_data
  for all using (user_id = auth.uid());
