# Plan de Migración del Frontend — Prospera Finance
## De arquitectura monolítica (AppState + SharedPreferences + Google Sheets) hacia Clean Architecture simplificada (Supabase + SQLite + Sync Engine)

**Estado de este documento**: REVISADO tras revisión crítica de simplificación — pendiente de aprobación final. Ninguna pantalla, diseño ni flujo de usuario se modifica hasta que este plan sea aprobado explícitamente.

**Versión anterior**: la v1 de este documento (10 fases) fue sometida a una revisión crítica explícita con foco en simplicidad, bajo acoplamiento y eliminación de abstracciones innecesarias. Esta v2 incorpora los resultados de esa revisión. Todos los cambios respecto a la v1 están marcados explícitamente en la sección 0 y en cada fase con `🔻 CAMBIO v2`.

---

## 0. Qué cambió respecto al plan original (v1 → v2) y por qué

Esta sección resume, de forma auditable, cada eliminación/simplificación decidida en la revisión crítica.

| # | Cambio | Por qué |
|---|---|---|
| 1 | **Se elimina la Fase 1 ("Bridge") como fase independiente** — se fusiona con la Fase 2. | Era pura ceremonia: agregar campos/archivos que no se usan hasta 2+ fases después. Código escrito y no ejercitado durante varias fases es riesgo de mantenimiento, no beneficio. Viola el principio "no agregar capas antes de necesitarlas". |
| 2 | **Limpieza de simplificación (PIN, Colaboradores, Google Sheets, `GoogleAuthService`, `RemoteFailure`/`UnknownFailure`, Client ID duplicado) pasa a ejecutarse ANTES de la Fase 1, como "Fase 0.5"**, en vez de estar distribuida en Fases 2 y 8. | Estas eliminaciones ya fueron aprobadas en la revisión de simplificación previa. Distribuirlas dentro de fases de migración de datos mezclaba dos tipos de trabajo distintos (retirar código muerto vs. migrar datos reales) sin necesidad. Ejecutarlas primero también **reduce el alcance de las Fases 2 y 8** (ya no cargan con esa limpieza). |
| 3 | **`domain/rules/` pasa de 4 archivos propuestos a 1 solo archivo** (`financial_rules.dart`, organizado por secciones comentadas). | El volumen real de código (verificado por lectura de `app_state.dart`) no justifica 4 archivos separados en un app financiero personal. Menos archivos, misma separación de responsabilidades (todas son funciones puras de dominio, sin mezclar con Data/Presentation). |
| 4 | **Los tests de paridad pasan de 4 archivos propuestos a 1 solo archivo** (`test/parity/financial_rules_parity_test.dart`). | Mismo razonamiento: los datos de referencia (`SeedData`) son compartidos entre módulos, no hay necesidad real de separar en 4 archivos. |
| 5 | **`legacy_mappers.dart` deja de crearse por anticipado con las 5 traducciones.** Cada función de mapeo se escribe recién en la fase donde se usa por primera vez. | Escribir y no poder validar código de mapeo durante varias fases es exactamente el tipo de riesgo de mantenimiento que se buscaba evitar. Se decide en cada fase si el archivo compartido vale la pena o si basta con funciones privadas dentro de `app_state.dart`. |
| 6 | **Se elimina `createdBy`/`updatedBy` de las 5 entidades de dominio** (`Transaction`, `BudgetItem`, `Debt`, `Goal`, `Category`), y del parámetro `deletedBy` de los `softDelete()`. | Verificado por grep en todo el código: en el 100% de los usos reales, `createdBy == updatedBy == userId`. Son campos de auditoría multiusuario sin propósito en un modelo donde "un usuario de Google = una cuenta" (no existe edición de datos de otra persona). Se mantienen `createdAt`/`updatedAt` (necesarios para last-write-wins del sync) y `deletedAt` (necesario para soft-delete/tombstone). |
| 7 | **Se decide ahora (no se deja "a decidir en el momento") que tema/período seleccionado/tarjetas visibles permanecen permanentemente en `SharedPreferences`**, sin tabla `user_settings` en Supabase. | Son preferencias de dispositivo sin valor real en sincronizarse entre aparelhos para un app de uso personal. Crear infraestructura remota para esto sería complejidad sin beneficio medible. |
| 8 | **No se crea ningún helper genérico para el volcado único de datos legacy → nuevo** (el patrón se repite ~5 veces, una por entidad). | A diferencia de los `*RepositoryImpl` (duplicación permanente, con service real), este código es transicional y se **elimina por completo** en la fase de limpieza final. No vale la pena abstraer código que será descartado. |
| 9 | **Total de fases: 10 → 8** (0.5, 2, 3, 4, 5, 6, 7, 8/final-cleanup fusionadas donde aplica). | Consecuencia directa de los puntos anteriores. |
| — | **Se mantienen sin cambios** (evaluados y confirmados como ya justificados): `AuthController` (resuelve una complicación real y documentada del login Web con Google — sin él, `AppState` absorbería esa complejidad); `SyncEngine` (tamaño y robustez ya validados en Fase 0, sin sobre-ingeniería — last-write-wins + outbox FIFO, sin CRDT ni merge complejo); `GenericLocalDataSource<T>` (ya evita duplicar SQL 5 veces); separación Domain/Data/Presentation (verificada sin dependencias cruzadas indebidas); estrategia de "fachada estable" (`AppState`) para no tocar pantallas durante la migración. | — |
| — | **Nota para el futuro (no bloquea este plan, no se decide ahora)**: una vez completada la Fase de limpieza final, evaluar si mantener `AppState` como fachada permanente o exponer los Controllers/Repositories directamente vía Provider a las pantallas — mantenerlo indefinidamente como intermediario de 1700+ líneas es en sí mismo un costo de mantenimiento a vigilar, pero decidir esto ahora requeriría tocar pantallas, lo cual está fuera del alcance de esta etapa. | Transparencia sobre un riesgo de largo plazo detectado, sin violar la restricción de "no tocar pantallas todavía". |

**Verificado antes de escribir este plan** (para no repetir suposiciones): grep confirmó que **ninguna** de las 12 pantallas ni de los 8 widgets en `lib/screens/`/`lib/widgets/` importa `supabase_flutter`, `sqflite`, `SharedPreferences`, `AppDatabase` o `SupabaseClientProvider` directamente — toda la infraestructura pasa exclusivamente por `AppState`. Esta es la regla que todas las fases siguientes deben preservar sin excepción.

---

## 1. Resumen ejecutivo

Hoy conviven en el repositorio **dos arquitecturas completas y desconectadas entre sí**:

| | Arquitectura ACTUAL (producción, `lib/main.dart`) | Arquitectura NUEVA (validada en diagnósticos, `lib/dev/`) |
|---|---|---|
| Estado | `AppState` (`lib/state/app_state.dart`, 1732 líneas, un solo `ChangeNotifier` con TODA la lógica) | `AuthController` (`lib/application/controllers/`) + Repositories inyectados |
| Persistencia local | `StorageService` (`SharedPreferences`, JSON de listas) | SQLite (`AppDatabase` + `GenericLocalDataSource<T>`) — tablas tipadas |
| Identidad de datos | Ninguna — no hay `userId` | `userId` obligatorio en cada entidad, igual a `auth.uid()` |
| Sincronización remota | ~~`GoogleSheetsService`~~ *(eliminado en Fase 0.5)* | `SyncEngine` + `sync_queue` (outbox) — fila por fila contra Supabase Postgres, con RLS |
| Login | ~~Solo PIN local~~ *(PIN eliminado en Fase 0.5)* | Login con Google obligatorio vía Supabase Auth |
| Modelos | `lib/models/*.dart` — mutables, sin auditoría | `lib/domain/entities/*.dart` — inmutables, con `id`/`userId`/`createdAt`/`updatedAt`/`deletedAt` *(sin `createdBy`/`updatedBy`, ver sección 0.6)* |
| Consumida por | 12 pantallas + 8 widgets (32 usos de `context.read/watch<AppState>()`) | Solo `lib/dev/architecture_diagnostics_main.dart` (no productivo) |

**Objetivo de esta migración**: reemplazar gradualmente el motor interno de `AppState` por los Repositories nuevos (SQLite + SyncEngine + Supabase), **sin que las 12 pantallas necesiten saberlo** — migrar la fontanería, no la casa.

**Estrategia central (Patrón "Strangler Fig" / Fachada estable)**: `AppState` deja de ser propietario de los datos y pasa a ser una **fachada de compatibilidad**: conserva EXACTAMENTE los mismos getters/métodos públicos que las pantallas ya conocen, pero por dentro cada método delega en el Repository correspondiente.

---

## 2. Inventario exacto de archivos involucrados

### 2.1 Se eliminan en la Fase 0.5 (antes de empezar la migración de datos — ver sección 4)
```
lib/screens/lock_screen.dart                    (PIN local)
lib/models/collaborator.dart                     (Colaboradores/ShareRole)
lib/services/google_sheets_service.dart          (sync paralelo a Sheets)
lib/services/google_auth_service.dart            (solo servía a Google Sheets)
lib/config/google_config.dart                    (Client ID duplicado — se unifica)
Secciones "PIN", "Compartir acceso" y "Sincronización con Google Sheets"
  en lib/screens/settings_screen.dart (líneas 179–650 aprox.)
Métodos de AppState: setPin/tryUnlock/lock, generateShareLink/revokeShareLink/
  setOwnerName, addCollaborator/updateCollaboratorRole/removeCollaborator,
  scheduleCloudSync/syncNowWithGoogleSheets/restoreNowFromGoogleSheets/
  disconnectGoogle/_onGoogleAuthChanged
Claves de StorageService: prospera_pin_v1, prospera_share_token_v1,
  prospera_collaborators_v1, prospera_owner_name_v1
RemoteFailure y UnknownFailure en lib/core/failures.dart (dead code)
```

### 2.2 Núcleo actual a reemplazar gradualmente (destino final: eliminación, nunca antes de la fase de limpieza)
```
lib/state/app_state.dart              (pasa a fachada, luego se reduce)
lib/services/storage_service.dart     (SharedPreferences — sobrevive para config local, ver sección 0.7)
lib/services/seed_data.dart           (datos de ejemplo — se reescribe en Fase Transacciones)
lib/services/insights_engine.dart     (motor de insights — se migra junto con su módulo, mismas reglas)
lib/services/export_import_service.dart (CSV export/import — se ajusta cuando ya no dependa de Colaboradores)
lib/models/*.dart                     (se eliminan uno por uno, según deje de haber referencias)
```

### 2.3 Núcleo nuevo ya validado (no se toca su lógica interna — ya probado en Fase 0)
```
lib/domain/entities/{transaction,budget_item,debt,goal,category,enums}.dart
  ⚠ se les retira createdBy/updatedBy en la fase que corresponda (ver sección 0.6)
lib/domain/repositories/{transaction,budget,debt,goal,category,auth}_repository.dart
lib/domain/rules/financial_rules.dart  (🔻 CAMBIO v2: un solo archivo, no 4)
lib/data/repositories/{transaction,budget,debt,goal,category}_repository_impl.dart
lib/data/local/datasources/{generic_local_datasource,sync_queue_local_datasource}.dart
lib/data/local/database/{app_database,migrations/v1_initial_schema}.dart
lib/data/remote/{supabase_client_provider,datasources/auth_remote_datasource}.dart
lib/data/sync/{sync_engine,sync_queue_entry}.dart
lib/application/controllers/auth_controller.dart
lib/core/{constants,failures,result,sqlite_bool}.dart
```

### 2.4 Pantallas y widgets que consumen `AppState` directamente (a NO tocar salvo llamadas puntuales)
```
lib/screens/analisis_screen.dart
lib/screens/budget_form_screen.dart
lib/screens/debt_form_screen.dart
lib/screens/goal_form_screen.dart
lib/screens/home_screen.dart
lib/screens/manage_taxonomy_screen.dart
lib/screens/planificacion_screen.dart
lib/screens/resumen_screen.dart
lib/screens/settings_screen.dart          ⚠ sección "Colaboradores"/"PIN"/"Google Sheets" ya retirada en Fase 0.5
lib/screens/transacciones_screen.dart
lib/screens/transaction_form_screen.dart
lib/widgets/{kpi_header,period_selector,google_sign_in_button_stub,google_sign_in_button_web}.dart
```
Confirmado por grep (sección 0): ninguno de estos archivos importa infraestructura directamente hoy — esta regla debe mantenerse sin excepción durante toda la migración.

### 2.5 Punto de entrada de producción
```
lib/main.dart   (se simplifica en Fase 0.5 al retirar la rama LockScreen; se amplía en Fase 2 con login)
```

---

## 3. Decisiones ya resueltas (no requieren aprobación adicional — ya decididas en la revisión de simplificación)

Estas dos decisiones, que en la v1 de este plan requerían tu aprobación explícita, **ya fueron decididas** durante la revisión de simplificación previa a esta:

### 3.1 Login obligatorio — DECIDIDO
No habrá una capa de PIN "encima" del login (el PIN se elimina por completo en Fase 0.5). El flujo final es simplemente: sin sesión → pantalla de login con Google; con sesión → Home directo. Una sola capa de seguridad (Supabase Auth), no dos.

### 3.2 Colaboradores / compartir acceso — DECIDIDO
La sección completa se retira en Fase 0.5, junto con `Collaborator`/`ShareRole`, antes de tocar ningún dato real. No se migra nada de esta funcionalidad porque no tiene ningún respaldo funcional en el nuevo backend.

**No quedan decisiones pendientes de tu aprobación puntual dentro de las fases 2–8** — todas las decisiones arquitectónicas relevantes ya se tomaron en esta revisión. Lo único pendiente es tu aprobación general de este plan completo (sección 10).

---

## 4. Estrategia de convivencia (código antiguo + nuevo al mismo tiempo)

Durante toda la migración (Fases 2 a 7), `lib/main.dart` sigue arrancando `AppState` de forma muy similar a hoy (sin PIN, con login agregado en Fase 2). Lo que cambia, fase a fase, es lo que hay DENTRO de `AppState`, módulo por módulo:

1. `AppState` recibe (agregado en la Fase 2, no en una fase "Bridge" separada — 🔻 CAMBIO v2) un `AuthController` y, módulo por módulo, cada Repository nuevo en el momento en que ese módulo se migra (no todos de antemano).
2. Las funciones de mapeo (`Txn ↔ Transaction`, etc.) se escriben en la fase donde se usan por primera vez, no antes (🔻 CAMBIO v2). Si crecen lo suficiente como para justificar un archivo propio (`legacy_mappers.dart`), se crea en ese momento — decisión tomada con código real delante, no anticipada.
3. Mientras un módulo NO ha sido migrado todavía, sigue funcionando exactamente como hoy (`storage.saveX()`/SharedPreferences) — almacenes independientes, sin colisión de claves.
4. Los datos ya existentes del usuario en `SharedPreferences` se migran una sola vez, de forma automática, al momento en que cada módulo pasa a usar el Repository nuevo (código simple e inline, deliberadamente no abstraído — ver sección 0.8).

Esto preserva exactamente lo pedido: fases pequeñas e independientes, nunca dos módulos importantes migrando a la vez, la app sigue compilando y funcionando igual después de cada fase.

---

## 5. Cómo se protege cada regla financiera existente

> **Ninguna fase mueve, reescribe ni reinterpreta una regla de negocio.** Cada regla financiera se **copia literalmente** desde `AppState` hacia `lib/domain/rules/financial_rules.dart` (🔻 CAMBIO v2: un solo archivo con secciones comentadas por módulo, no 4 archivos separados) como función pura (input → output, sin `ChangeNotifier`, sin `Future`), y el método público de `AppState` pasa a llamar a esa función.

Esto da dos garantías:
1. **Diff literal verificable**: código viejo en `AppState` vs. código nuevo en `domain/rules/financial_rules.dart`, idénticos carácter por carácter (salvo renombrar `Txn`→`Transaction`).
2. **Testeable de forma aislada**: un único archivo `test/parity/financial_rules_parity_test.dart` (🔻 CAMBIO v2: un solo archivo, no 4) alimenta los mismos datos de `SeedData` y compara resultados exactos antes/después, por sección.

Reglas financieras identificadas que deben preservarse exactamente:
- `AppState._recalcDebt` / `_recalcGoal` — recálculo desde transacciones vinculadas (fuente única de verdad).
- `AppState._generateInstallmentsForDebt` / `_generateContributionsForGoal` — generación automática de `BudgetItem`.
- `AppState.reconcileDeficitRollovers` — rollover de déficit mes a mes.
- `Txn.isEffectivelyInflow` / `signedAmount` / `movementTypeLabel` — ya existen idénticos en `domain/entities/transaction.dart` (solo verificación de paridad).
- `budgetProgressLevelFor(ratio)` — niveles verde/amarillo/naranja/rojo del KPI de Planificación.
- `AppState.realizadoForBudgetItem` / `isBudgetItemCovered`.
- `InsightsEngine` — todas sus funciones de interpretación (se mantiene como archivo propio, es lógica de producto/dominio, no infraestructura — ver Grupo C de la revisión de simplificación).

---

## 6. Orden exacto de las fases (🔻 CAMBIO v2: 10 → 8 fases)

```
Fase 0    ✅ COMPLETA — Infraestructura validada (ya ejecutada)
Fase 0.5  → Limpieza de simplificación (eliminar PIN, Colaboradores, Google Sheets,
            GoogleAuthService, RemoteFailure/UnknownFailure, unificar Client ID)
Fase 2    → Autenticación end-to-end (login Google real + wiring de AuthController
            + Repositories, todo en una sola fase — antes Fase 1+2)
Fase 3    → Categorías (Taxonomía) — módulo más simple, menor riesgo
Fase 4    → Transacciones — núcleo del sistema, mayor riesgo, migra sola
            (incluye retirar createdBy/updatedBy de las 5 entidades, ver sección 0.6)
Fase 5    → Planificación (Presupuesto) — depende de Transacciones
Fase 6    → Deudas — depende de Transacciones
Fase 7    → Objetivos (Goals) — depende de Transacciones
Fase 8    → Configuración general (tema, período, tarjetas visibles — permanecen
            en SharedPreferences, decisión ya tomada, ver sección 0.7) +
            limpieza final de código/modelos legacy sin referencias
Fase 9    → (Opcional, posterior, fuera de alcance inmediato) Sincronización "pull"
```

**Por qué este orden**: igual razonamiento que la v1 — Categorías primero (sin reglas de recálculo, menor riesgo para afinar el patrón), Transacciones sola (todo depende de ella), Planificación/Deudas/Objetivos en ese orden por sus dependencias de lectura/escritura mutuas.

---

## Fase 0.5 — Limpieza de simplificación (ejecutar antes de tocar cualquier dato real)

**Objetivo**: retirar todo lo que la revisión de simplificación identificó como código muerto o funcionalidad sin respaldo real, ANTES de empezar a migrar datos — para que las fases siguientes no carguen con esta limpieza.

**Archivos eliminados**:
```
lib/screens/lock_screen.dart
lib/models/collaborator.dart
lib/services/google_sheets_service.dart
lib/services/google_auth_service.dart
lib/config/google_config.dart (tras mover su constante, unificada, a lib/core/constants.dart)
```

**Archivos modificados**:
- `lib/main.dart` — se retira la rama `state.unlocked ? HomeScreen() : LockScreen()`; queda solo `HomeScreen()` (el login real se agrega en Fase 2).
- `lib/state/app_state.dart` — se retiran todos los métodos/campos listados en la sección 2.1.
- `lib/services/storage_service.dart` — se retiran las claves/métodos de PIN, share token, colaboradores, owner name.
- `lib/screens/settings_screen.dart` — se retiran las secciones "Seguridad" (PIN), "Compartir acceso" y "Sincronización con Google Sheets".
- `lib/services/export_import_service.dart` — se retira `collaboratorsCsv`/la fila `propietario` de `settingsCsv`.
- `lib/core/failures.dart` — se retiran `RemoteFailure`/`UnknownFailure`.
- `pubspec.yaml` — se retira la dependencia `http` (único consumidor era `google_sheets_service.dart`, confirmado por grep).
- `lib/data/remote/datasources/auth_remote_datasource.dart` — su `_kGoogleClientId` pasa a leer desde una única constante en `lib/core/constants.dart`.

**Cómo validar esta fase**:
1. `flutter analyze` limpio (0 errores nuevos).
2. `flutter build web --release` compila.
3. Recorrido manual de las 5 pantallas principales — la app abre directo en Home (sin PIN), Ajustes ya no muestra PIN/Colaboradores/Google Sheets, el resto se ve igual.
4. Exportar CSV — confirmar que el archivo generado ya no incluye la sección de colaboradores/propietario.

**Riesgos**:
- Riesgo: algún usuario real ya configuró un PIN o tiene colaboradores guardados en `SharedPreferences`. Mitigación: como estamos en fase de diagnóstico sin usuarios de producción reales todavía (confirmado en `app_database.dart`), no hay datos que preservar; si esto cambia antes de ejecutar esta fase, se debe re-evaluar.

---

## Fase 2 — Autenticación end-to-end + wiring de Repositories (🔻 CAMBIO v2: fusiona lo que antes eran Fase 1 + Fase 2)

**Objetivo**: la app de producción pasa a tener sesión real de Supabase Auth (vía Google), y `AppState` queda preparado con acceso a `AuthController` y a los Repositories que se irán usando fase por fase.

**Archivos modificados**:
- `lib/main.dart` — se agrega la creación de `AuthController`. Antes de mostrar `HomeScreen`, se verifica `AuthController.currentUser`: si es `null`, se muestra la nueva pantalla de login; si no, pasa directo a `HomeScreen` (login silencioso restaurado automáticamente, ya validado en Fase 0).
- **Nuevo archivo** `lib/screens/google_login_screen.dart` — pantalla mínima que reutiliza `GoogleSignInButton` (se consolidan los dos sets duplicados de `lib/dev/`/`lib/widgets/` en uno solo, apuntando a `AuthController`, ver Grupo B de la revisión de simplificación) y `AuthController.prepareGoogleSignIn()`/`signInWithGoogle()`.
- `lib/state/app_state.dart` — recibe `AuthController` por constructor; se agrega `String? get currentUserId => authController.currentUser?.id;`. Se agregan campos privados para cada Repository nuevo **a medida que cada fase los necesita** (no los 5 de antemano — 🔻 CAMBIO v2).

**Migración de datos existentes**: ninguna en esta fase (el login no mueve datos, solo establece identidad).

**Cómo validar esta fase**:
1. `flutter analyze` limpio.
2. `flutter build web --release` compila.
3. Login con Google funciona igual que en diagnósticos (Fase 0).
4. Sesión persiste tras recargar/reabrir.
5. Cerrar sesión vuelve a mostrar la pantalla de login.

**Pruebas funcionales**:
- Login nuevo usuario Google → Home → resto de la app funciona 100% igual (datos aún en SharedPreferences, todavía no migrados).
- Cerrar y reabrir la pestaña/app → sesión se restaura automáticamente.

**Riesgos y cómo evitarlos**:
- Riesgo: crear una instancia adicional de Repository que abra la base SQLite en paralelo. Mitigación: `AppDatabase` ya es singleton — confirmado por lectura de código, no se asume.

---

## Fase 3 — Categorías (Taxonomía)

**Objetivo**: primer módulo de datos migrado a SQLite+Supabase — el de menor riesgo (sin reglas de recálculo).

**Archivos modificados**:
- `lib/state/app_state.dart`:
  - `_expenseCategories`/`_incomeCategories` pasan a poblarse desde `CategoryRepositoryImpl.getAll(userId)`, mapeando `Category` (nuevo) → `CategoryDef` (legacy). La función de mapeo se escribe aquí mismo (primera vez que se necesita — ver sección 0.5).
  - `addExpenseCategory`, `addIncomeCategory`, `addSubcategory`, `removeCategory`, `removeSubcategory` pasan a usar `CategoryRepositoryImpl.upsert(...)`/`softDelete(...)`.
  - Los getters públicos **no cambian de firma** (siguen devolviendo `List<CategoryDef>`).

**Migración de datos existentes** (una sola vez, inline, sin abstracción — ver sección 0.8):
- Al iniciar `AppState.init()`, si `CategoryRepositoryImpl.getAll(userId)` está vacío Y `storage.loadExpenseCategories()`/`loadIncomeCategories()` tienen datos, se recorren y se hace `upsert` hacia `CategoryRepositoryImpl` (con `id: uuid.v4()`, `userId: currentUserId`, timestamps `DateTime.now()` — sin `createdBy`/`updatedBy`, ya retirados). Marca simple: clave `prospera_categories_migrated_v1` en SharedPreferences.

**Cómo validar**:
1. `flutter analyze` limpio.
2. Categorías/subcategorías idénticas en `manage_taxonomy_screen.dart` antes/después.
3. Confirmar en Supabase Table Editor que `categories` recibió las filas con `user_id` correcto.
4. Repetir el test offline→online de Fase 0 con una categoría real.

**Pruebas funcionales**:
- Crear/eliminar categoría y subcategoría — confirmar reflejo idéntico en todos los formularios que las consumen.

**Riesgos**:
- `Category` (nuevo) tiene `id` propio que `CategoryDef` (legacy) no tiene — confirmado por lectura de código que ninguna pantalla identifica categorías por `id` hoy (todo es por `name`), sin riesgo real.

---

## Fase 4 — Transacciones (núcleo del sistema) ⚠ Mayor riesgo — migra completamente sola

**Objetivo**: el módulo más importante y con más reglas de negocio. No se migra en paralelo con Planificación/Deudas/Objetivos.

**Incluye (🔻 CAMBIO v2, nuevo respecto a v1)**: retirar `createdBy`/`updatedBy` de las 5 entidades de dominio (`Transaction`, `BudgetItem`, `Debt`, `Goal`, `Category`) y del parámetro `deletedBy` de los 5 `softDelete()` — se hace aquí, en la primera fase que efectivamente instancia entidades de dominio en producción, para no tocar dos veces el mismo código.

**Archivos modificados**:
- `lib/domain/entities/{transaction,budget_item,debt,goal,category}.dart` — se retiran los campos `createdBy`/`updatedBy`; `toMap()`/`fromMap()` se ajustan.
- `lib/data/repositories/*_repository_impl.dart` — `softDelete()` deja de recibir `deletedBy` (ya no se usa para nada — solo se necesitaba para poblar `updatedBy`).
- `lib/domain/rules/financial_rules.dart` (**nuevo archivo, único** — 🔻 CAMBIO v2) — sección `// --- Transacciones ---` con las funciones puras portadas literalmente:
  - `signedAmount`/`isEffectivelyInflow` (ya existen idénticos en `domain/entities/transaction.dart` — solo verificación de paridad).
  - `_afterTxnChange` → función pura que `AppState` invoca explícitamente tras cada cambio.
- `lib/state/app_state.dart`:
  - `_txns` pasa a `TransactionRepositoryImpl.getAll(userId)`, mapeando `Transaction` → `Txn`.
  - `addTxn`, `updateTxn`, `deleteTxn`, `duplicateTxn`, `linkTxnToBudget` pasan a usar `TransactionRepositoryImpl.upsert(...)`/`softDelete(...)`.
  - **CRÍTICO**: se preserva exactamente el orden de efectos secundarios (recalcular deuda/objetivo vinculado, etc.).

**Migración de datos existentes**: mismo patrón que Fase 3, marca `prospera_txns_migrated_v1`. Debe ejecutarse DESPUÉS de que Categorías (Fase 3) ya esté migrada.

**Cómo validar**:
1. `flutter analyze` limpio.
2. Test de paridad (`test/parity/financial_rules_parity_test.dart`, sección Transacciones): mismos datos de `SeedData`, mismos resultados de KPIs antes/después.
3. Crear/editar/eliminar/duplicar transacción real — confirmar reflejo idéntico en Resumen/Análisis/Transacciones.
4. Confirmar en Supabase que la fila llegó con `user_id` correcto (sin `created_by`/`updated_by`).
5. Repetir el test offline→online con una transacción real de producción.

**Pruebas funcionales** (lista extensa, núcleo del sistema):
- Ingreso, gasto, aporte/rescate de inversión, pago de deuda — `movementTypeLabel`/`signedAmount`/color correctos.
- Vincular a Deuda/Objetivo → recálculo idéntico. Eliminar vínculo → resta correctamente.
- Duplicar transacción → comportamiento idéntico.
- Marcar "pendiente" ($0) → no afecta KPIs hasta completarse.
- `txnsPendingPlanificacion`/`pendingPlanificacionCount`/`pendingPlanificacionTotal` — funcionan igual.
- `reconcileDeficitRollovers` — funciona igual en el siguiente cierre de mes simulado.

**Riesgos y cómo evitarlos**:
- **Alto**: orden de efectos secundarios roto. Mitigación: test de paridad escrito y ejecutado contra el código legacy ANTES de migrar, para capturar el resultado esperado.
- **Medio**: mapeo incompleto de campos. Mitigación: mapeo transcrito campo por campo, no inferido.
- **Medio**: rendimiento de `getAll()` sin paginación. Mitigación: no es regresión (SharedPreferences también carga todo en memoria) — se optimiza solo si aparece un problema real medido.

---

## Fase 5 — Planificación (Presupuesto)

**Objetivo**: migrar `BudgetItem` — depende de Transacciones (Fase 4) ya migrada.

**Archivos modificados**:
- `lib/domain/rules/financial_rules.dart` — sección `// --- Planificación ---`: `budgetProgressLevelFor`, `realizadoForBudgetItem`, `isBudgetItemCovered`, `budgetsForMonth`, `replicateBudgetMonth`, `replicateBudgetToMany`, `applyBudgetSuggestion`.
- `lib/state/app_state.dart` — `_budgets` pasa a `BudgetRepositoryImpl.getAll(userId)`; CRUD pasa al Repository nuevo.

**Migración de datos existentes**: `prospera_budgets_migrated_v1`.

**Cómo validar**: análogo a fases anteriores + confirmar los 4 niveles de color de KPI dan el mismo resultado.

**Pruebas funcionales**:
- Crear ítem manual, replicar a varios meses — mismas filas que antes.
- Ítems generados automáticamente por Deudas/Objetivos (aún en `AppState` legacy en esta fase, migran en Fases 6–7) siguen escribiendo correctamente en el repositorio nuevo de Planificación desde esta fase en adelante.

**Riesgos**:
- Los generadores automáticos de cuotas (`_generateInstallmentsForDebt`/`_generateContributionsForGoal`) deben apuntar YA al `BudgetRepositoryImpl` nuevo desde esta fase, aunque Deudas/Objetivos en sí sigan en SharedPreferences hasta sus propias fases.

---

## Fase 6 — Deudas

**Archivos modificados**:
- `lib/domain/rules/financial_rules.dart` — sección `// --- Deudas ---`: `_recalcDebt`, `_generateInstallmentsForDebt`, `markNextInstallmentPaid`, `payDebt`.
- `lib/state/app_state.dart` — `_debts` pasa a `DebtRepositoryImpl`.

**Migración de datos existentes**: `prospera_debts_migrated_v1`.

**Pruebas funcionales**:
- Crear deuda → genera cuotas automáticamente en Planificación (ya migrada) igual que antes.
- Pagar cuota → `paidAmount` recalculado igual.
- Eliminar deuda → limpia `BudgetItem` vinculados igual que antes.

**Riesgos**: mismos patrones que Fase 4/5, riesgo medio-bajo.

---

## Fase 7 — Objetivos (Goals)

**Archivos modificados**:
- `lib/domain/rules/financial_rules.dart` — sección `// --- Objetivos ---`: `_recalcGoal`, `_generateContributionsForGoal`, `contributeToGoal`, `withdrawFromGoal`.
- `lib/state/app_state.dart` — `_goals` pasa a `GoalRepositoryImpl`.

**Migración de datos existentes**: `prospera_goals_migrated_v1`.

**Pruebas funcionales**:
- Crear objetivo, aportar, rescatar — `currentAmount` recalculado igual.
- Generación automática de aportes en Planificación igual que antes.

**Riesgos**: análogos a Fase 6.

---

## Fase 8 — Configuración general + limpieza final

**Objetivo**: cerrar la migración — configuración local que permanece en `SharedPreferences` (decisión ya tomada, sección 0.7) y eliminación de todo código legacy sin referencias.

**Archivos modificados**:
- `lib/state/app_state.dart` — tema, período seleccionado, tarjetas visibles permanecen usando `StorageService` (decisión definitiva, no hay tabla `user_settings`).
- `lib/services/export_import_service.dart` — se revisa que siga funcionando con los nuevos getters (que no cambiaron de firma).

**Regla de eliminación (aplica retroactivamente a todo el plan)**:
> Un archivo solo se elimina cuando (a) ya pasó por su fase de migración, (b) `grep -rn "NombreDeLaClaseOArchivo" lib/` da CERO referencias fuera del propio archivo, y (c) `flutter analyze` + `flutter build web --release` siguen limpios tras la eliminación.

**Orden de eliminación**:
1. `lib/state/legacy_mappers.dart` (si llegó a crearse como archivo separado — ver sección 0.5) o las funciones de mapeo inline en `app_state.dart`.
2. `lib/models/{transaction,budget_item,debt,goal,taxonomy,insight,enums}.dart` (en ese orden, verificando cero referencias en cada paso).
3. `lib/services/storage_service.dart` — **sobrevive permanentemente**: sigue siendo la solución final para tema/período/tarjetas visibles (decisión de sección 0.7), no es código legacy.
4. `AppState` se reduce a lo mínimo — para entonces, todos sus métodos son delegaciones de una línea a los Repositories. Ver nota de "futuro" en sección 0 sobre evaluar reemplazarlo por Controllers directos — decisión explícitamente fuera de este plan.

**Cómo validar**: `flutter analyze` + `flutter build web --release` + recorrido manual completo de las 12 pantallas, confirmando comportamiento idéntico al existente antes de iniciar la Fase 0.5.

---

## Fase 9 (opcional, posterior, fuera del alcance inmediato) — Sincronización "pull"

El `SyncEngine` actual solo sube datos (push). Para que un usuario con dos dispositivos vea cambios hechos en el otro, hace falta implementar la descarga de cambios remotos (`applyRemoteRow` ya existe en `GenericLocalDataSource`, pero nada lo invoca todavía). Trabajo de infraestructura, no de pantallas — puede abordarse en cualquier momento después de la Fase 4, sin bloquear ni ser bloqueado por las Fases 5–8.

---

## 7. Test de paridad de reglas financieras (🔻 CAMBIO v2: un solo archivo)

Antes de migrar cada módulo con reglas de recálculo:
1. `test/parity/financial_rules_parity_test.dart` (un solo archivo, secciones por módulo) — toma datos de `SeedData`, calcula con el código LEGACY actual los resultados esperados: `Debt.paidAmount`, `Goal.currentAmount`, KPIs de `resumen_screen.dart`, niveles de `BudgetProgressLevel`.
2. Resultados esperados guardados como constantes en el test (snapshot manual — no se justifica infraestructura de snapshot testing automatizado para este tamaño de proyecto).
3. Tras migrar cada módulo, se ejecuta la sección correspondiente del mismo test contra el código nuevo y se confirma resultado idéntico.
4. Este test se mantiene en el repositorio como red de seguridad permanente.

---

## 8. Checklist de validación aplicable a TODAS las fases

- [ ] `flutter analyze` — 0 errores nuevos.
- [ ] `flutter build web --release` — compila sin errores.
- [ ] Recorrido manual de las pantallas afectadas — comportamiento visualmente idéntico al anterior.
- [ ] Si la fase migra datos: confirmar en Supabase Table Editor `user_id` correcto y campos esperados (sin `created_by`/`updated_by`, retirados en Fase 4).
- [ ] Si la fase migra datos: sección correspondiente del test de paridad da resultados idénticos.
- [ ] Repetir el test offline→online (Fase 0) con datos reales del módulo recién migrado.
- [ ] Ningún archivo eliminado fuera de lo explícitamente indicado en esa fase.
- [ ] Commit separado por fase, nunca mezclar dos fases en un mismo commit.
- [ ] Solo entonces, pedir aprobación explícita para iniciar la fase siguiente.

---

## 9. Resumen de riesgos globales y mitigación transversal

| Riesgo | Mitigación |
|---|---|
| Migrar dos módulos importantes a la vez | Prohibido por diseño de fases (Fase 4 va sola; 5/6/7 una por una) |
| Perder datos existentes al migrar de SharedPreferences a SQLite | Volcado único y automático por módulo, nunca se borra el dato legacy hasta confirmar éxito |
| Reglas financieras alteradas sin darse cuenta | Copia literal a `domain/rules/financial_rules.dart` + test de paridad, nunca reescritura desde cero |
| Pantallas rotas por cambio de firma de `AppState` | La fachada preserva EXACTAMENTE los mismos getters/métodos públicos durante toda la migración |
| Código especulativo sin validar durante varias fases | Eliminado por diseño en v2: mapeos y campos de Repository se crean en la fase donde se usan, no antes |
| Eliminar un archivo todavía referenciado | Regla formal de eliminación (grep de cero referencias + build limpio, nunca por asunción) |
| Fase deja la app sin compilar o sin funcionar | Checklist obligatorio al final de cada fase |
| `AppState` como intermediario permanente de 1700+ líneas | Documentado como evaluación futura post-migración (sección 0), no se decide ahora |

---

## 10. Qué se necesita de vos para arrancar

Ya no quedan decisiones puntuales pendientes por fase (ver sección 3) — solo se necesita:

1. **Aprobar este plan revisado en general** (8 fases, estrategia de fachada/convivencia, y todos los cambios de simplificación listados en la sección 0).

Una vez aprobado, se comienza por la **Fase 0.5** (limpieza de simplificación, cero dato real migrado todavía) y se avanza fase por fase, pidiendo validación después de cada una antes de continuar.
