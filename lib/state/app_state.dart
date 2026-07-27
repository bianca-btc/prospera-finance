import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/enums.dart';
import '../models/transaction.dart';
import '../models/budget_item.dart';
import '../models/goal.dart';
import '../models/debt.dart';
import '../models/insight.dart';
import '../models/taxonomy.dart';
import '../models/collaborator.dart';
import '../services/storage_service.dart';
import '../services/seed_data.dart';
import '../services/insights_engine.dart';
import '../utils/period.dart';

const _uuid = Uuid();

/// Chaves dos cards que podem aparecer no Resumen — usadas para a
/// personalização de tela inicial (o usuário escolhe o que quer ver).
const List<String> allResumenCardKeys = [
  'resumo_inteligente',
  'principales_gastos',
  'proximos_vencimientos',
  'objetivos',
];

/// Faixas de progresso do KPI de Gastos (% do planejado).
enum BudgetProgressLevel { verde, amarillo, naranja, rojo }

BudgetProgressLevel budgetProgressLevelFor(double ratio) {
  if (ratio <= 0.70) return BudgetProgressLevel.verde;
  if (ratio <= 0.90) return BudgetProgressLevel.amarillo;
  if (ratio <= 1.00) return BudgetProgressLevel.naranja;
  return BudgetProgressLevel.rojo;
}

/// Estado global do app Prospera: transações, orçamentos, objetivos,
/// dívidas, taxonomias customizáveis e filtro de período.
///
/// ================= PRINCÍPIO DE FONTE ÚNICA DE VERDADE =================
/// Nenhuma informação existe em mais de um lugar. Especificamente:
/// - O valor "pagado" de uma Deuda ([Debt.paidAmount]) e o "acumulado" de
///   um Objetivo ([InvestmentGoal.currentAmount]) NUNCA são editados
///   manualmente: são recalculados automaticamente a partir da soma das
///   transações vinculadas (Txn.debtId / Txn.goalId) sempre que uma
///   transação é criada, editada ou removida (ver [_recalcDebt] /
///   [_recalcGoal], chamados a partir de todo CRUD de Txn).
/// - Dívidas e Objetivos geram automaticamente itens de Planificación
///   (BudgetItem.linkedDebtId / linkedGoalId) — o usuário nunca cria
///   parcelas ou aportes manualmente no planejamento.
/// - Todas as áreas (KPIs, Resumen, Planificación, Análisis) leem sempre
///   os mesmos dados-base (txns/budgets/goals/debts), nunca calculam uma
///   cópia paralela.
/// =========================================================================
class AppState extends ChangeNotifier {
  final StorageService storage;
  AppState(this.storage);

  List<Txn> _txns = [];
  List<BudgetItem> _budgets = [];
  List<InvestmentGoal> _goals = [];
  List<Debt> _debts = [];
  List<CategoryDef> _expenseCategories = [];
  List<CategoryDef> _incomeCategories = [];
  List<String> _countries = [];
  List<Collaborator> _collaborators = [];
  List<String> _visibleCards = List.from(allResumenCardKeys);

  PeriodRange _selectedRange = PeriodRange.singleMonth(
    YearMonth.fromDate(DateTime.now()),
  );
  ThemeMode _themeMode = ThemeMode.dark;
  String? _pin;
  bool _unlocked = false;
  String? _shareToken;
  String _ownerName = 'Propietario';

  bool _loading = true;
  bool get loading => _loading;

  // ---------------- Getters públicos ----------------
  List<Txn> get txns => List.unmodifiable(_txns);
  List<BudgetItem> get budgets => List.unmodifiable(_budgets);
  List<InvestmentGoal> get goals => List.unmodifiable(_goals);
  List<Debt> get debts => List.unmodifiable(_debts);
  List<CategoryDef> get expenseCategories =>
      List.unmodifiable(_expenseCategories);
  List<CategoryDef> get incomeCategories =>
      List.unmodifiable(_incomeCategories);
  List<String> get countries => List.unmodifiable(_countries);
  List<Collaborator> get collaborators => List.unmodifiable(_collaborators);
  List<String> get visibleCards => List.unmodifiable(_visibleCards);

  PeriodRange get selectedRange => _selectedRange;
  Set<YearMonth> get selectedPeriods => _selectedRange.monthSet;

  ThemeMode get themeMode => _themeMode;
  bool get hasPin => _pin != null && _pin!.isNotEmpty;
  bool get unlocked => _unlocked;
  String? get shareToken => _shareToken;
  String get ownerName => _ownerName;

  // ---------------- Inicialização ----------------
  Future<void> init() async {
    await storage.init();

    _themeMode = storage.loadThemeMode() == 'light'
        ? ThemeMode.light
        : ThemeMode.dark;
    _pin = storage.loadPin();
    _unlocked = !hasPin;
    _shareToken = storage.loadShareToken();
    _ownerName = storage.loadOwnerName();

    if (!storage.isSeeded) {
      await _seed();
    } else {
      _loadFromStorage();
    }

    // Garante países mínimos exigidos mesmo em bases já existentes.
    for (final c in SeedData.countries()) {
      if (!_countries.contains(c)) _countries.add(c);
    }

    final savedRange = storage.loadPeriodRange();
    if (savedRange != null) {
      _selectedRange = PeriodRange.fromJson(savedRange);
    } else if (_txns.isNotEmpty) {
      final months =
          _txns.map((t) => YearMonth(t.year, t.month)).toSet().toList()..sort();
      _selectedRange = PeriodRange.singleMonth(months.last);
    } else {
      _selectedRange = PeriodRange.singleMonth(
        YearMonth.fromDate(DateTime.now()),
      );
    }

    final savedCards = storage.loadVisibleCards();
    if (savedCards != null && savedCards.isNotEmpty) {
      _visibleCards = savedCards;
    }

    reconcileDeficitRollovers();
    // Limpia ítems de planificación "huérfanos" (vinculados a una Deuda u
    // Objetivo que ya no existe) y duplicados — puede ocurrir en bases
    // antiguas migradas donde la deuda/objetivo fue eliminada antes de que
    // existiera la limpieza automática de vínculos. Sin esto, aparecían
    // notificaciones de "próximos vencimientos" para planificaciones que
    // el usuario ya había borrado.
    var purged = _purgeOrphanedAndDuplicateBudgetItems();
    // BUGFIX (vencimentos fantasma): bases criadas antes da correção de
    // `installmentDates()`/`contributionDates()` podem ter itens de
    // planejamento com `dueDate`/mês "vazados" para o mês seguinte (ex.:
    // dia 31 gerado num mês de 30 dias). Para reconciliar dados legados,
    // removemos e regeneramos TODOS os itens vinculados a Deudas/Objetivos
    // com as datas já corrigidas — mesmo comportamento que já ocorre
    // normalmente ao editar uma Deuda/Objetivo ([updateDebt]/[updateGoal]),
    // então é seguro repetir aqui. Nunca afeta transações (vinculadas por
    // debtId/goalId, não por budgetItemId).
    _budgets.removeWhere((b) => b.linkedDebtId != null);
    _budgets.removeWhere((b) => b.linkedGoalId != null);
    purged = true;
    // Garante que dívidas/objetivos tenham seus itens de planejamento e
    // que os valores acumulados estejam sincronizados com as transações
    // (fonte única de verdade), mesmo em bases antigas migradas.
    _recalcAllDebtsAndGoals();
    for (final d in _debts) {
      _generateInstallmentsForDebt(d);
    }
    for (final g in _goals) {
      _generateContributionsForGoal(g);
    }
    if (purged) {
      await _persistBudgets();
    }

    _loading = false;
    notifyListeners();
  }

  /// Elimina de [_budgets] cualquier ítem "huérfano" — vinculado
  /// (`linkedDebtId`/`linkedGoalId`) a una Deuda u Objetivo que ya no
  /// existe en la base — y también deduplica ítems generados dos veces
  /// para el mismo mes+vínculo (mismo bug de origen: datos legados de
  /// antes de que existiera la deduplicación en
  /// [_generateInstallmentsForDebt]/[_generateContributionsForGoal]).
  /// Devuelve `true` si algo fue eliminado (para saber si hay que
  /// persistir). Nunca toca transacciones ni KPIs.
  bool _purgeOrphanedAndDuplicateBudgetItems() {
    final debtIds = _debts.map((d) => d.id).toSet();
    final goalIds = _goals.map((g) => g.id).toSet();
    final before = _budgets.length;

    // 1) Huérfanos: apuntan a un id de deuda/objetivo que ya no existe.
    _budgets.removeWhere((b) {
      if (b.linkedDebtId != null && !debtIds.contains(b.linkedDebtId)) {
        return true;
      }
      if (b.linkedGoalId != null && !goalIds.contains(b.linkedGoalId)) {
        return true;
      }
      return false;
    });

    // 2) Duplicados: más de un ítem para el mismo mes+deuda o mes+objetivo.
    final seenDebt = <String>{};
    final seenGoal = <String>{};
    _budgets.removeWhere((b) {
      if (b.linkedDebtId != null) {
        final key = '${b.year}-${b.month}-${b.linkedDebtId}';
        if (seenDebt.contains(key)) return true;
        seenDebt.add(key);
      }
      if (b.linkedGoalId != null) {
        final key = '${b.year}-${b.month}-${b.linkedGoalId}';
        if (seenGoal.contains(key)) return true;
        seenGoal.add(key);
      }
      return false;
    });

    return _budgets.length != before;
  }

  Future<void> _seed() async {
    _txns = SeedData.buildTransactions();
    _budgets = SeedData.buildBudgets();
    _expenseCategories = SeedData.expenseCategories();
    _incomeCategories = SeedData.incomeCategories();
    _countries = SeedData.countries();
    _goals = SeedData.goals();
    _debts = SeedData.debts();
    _collaborators = [];
    await _persistAll();
    await storage.setSeeded();
  }

  void _loadFromStorage() {
    _txns = storage.loadTxns().map(Txn.fromJson).toList();
    _budgets = storage.loadBudgets().map(BudgetItem.fromJson).toList();
    _goals = storage.loadGoals().map(InvestmentGoal.fromJson).toList();
    _debts = storage.loadDebts().map(Debt.fromJson).toList();
    _expenseCategories = storage
        .loadExpenseCategories()
        .map(CategoryDef.fromJson)
        .toList();
    _incomeCategories = storage
        .loadIncomeCategories()
        .map(CategoryDef.fromJson)
        .toList();
    _countries = storage.loadCountries();
    _collaborators = storage
        .loadCollaborators()
        .map(Collaborator.fromJson)
        .toList();

    if (_expenseCategories.isEmpty) {
      _expenseCategories = SeedData.expenseCategories();
    }
    if (_incomeCategories.isEmpty) {
      _incomeCategories = SeedData.incomeCategories();
    }
    if (_countries.isEmpty) _countries = SeedData.countries();
  }

  Future<void> _persistAll() async {
    await storage.saveTxns(_txns.map((e) => e.toJson()).toList());
    await storage.saveBudgets(_budgets.map((e) => e.toJson()).toList());
    await storage.saveGoals(_goals.map((e) => e.toJson()).toList());
    await storage.saveDebts(_debts.map((e) => e.toJson()).toList());
    await storage.saveExpenseCategories(
      _expenseCategories.map((e) => e.toJson()).toList(),
    );
    await storage.saveIncomeCategories(
      _incomeCategories.map((e) => e.toJson()).toList(),
    );
    await storage.saveCountries(_countries);
    await storage.saveCollaborators(
      _collaborators.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> _persistTxns() async {
    await storage.saveTxns(_txns.map((e) => e.toJson()).toList());
  }

  Future<void> _persistBudgets() async {
    await storage.saveBudgets(_budgets.map((e) => e.toJson()).toList());
  }

  Future<void> _persistGoals() async {
    await storage.saveGoals(_goals.map((e) => e.toJson()).toList());
  }

  Future<void> _persistDebts() async {
    await storage.saveDebts(_debts.map((e) => e.toJson()).toList());
  }

  Future<void> _persistCategories() async {
    await storage.saveExpenseCategories(
      _expenseCategories.map((e) => e.toJson()).toList(),
    );
    await storage.saveIncomeCategories(
      _incomeCategories.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> _persistCountries() async {
    await storage.saveCountries(_countries);
  }

  Future<void> _persistCollaborators() async {
    await storage.saveCollaborators(
      _collaborators.map((e) => e.toJson()).toList(),
    );
  }

  // ---------------- Segurança (PIN) ----------------
  Future<void> setPin(String? pin) async {
    _pin = pin;
    await storage.savePin(pin);
    notifyListeners();
  }

  bool tryUnlock(String pin) {
    if (_pin == null || _pin == pin) {
      _unlocked = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void lock() {
    if (hasPin) {
      _unlocked = false;
      notifyListeners();
    }
  }

  // ---------------- Tema ----------------
  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await storage.saveThemeMode(
      _themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
    notifyListeners();
  }

  // ---------------- Compartilhamento ----------------
  Future<String> generateShareLink() async {
    final token = _uuid.v4().replaceAll('-', '').substring(0, 16);
    _shareToken = token;
    await storage.saveShareToken(token);
    notifyListeners();
    return token;
  }

  Future<void> revokeShareLink() async {
    _shareToken = null;
    await storage.saveShareToken(null);
    notifyListeners();
  }

  Future<void> setOwnerName(String name) async {
    _ownerName = name;
    await storage.saveOwnerName(name);
    notifyListeners();
  }

  // ---------------- Colaboradores (Propietario/Editor/Visualizador) ----------------
  Future<void> addCollaborator(Collaborator c) async {
    _collaborators.add(c);
    await _persistCollaborators();
    notifyListeners();
  }

  Future<void> updateCollaboratorRole(String id, ShareRole role) async {
    final idx = _collaborators.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _collaborators[idx] = _collaborators[idx].copyWith(role: role);
      await _persistCollaborators();
      notifyListeners();
    }
  }

  Future<void> removeCollaborator(String id) async {
    _collaborators.removeWhere((c) => c.id == id);
    await _persistCollaborators();
    notifyListeners();
  }

  // ---------------- Personalização de cards ----------------
  Future<void> setVisibleCards(List<String> keys) async {
    _visibleCards = keys;
    await storage.saveVisibleCards(keys);
    notifyListeners();
  }

  Future<void> toggleCardVisible(String key) async {
    if (_visibleCards.contains(key)) {
      _visibleCards = _visibleCards.where((k) => k != key).toList();
    } else {
      _visibleCards = [..._visibleCards, key];
    }
    await storage.saveVisibleCards(_visibleCards);
    notifyListeners();
  }

  // ---------------- Filtro de período (estilo Google Analytics) ----------------
  void setSelectedRange(PeriodRange range) {
    _selectedRange = range;
    storage.savePeriodRange(range.toJson());
    notifyListeners();
  }

  void selectSingleMonth(YearMonth ym) =>
      setSelectedRange(PeriodRange.singleMonth(ym));

  void selectLastNMonths(int n) => setSelectedRange(PeriodRange.lastNMonths(n));

  /// Garante que [ym] esteja incluído no período selecionado, expandindo o
  /// intervalo automaticamente se necessário. Usado pelas ações rápidas
  /// (Aportar/Rescatar/Pagar deuda), que sempre registram el movimiento con
  /// la fecha de HOY: sin esto, si el usuario está viendo un período
  /// histórico (ej. datos de demostración de un año anterior) que no
  /// incluye el mes actual, el movimiento se crea correctamente (la
  /// Deuda/Objetivo se actualiza) pero el KPI header — que sí filtra por
  /// [selectedPeriods] — nunca mostraría el cambio, dando la falsa
  /// impresión de que el rescate/aporte/pago "no funcionó".
  void _ensurePeriodIncludes(YearMonth ym) {
    if (_selectedRange.monthSet.contains(ym)) return;
    final s = _selectedRange.start.compareTo(ym) <= 0
        ? _selectedRange.start
        : ym;
    final e = _selectedRange.end.compareTo(ym) >= 0 ? _selectedRange.end : ym;
    setSelectedRange(PeriodRange(s, e));
  }

  /// Todos os anos conhecidos (com dados) + o ano atual, para popular o
  /// seletor sem jamais limitar os anos disponíveis (o usuário sempre pode
  /// digitar/escolher qualquer ano manualmente na UI, mas isto alimenta os
  /// atalhos de navegação rápida).
  List<int> get knownYears {
    final Set<int> years = {};
    for (final t in _txns) {
      years.add(t.year);
    }
    for (final b in _budgets) {
      years.add(b.year);
    }
    years.add(DateTime.now().year);
    final list = years.toList()..sort();
    return list;
  }

  // ================= Transações CRUD (fonte única de verdade) =================
  // Toda vez que uma transação vinculada a uma dívida/objetivo é criada,
  // editada ou removida, recalculamos automaticamente o valor pagado/
  // acumulado dessa dívida/objetivo — nunca é preciso atualizar em dois
  // lugares.

  Future<void> addTxn(Txn txn) async {
    _txns.add(txn);
    await _persistTxns();
    _applyDeficitRolloverIfNeeded(YearMonth(txn.year, txn.month));
    await _afterTxnChange(oldTxn: null, newTxn: txn);
    notifyListeners();
  }

  Future<void> updateTxn(Txn txn) async {
    final idx = _txns.indexWhere((t) => t.id == txn.id);
    if (idx != -1) {
      final old = _txns[idx];
      _txns[idx] = txn;
      await _persistTxns();
      await _afterTxnChange(oldTxn: old, newTxn: txn);
      notifyListeners();
    }
  }

  Future<void> deleteTxn(String id) async {
    final idx = _txns.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final old = _txns[idx];
    _txns.removeAt(idx);
    await _persistTxns();
    await _afterTxnChange(oldTxn: old, newTxn: null);
    notifyListeners();
  }

  Future<void> duplicateTxn(String id) async {
    final t = _txns.firstWhere((t) => t.id == id);
    final copy = Txn(
      id: _uuid.v4(),
      type: t.type,
      status: TxStatus.pendiente,
      country: t.country,
      category: t.category,
      subcategory: t.subcategory,
      amount: t.amount,
      date: t.date,
      description: t.description,
      scope: t.scope,
    );
    _txns.add(copy);
    await _persistTxns();
    notifyListeners();
  }

  /// Recalcula dívidas/objetivos afetados por uma mudança de transação
  /// (criação/edição/remoção), mantendo a única fonte de verdade sempre
  /// sincronizada em todas as telas.
  Future<void> _afterTxnChange({Txn? oldTxn, Txn? newTxn}) async {
    final affectedDebtIds = <String>{};
    final affectedGoalIds = <String>{};
    if (oldTxn?.debtId != null) affectedDebtIds.add(oldTxn!.debtId!);
    if (newTxn?.debtId != null) affectedDebtIds.add(newTxn!.debtId!);
    if (oldTxn?.goalId != null) affectedGoalIds.add(oldTxn!.goalId!);
    if (newTxn?.goalId != null) affectedGoalIds.add(newTxn!.goalId!);

    var debtsChanged = false;
    var goalsChanged = false;
    for (final id in affectedDebtIds) {
      if (_recalcDebt(id)) debtsChanged = true;
    }
    for (final id in affectedGoalIds) {
      if (_recalcGoal(id)) goalsChanged = true;
    }
    if (debtsChanged) await _persistDebts();
    if (goalsChanged) await _persistGoals();
  }

  /// Recalcula [Debt.paidAmount] como soma de todas as transações
  /// vinculadas (Txn.debtId == debtId). Retorna true se o valor mudou.
  bool _recalcDebt(String debtId) {
    final idx = _debts.indexWhere((d) => d.id == debtId);
    if (idx == -1) return false;
    final total = _txns
        .where((t) => t.debtId == debtId)
        .fold(0.0, (s, t) => s + t.amount);
    if ((total - _debts[idx].paidAmount).abs() < 0.005) return false;
    _debts[idx] = _debts[idx].copyWith(paidAmount: total);
    return true;
  }

  /// Recalcula [InvestmentGoal.currentAmount] como soma de todas as
  /// transações vinculadas (Txn.goalId == goalId). Os RESCATES
  /// ([Txn.isWithdrawal] == true) restam do total en vez de sumar —
  /// mantém [InvestmentGoal.currentAmount] como fonte única de verdade,
  /// refletindo aportes e retiros. Retorna true se mudou.
  bool _recalcGoal(String goalId) {
    final idx = _goals.indexWhere((g) => g.id == goalId);
    if (idx == -1) return false;
    final total = _txns
        .where((t) => t.goalId == goalId)
        .fold(0.0, (s, t) => t.isWithdrawal ? s - t.amount : s + t.amount);
    if ((total - _goals[idx].currentAmount).abs() < 0.005) return false;
    _goals[idx] = _goals[idx].copyWith(currentAmount: total);
    return true;
  }

  void _recalcAllDebtsAndGoals() {
    for (final d in _debts) {
      _recalcDebt(d.id);
    }
    for (final g in _goals) {
      _recalcGoal(g.id);
    }
  }

  /// Sugere uma vinculação automática quando uma nova transação corresponde
  /// a um item de planejamento ativo neste mês (mesma categoria+subcategoria,
  /// ainda sem transações que a cubram totalmente). Retorna o [BudgetItem]
  /// candidato, ou null se não houver sugestão relevante. Funciona para
  /// QUALQUER item de planejamento (não apenas os vinculados a Deuda/Objetivo)
  /// — é a base do fluxo "toda transação deve ter um plan vinculado".
  BudgetItem? suggestBudgetLinkFor(Txn txn) {
    if (txn.type == TxType.ingreso) return null;
    final ym = YearMonth(txn.year, txn.month);
    final candidates = _budgets.where(
      (b) =>
          b.year == ym.year &&
          b.month == ym.month &&
          b.category == txn.category &&
          b.subcategory == txn.subcategory &&
          // Nunca sugerir un plan de Inversión/Deuda: esos solo reciben
          // movimientos generados desde su propia planificación (Aportar/
          // Rescatar/Realizar pago), jamás un gasto manual coincidente por
          // categoría+subcategoría.
          !b.isDebtInstallment &&
          !b.isGoalContribution,
    );
    if (candidates.isEmpty) return null;
    return candidates.first;
  }

  /// Todos os itens de planejamento de um mês específico — usado pelo
  /// seletor "Planificación" no formulário de transação (D), para que o
  /// usuário sempre possa vincular a transação a um plan já existente.
  List<BudgetItem> budgetsForMonth(YearMonth ym) {
    return _budgets
        .where((b) => b.year == ym.year && b.month == ym.month)
        .toList()
      ..sort(
        (a, b) => '${a.category}${a.subcategory}'.compareTo(
          '${b.category}${b.subcategory}',
        ),
      );
  }

  /// Busca (ou cria) o item de planejamento genérico "Otros" de um mês —
  /// fallback usado quando o usuário registra una transacción fuera de
  /// cualquier plan y decide no crear uno específico. Garante que TODA
  /// transação sempre tenha um plan vinculado (sem duplicar información).
  Future<BudgetItem> getOrCreateOtrosBudgetItem({
    required YearMonth ym,
    required String country,
  }) async {
    final existing = _budgets.where(
      (b) =>
          b.year == ym.year &&
          b.month == ym.month &&
          b.category == 'Otros' &&
          b.linkedDebtId == null &&
          b.linkedGoalId == null,
    );
    if (existing.isNotEmpty) return existing.first;
    final item = BudgetItem(
      id: _uuid.v4(),
      month: ym.month,
      year: ym.year,
      category: 'Otros',
      subcategory: 'Varios',
      country: country,
      planned: 0,
      description:
          'Planificación genérica para gastos que no fueron asignados a un plan específico.',
    );
    _budgets.add(item);
    await _persistBudgets();
    notifyListeners();
    return item;
  }

  /// Total realizado (transações executadas) vinculado a um item de
  /// planejamento — considera o vínculo explícito [Txn.budgetItemId], os
  /// vínculos automáticos de Deuda/Objetivo, e (para compatibilidade com
  /// dados antigos) o casamento por categoria+subcategoria+mês quando a
  /// transação não tem nenhum vínculo explícito. Fonte única de verdade
  /// para saber se um plan já está "cubierto" — substitui o antigo campo
  /// manual de Estado (pagado/pendiente).
  double realizadoForBudgetItem(BudgetItem b) {
    final ym = YearMonth(b.year, b.month);
    return _txns
        .where((t) {
          if (YearMonth(t.year, t.month) != ym) return false;
          if (t.budgetItemId == b.id) return true;
          if (b.linkedDebtId != null && t.debtId == b.linkedDebtId) return true;
          if (b.linkedGoalId != null && t.goalId == b.linkedGoalId) return true;
          if (t.budgetItemId == null &&
              t.debtId == null &&
              t.goalId == null &&
              t.category == b.category &&
              t.subcategory == b.subcategory) {
            return true;
          }
          return false;
        })
        .fold(0.0, (s, t) => s + t.amount);
  }

  /// Um item de planejamento é considerado "cubierto" quando o realizado
  /// já alcançou o valor planejado — usado no lugar do antigo campo manual
  /// de Estado para decidir o que ainda está pendente de pago.
  bool isBudgetItemCovered(BudgetItem b) =>
      b.planned > 0 && realizadoForBudgetItem(b) >= b.planned - 0.01;

  /// Cantidad de transacciones vinculadas a un ítem de planificación —
  /// misma lógica de coincidencia que [realizadoForBudgetItem] (vínculo
  /// explícito o fallback por categoría+subcategoría+mes), pero contando
  /// registros en vez de sumar montos. Usado en las nuevas tarjetas de
  /// Planificación para mostrar "N transacciones".
  int txnCountForBudgetItem(BudgetItem b) {
    final ym = YearMonth(b.year, b.month);
    return _txns.where((t) {
      if (YearMonth(t.year, t.month) != ym) return false;
      if (t.budgetItemId == b.id) return true;
      if (b.linkedDebtId != null && t.debtId == b.linkedDebtId) return true;
      if (b.linkedGoalId != null && t.goalId == b.linkedGoalId) return true;
      if (t.budgetItemId == null &&
          t.debtId == null &&
          t.goalId == null &&
          t.category == b.category &&
          t.subcategory == b.subcategory) {
        return true;
      }
      return false;
    }).length;
  }

  /// Cantidad de aportes (excluye rescates) vinculados a un objetivo de
  /// inversión — usado en la tarjeta de Objetivo para mostrar "N aportes".
  int txnCountForGoal(String goalId) =>
      _txns.where((t) => t.goalId == goalId && !t.isWithdrawal).length;

  /// Lista completa (más reciente primero) de las transacciones vinculadas
  /// a un ítem de planificación — misma lógica de coincidencia que
  /// [realizadoForBudgetItem]/[txnCountForBudgetItem]. Usada para mostrar
  /// el historial de movimientos dentro de la tarjeta expandida.
  List<Txn> txnsForBudgetItem(BudgetItem b) {
    final ym = YearMonth(b.year, b.month);
    final list = _txns.where((t) {
      if (YearMonth(t.year, t.month) != ym) return false;
      if (t.budgetItemId == b.id) return true;
      if (b.linkedDebtId != null && t.debtId == b.linkedDebtId) return true;
      if (b.linkedGoalId != null && t.goalId == b.linkedGoalId) return true;
      if (t.budgetItemId == null &&
          t.debtId == null &&
          t.goalId == null &&
          t.category == b.category &&
          t.subcategory == b.subcategory) {
        return true;
      }
      return false;
    }).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Lista completa (más reciente primero) de los pagos vinculados a una
  /// deuda — usada para mostrar el historial de pagos dentro de la tarjeta
  /// expandida de Deuda.
  List<Txn> txnsForDebt(String debtId) {
    final list = _txns.where((t) => t.debtId == debtId).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Lista completa (más reciente primero) de aportes/rescates vinculados
  /// a un objetivo de inversión — usada para mostrar el historial dentro
  /// de la tarjeta expandida de Objetivo.
  List<Txn> txnsForGoal(String goalId) {
    final list = _txns.where((t) => t.goalId == goalId).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  // ---------------- Orçamentos (Planificación) CRUD ----------------
  Future<void> addBudget(BudgetItem item) async {
    _budgets.add(item);
    await _persistBudgets();
    notifyListeners();
  }

  Future<void> updateBudget(BudgetItem item) async {
    final idx = _budgets.indexWhere((b) => b.id == item.id);
    if (idx != -1) {
      _budgets[idx] = item;
      await _persistBudgets();
      notifyListeners();
    }
  }

  /// Elimina un ítem de Planificación (Presupuesto). Una planificación
  /// NUNCA es propietaria de transacciones — solo las organiza. Por eso,
  /// eliminarla JAMÁS borra ni altera ninguna transacción financiera, ni
  /// ningún KPI, Dashboard, gráfico o relatório: únicamente se retira el
  /// VÍNCULO (budgetItemId) y las transacciones afectadas quedan marcadas
  /// como "Pendente de planificación" para que el usuario las reorganice.
  Future<void> deleteBudget(String id) async {
    _budgets.removeWhere((b) => b.id == id);

    for (var i = 0; i < _txns.length; i++) {
      final t = _txns[i];
      if (t.budgetItemId == id) {
        _txns[i] = t.copyWith(
          clearBudgetItemId: true,
          needsPlanificacionLink: true,
        );
      }
    }

    await _persistBudgets();
    await _persistTxns();
    assert(
      validateFinancialIntegrity(),
      'La eliminación de la planificación violó la integridad financiera',
    );
    notifyListeners();
  }

  /// Replica o planejamento de um mês para um conjunto de meses de destino
  /// (Planificación > Replicar). Suporta: próximo mês, N meses consecutivos,
  /// meses específicos ou ano inteiro — bastando informar a lista de
  /// [targets]. Nunca copia transações executadas, apenas o planejamento
  /// (categorias, valores, prioridades, dívidas e objetivos vinculados).
  Future<void> replicateBudgetMonth({
    required YearMonth from,
    required YearMonth to,
  }) => replicateBudgetToMany(from: from, targets: [to]);

  Future<void> replicateBudgetToMany({
    required YearMonth from,
    required List<YearMonth> targets,
  }) async {
    final source = _budgets
        .where((b) => b.year == from.year && b.month == from.month)
        .toList();
    for (final to in targets) {
      for (final b in source) {
        final exists = _budgets.any(
          (x) =>
              x.year == to.year &&
              x.month == to.month &&
              x.category == b.category &&
              x.subcategory == b.subcategory &&
              x.country == b.country,
        );
        if (!exists) {
          _budgets.add(
            BudgetItem(
              id: _uuid.v4(),
              month: to.month,
              year: to.year,
              category: b.category,
              subcategory: b.subcategory,
              country: b.country,
              planned: b.planned,
              priority: b.priority,
              status: TxStatus.pendiente,
              description: b.description,
              dueDate: b.dueDate != null
                  ? safeMonthDate(to.year, to.month, b.dueDate!.day)
                  : null,
              // Dívidas/objetivos não são replicados manualmente: eles já
              // geram seus próprios itens mensais automaticamente.
              linkedDebtId: null,
              linkedGoalId: null,
            ),
          );
        }
      }
    }
    await _persistBudgets();
    notifyListeners();
  }

  /// Replica um conjunto ESPECÍFICO de itens de planejamento (por id) para
  /// os meses de destino informados — usado pela seleção múltipla da tela
  /// de Planificación, quando o usuário quer replicar só alguns itens (não
  /// o mês inteiro, como faz [replicateBudgetToMany]). Cada item gera um
  /// novo registro independente (novo id) por mês de destino; nunca copia
  /// dívidas/objetivos vinculados (esses geram seus próprios itens
  /// automaticamente).
  Future<int> replicateBudgetItemsToMany({
    required List<String> budgetIds,
    required List<YearMonth> targets,
  }) async {
    final source = _budgets
        .where(
          (b) =>
              budgetIds.contains(b.id) &&
              !b.isDebtInstallment &&
              !b.isGoalContribution,
        )
        .toList();
    var created = 0;
    for (final to in targets) {
      for (final b in source) {
        final exists = _budgets.any(
          (x) =>
              x.year == to.year &&
              x.month == to.month &&
              x.category == b.category &&
              x.subcategory == b.subcategory &&
              x.country == b.country,
        );
        if (!exists) {
          _budgets.add(
            BudgetItem(
              id: _uuid.v4(),
              month: to.month,
              year: to.year,
              category: b.category,
              subcategory: b.subcategory,
              country: b.country,
              planned: b.planned,
              priority: b.priority,
              status: TxStatus.pendiente,
              description: b.description,
              dueDate: b.dueDate != null
                  ? safeMonthDate(to.year, to.month, b.dueDate!.day)
                  : null,
            ),
          );
          created++;
        }
      }
    }
    if (created > 0) {
      await _persistBudgets();
      notifyListeners();
    }
    return created;
  }

  /// Quantas transações ficarão marcadas como "pendentes de planificación"
  /// se os itens [budgetIds] forem excluídos — usado para mostrar a
  /// confirmação de exclusão em massa ANTES de executar, sem nunca apagar
  /// nada silenciosamente (mesma regra do [deleteBudget] individual).
  int countTxnsAffectedByBudgetDeletion(List<String> budgetIds) {
    final idSet = budgetIds.toSet();
    return _txns
        .where((t) => t.budgetItemId != null && idSet.contains(t.budgetItemId))
        .length;
  }

  /// Exclui em massa um conjunto de itens de planejamento (Gasto normal,
  /// não Deuda/Objetivo — esses são excluídos individualmente pelas suas
  /// próprias telas). Segue exatamente a mesma regra do [deleteBudget]
  /// individual: NUNCA apaga transações, apenas desvincula e marca
  /// [Txn.needsPlanificacionLink] = true para reorganização posterior.
  Future<void> deleteBudgetsBulk(List<String> budgetIds) async {
    final idSet = budgetIds.toSet();
    _budgets.removeWhere((b) => idSet.contains(b.id));
    for (var i = 0; i < _txns.length; i++) {
      final t = _txns[i];
      if (t.budgetItemId != null && idSet.contains(t.budgetItemId)) {
        _txns[i] = t.copyWith(
          clearBudgetItemId: true,
          needsPlanificacionLink: true,
        );
      }
    }
    await _persistBudgets();
    await _persistTxns();
    assert(
      validateFinancialIntegrity(),
      'La eliminación en masa de planificaciones violó la integridad financiera',
    );
    notifyListeners();
  }

  /// Aplica ao mês [target] a sugestão de orçamento gerada pelo motor de
  /// inteligência (baseada na média histórica), sem duplicar itens já
  /// existentes para a mesma categoria+subcategoria+país.
  Future<void> applyBudgetSuggestion(YearMonth target) async {
    final engine = InsightsEngine(
      allTxns: _txns,
      allBudgets: _budgets,
      expenseCategories: _expenseCategories,
      goals: _goals,
      debts: _debts,
    );
    final suggestions = engine.suggestNextMonthBudget(targetMonth: target);
    for (final s in suggestions) {
      final exists = _budgets.any(
        (x) =>
            x.year == target.year &&
            x.month == target.month &&
            x.category == s.category &&
            x.subcategory == s.subcategory,
      );
      if (!exists) {
        _budgets.add(
          BudgetItem(
            id: _uuid.v4(),
            month: target.month,
            year: target.year,
            category: s.category,
            subcategory: s.subcategory,
            country: s.country,
            planned: s.planned,
            autoSuggested: true,
          ),
        );
      }
    }
    await _persistBudgets();
    notifyListeners();
  }

  // ================= Objetivos de investimento CRUD =================
  // O objetivo gera automaticamente seus próprios itens de Planificación
  // mensais (aporte necessário), assim como as Deudas.

  Future<void> addGoal(InvestmentGoal goal) async {
    _goals.add(goal);
    await _persistGoals();
    _generateContributionsForGoal(goal);
    await _persistBudgets();
    notifyListeners();
  }

  Future<void> updateGoal(InvestmentGoal goal) async {
    final idx = _goals.indexWhere((g) => g.id == goal.id);
    if (idx != -1) {
      _goals[idx] = goal;
      await _persistGoals();
      // Remove itens de planejamento antigos ligados a este objetivo e
      // recria com base nos novos valores/prazos (fonte única de verdade).
      _budgets.removeWhere((b) => b.linkedGoalId == goal.id);
      _generateContributionsForGoal(goal);
      await _persistBudgets();
      notifyListeners();
    }
  }

  /// Elimina un Objetivo (meta de inversión). El objetivo/planificación
  /// NUNCA es propietario de transacciones — solo las organiza. Eliminar
  /// un objetivo JAMÁS borra ni altera ninguna transacción financiera, ni
  /// ningún KPI, Dashboard, gráfico o relatório: solo se retira el VÍNCULO
  /// (goalId y budgetItemId asociados) y las transacciones afectadas
  /// quedan marcadas como "Pendente de planificación".
  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((g) => g.id == id);
    final unlinkedBudgetIds = _budgets
        .where((b) => b.linkedGoalId == id)
        .map((b) => b.id)
        .toSet();
    _budgets.removeWhere((b) => b.linkedGoalId == id);
    // Desvincula (não exclui) transações que apontavam para este objetivo,
    // e marca como pendentes de planificación para reorganização.
    for (var i = 0; i < _txns.length; i++) {
      final t = _txns[i];
      final linkedToGoal = t.goalId == id;
      final linkedToRemovedBudget =
          t.budgetItemId != null && unlinkedBudgetIds.contains(t.budgetItemId);
      if (linkedToGoal || linkedToRemovedBudget) {
        _txns[i] = t.copyWith(
          clearGoalId: linkedToGoal,
          clearBudgetItemId: linkedToRemovedBudget,
          needsPlanificacionLink: true,
        );
      }
    }
    await _persistGoals();
    await _persistBudgets();
    await _persistTxns();
    assert(
      validateFinancialIntegrity(),
      'La eliminación del objetivo violó la integridad financiera',
    );
    notifyListeners();
  }

  void _generateContributionsForGoal(InvestmentGoal goal) {
    if (goal.monthlyTarget <= 0) return;
    final dates = goal.contributionDates();
    final country = goal.country.isNotEmpty
        ? goal.country
        : (_countries.isNotEmpty ? _countries.first : '');
    for (final date in dates) {
      final ym = YearMonth.fromDate(date);
      final exists = _budgets.any(
        (b) =>
            b.year == ym.year &&
            b.month == ym.month &&
            b.linkedGoalId == goal.id,
      );
      if (!exists) {
        _budgets.add(
          BudgetItem(
            id: _uuid.v4(),
            month: ym.month,
            year: ym.year,
            category: goal.category,
            subcategory: goal.subcategory.isNotEmpty
                ? goal.subcategory
                : goal.name,
            country: country,
            planned: goal.monthlyTarget,
            priority: Priority.media,
            dueDate: date,
            linkedGoalId: goal.id,
          ),
        );
      }
    }
  }

  /// Registra el aporte a un objetivo con un solo clic ("Aportar dinero"):
  /// crea automáticamente un movimiento de inversión vinculado (goalId),
  /// que aumenta el saldo actual de la inversión y actualiza el progreso
  /// de la meta, el dashboard, los KPIs y los análisis — sin ninguna
  /// actualización manual adicional. Esta es la ÚNICA vía soportada para
  /// aportar dinero a una inversión (no se crea desde Nueva Transacción).
  Future<void> contributeToGoal(String goalId, double amount) async {
    final idx = _goals.indexWhere((g) => g.id == goalId);
    if (idx == -1 || amount <= 0) return;
    final goal = _goals[idx];
    final country = goal.country.isNotEmpty
        ? goal.country
        : (_countries.isNotEmpty ? _countries.first : 'El Salvador');
    final now = DateTime.now();
    // Asegura que el KPI header/análisis (que filtran por período
    // seleccionado) muestren el impacto de este aporte de inmediato,
    // aunque el usuario esté viendo un período histórico distinto al mes
    // actual.
    _ensurePeriodIncludes(YearMonth.fromDate(now));
    await addTxn(
      Txn(
        id: _uuid.v4(),
        type: TxType.inversion,
        status: TxStatus.pagado,
        country: country,
        category: goal.category,
        subcategory: goal.subcategory.isNotEmpty ? goal.subcategory : goal.name,
        amount: amount,
        date: now,
        description: 'Aporte ${goal.name}',
        goalId: goal.id,
        isWithdrawal: false,
      ),
    );
  }

  /// Registra un rescate (retiro) de un objetivo de inversión con un solo
  /// clic ("Rescatar dinero"): crea automáticamente un movimiento de
  /// inversión marcado como retiro ([Txn.isWithdrawal] = true), lo que:
  /// - Disminuye [InvestmentGoal.currentAmount] (vía [_recalcGoal]).
  /// - Aumenta el saldo disponible del usuario (vía [balance]/
  ///   [balanceForMonth], que tratan los retiros como entrada de dinero).
  /// Mantiene siempre el historial completo (el movimiento queda visible
  /// en Movimientos). No permite rescatar más de lo que hay acumulado.
  Future<void> withdrawFromGoal(String goalId, double amount) async {
    final idx = _goals.indexWhere((g) => g.id == goalId);
    if (idx == -1 || amount <= 0) return;
    final goal = _goals[idx];
    final safeAmount = amount > goal.currentAmount
        ? goal.currentAmount
        : amount;
    if (safeAmount <= 0) return;
    final country = goal.country.isNotEmpty
        ? goal.country
        : (_countries.isNotEmpty ? _countries.first : 'El Salvador');
    final now = DateTime.now();
    // Ver comentario equivalente en [contributeToGoal]: garantiza que el
    // KPI header refleje el rescate de inmediato, aunque el período
    // seleccionado sea histórico.
    _ensurePeriodIncludes(YearMonth.fromDate(now));
    await addTxn(
      Txn(
        id: _uuid.v4(),
        type: TxType.inversion,
        status: TxStatus.pagado,
        country: country,
        category: goal.category,
        subcategory: goal.subcategory.isNotEmpty ? goal.subcategory : goal.name,
        amount: safeAmount,
        date: now,
        description: 'Rescate ${goal.name}',
        goalId: goal.id,
        isWithdrawal: true,
      ),
    );
  }

  // ================= Dívidas: total+meses → parcelas automáticas =================

  Future<void> addDebt(Debt debt) async {
    _debts.add(debt);
    await _persistDebts();
    _generateInstallmentsForDebt(debt);
    await _persistBudgets();
    notifyListeners();
  }

  Future<void> updateDebt(Debt debt) async {
    final idx = _debts.indexWhere((d) => d.id == debt.id);
    if (idx != -1) {
      _debts[idx] = debt;
      await _persistDebts();
      // Remove parcelas antigas ligadas a esta dívida e recria.
      _budgets.removeWhere((b) => b.linkedDebtId == debt.id);
      _generateInstallmentsForDebt(debt);
      await _persistBudgets();
      notifyListeners();
    }
  }

  /// Elimina una Deuda. La deuda/planificación NUNCA es propietaria de
  /// transacciones — solo las organiza. Eliminarla JAMÁS borra ni altera
  /// ninguna transacción financiera, ni ningún KPI, Dashboard, gráfico o
  /// relatório: solo se retira el VÍNCULO (debtId y budgetItemId
  /// asociados) y las transacciones afectadas quedan marcadas como
  /// "Pendente de planificación".
  Future<void> deleteDebt(String id) async {
    _debts.removeWhere((d) => d.id == id);
    final unlinkedBudgetIds = _budgets
        .where((b) => b.linkedDebtId == id)
        .map((b) => b.id)
        .toSet();
    _budgets.removeWhere((b) => b.linkedDebtId == id);
    for (var i = 0; i < _txns.length; i++) {
      final t = _txns[i];
      final linkedToDebt = t.debtId == id;
      final linkedToRemovedBudget =
          t.budgetItemId != null && unlinkedBudgetIds.contains(t.budgetItemId);
      if (linkedToDebt || linkedToRemovedBudget) {
        _txns[i] = t.copyWith(
          clearDebtId: linkedToDebt,
          clearBudgetItemId: linkedToRemovedBudget,
          needsPlanificacionLink: true,
        );
      }
    }
    await _persistDebts();
    await _persistBudgets();
    await _persistTxns();
    assert(
      validateFinancialIntegrity(),
      'La eliminación de la deuda violó la integridad financiera',
    );
    notifyListeners();
  }

  // ============================================================
  // ============= TRANSAÇÕES PENDENTES DE PLANIFICAÇÃO =============
  // ============================================================
  // Uma transação fica "pendente de planificación" quando perdeu seu
  // vínculo (budgetItemId/debtId/goalId) porque a planificación à qual
  // pertencia foi excluída. NUNCA afeta os KPIs — é puramente uma
  // pendência de ORGANIZAÇÃO, resolvível vinculando a transação a uma
  // planificación existente ou nova.

  /// Todas las transacciones que necesitan ser vinculadas (o revinculadas)
  /// a una planificación.
  List<Txn> get txnsPendingPlanificacion =>
      _txns.where((t) => t.needsPlanificacionLink).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  int get pendingPlanificacionCount => txnsPendingPlanificacion.length;

  double get pendingPlanificacionTotal =>
      txnsPendingPlanificacion.fold(0.0, (s, t) => s + t.amount);

  bool get hasPendingPlanificacion => txnsPendingPlanificacion.isNotEmpty;

  /// Vincula una transacción pendiente a un ítem de Planificación (Budget)
  /// existente. Nunca altera ningún KPI — solo el vínculo de organización.
  Future<void> linkTxnToBudget(String txnId, String budgetItemId) async {
    final idx = _txns.indexWhere((t) => t.id == txnId);
    if (idx == -1) return;
    _txns[idx] = _txns[idx].copyWith(
      budgetItemId: budgetItemId,
      needsPlanificacionLink: false,
    );
    await _persistTxns();
    notifyListeners();
  }

  void _generateInstallmentsForDebt(Debt debt) {
    final dates = debt.installmentDates();
    for (final date in dates) {
      final ym = YearMonth.fromDate(date);
      final exists = _budgets.any(
        (b) =>
            b.year == ym.year &&
            b.month == ym.month &&
            b.linkedDebtId == debt.id,
      );
      if (!exists) {
        _budgets.add(
          BudgetItem(
            id: _uuid.v4(),
            month: ym.month,
            year: ym.year,
            category: debt.category,
            subcategory: debt.subcategory,
            country: debt.country,
            planned: debt.monthlyInstallment,
            priority: Priority.alta,
            dueDate: date,
            linkedDebtId: debt.id,
          ),
        );
      }
    }
  }

  /// Registra el pago de la próxima cuota pendiente con un solo clic: crea
  /// automáticamente una transacción de tipo deuda vinculada (debtId), que
  /// actualiza el valor pagado/restante, el planejamento, el dashboard, los
  /// KPIs y las análisis — sin ninguna actualización manual adicional.
  Future<void> markNextInstallmentPaid(String debtId) async {
    final idx = _debts.indexWhere((d) => d.id == debtId);
    if (idx == -1) return;
    final debt = _debts[idx];
    if (debt.isSettled) return;
    await addTxn(
      Txn(
        id: _uuid.v4(),
        type: TxType.deuda,
        status: TxStatus.pagado,
        country: debt.country,
        category: debt.category,
        subcategory: debt.subcategory,
        amount: debt.monthlyInstallment,
        date: DateTime.now(),
        description: 'Pago ${debt.name}',
        debtId: debt.id,
      ),
    );
  }

  /// Registra un pago manual de monto libre para una deuda ("Realizar
  /// pago" dentro de la planificación de deuda): crea automáticamente un
  /// movimiento de tipo deuda vinculado (debtId), que reduce el saldo
  /// pendiente y actualiza el progreso de pago. Esta es la vía preferida
  /// cuando el usuario quiere pagar un monto distinto al de la cuota fija
  /// (adelantos, pagos parciales, etc). No permite pagar más de lo que
  /// queda pendiente.
  Future<void> payDebt(String debtId, double amount) async {
    final idx = _debts.indexWhere((d) => d.id == debtId);
    if (idx == -1 || amount <= 0) return;
    final debt = _debts[idx];
    final safeAmount = amount > debt.remainingAmount
        ? debt.remainingAmount
        : amount;
    if (safeAmount <= 0) return;
    final now = DateTime.now();
    // Ver comentario equivalente en [contributeToGoal]/[withdrawFromGoal]:
    // garantiza que el KPI header refleje el pago de inmediato, aunque el
    // período seleccionado sea histórico.
    _ensurePeriodIncludes(YearMonth.fromDate(now));
    await addTxn(
      Txn(
        id: _uuid.v4(),
        type: TxType.deuda,
        status: TxStatus.pagado,
        country: debt.country,
        category: debt.category,
        subcategory: debt.subcategory,
        amount: safeAmount,
        date: now,
        description: 'Pago ${debt.name}',
        debtId: debt.id,
      ),
    );
  }

  // ---------------- Categorias / Subcategorias / Países customizáveis ----------------
  Future<void> addExpenseCategory(CategoryDef cat) async {
    _expenseCategories.add(cat..isCustom = true);
    await _persistCategories();
    notifyListeners();
  }

  Future<void> addIncomeCategory(CategoryDef cat) async {
    _incomeCategories.add(cat..isCustom = true);
    await _persistCategories();
    notifyListeners();
  }

  Future<void> addSubcategory({
    required bool isExpense,
    required String category,
    required String subcategory,
  }) async {
    final list = isExpense ? _expenseCategories : _incomeCategories;
    final idx = list.indexWhere((c) => c.name == category);
    if (idx != -1 && !list[idx].subcategories.contains(subcategory)) {
      list[idx].subcategories.add(subcategory);
      await _persistCategories();
      notifyListeners();
    }
  }

  Future<void> removeCategory({
    required bool isExpense,
    required String category,
  }) async {
    if (isExpense) {
      _expenseCategories.removeWhere((c) => c.name == category);
    } else {
      _incomeCategories.removeWhere((c) => c.name == category);
    }
    await _persistCategories();
    notifyListeners();
  }

  Future<void> removeSubcategory({
    required bool isExpense,
    required String category,
    required String subcategory,
  }) async {
    final list = isExpense ? _expenseCategories : _incomeCategories;
    final idx = list.indexWhere((c) => c.name == category);
    if (idx != -1) {
      list[idx].subcategories.remove(subcategory);
      await _persistCategories();
      notifyListeners();
    }
  }

  Future<void> addCountry(String country) async {
    if (!_countries.contains(country)) {
      _countries.add(country);
      await _persistCountries();
      notifyListeners();
    }
  }

  Future<void> removeCountry(String country) async {
    _countries.remove(country);
    await _persistCountries();
    notifyListeners();
  }

  List<CategoryDef> categoriesFor(TxType type) {
    switch (type) {
      case TxType.ingreso:
        return _incomeCategories;
      case TxType.gasto:
      case TxType.deuda:
      case TxType.inversion:
        return _expenseCategories;
    }
  }

  // ---------------- Filtros/consultas auxiliares ----------------
  List<Txn> txnsForPeriods(Set<YearMonth> periods) {
    return _txns
        .where(
          (t) => periods.contains(YearMonth(t.year, t.month)) && !t.isPending,
        )
        .toList();
  }

  List<Txn> txnsForRange(PeriodRange range) => txnsForPeriods(range.monthSet);

  List<Txn> get txnsForSelectedPeriods => txnsForPeriods(selectedPeriods);

  double totalByType(TxType type, {Set<YearMonth>? periods}) {
    final list = txnsForPeriods(periods ?? selectedPeriods);
    return list
        .where((t) => t.type == type)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Suma de APORTES de inversión (excluye rescates) en el período.
  double totalAportesInversion({Set<YearMonth>? periods}) {
    final list = txnsForPeriods(periods ?? selectedPeriods);
    return list
        .where((t) => t.type == TxType.inversion && !t.isWithdrawal)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Suma de RESCATES de inversión en el período.
  double totalRescatesInversion({Set<YearMonth>? periods}) {
    final list = txnsForPeriods(periods ?? selectedPeriods);
    return list
        .where((t) => t.type == TxType.inversion && t.isWithdrawal)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalIngresos => totalByType(TxType.ingreso);
  double get totalGastosYDeudas =>
      totalByType(TxType.gasto) + totalByType(TxType.deuda);

  /// Inversión NETA del período (aportes - rescates). Un rescate reduce
  /// este valor, lo que a su vez aumenta [balance] — refleja que el
  /// dinero rescatado vuelve al saldo disponible del usuario.
  double get totalInversiones =>
      totalAportesInversion() - totalRescatesInversion();

  double get balance => totalIngresos - totalGastosYDeudas - totalInversiones;

  // ============================================================
  // ============= SISTEMA DE FLUJO DE CAPITAL CERRADO =============
  // ============================================================
  // Los 3 KPIs principales (Ingreso disponible / Gastos / Inversiones)
  // representan ESTADOS del dinero, NO flujos de un período. Por eso se
  // calculan siempre sobre el HISTÓRICO COMPLETO de transacciones,
  // independientemente del [selectedPeriods] que el usuario tenga elegido
  // en la UI (ese selector solo afecta reportes/gráficos, nunca el estado
  // real de "cuánto dinero tengo disponible ahora").
  //
  // Invariante fundamental que SIEMPRE debe cumplirse:
  //   ingresoDisponible + totalGastosHistorico + inversionesActuales
  //       == totalIngresosHistorico
  //
  // Ningún dólar puede estar en dos estados a la vez, ni desaparecer.
  // ============================================================

  /// Todas las transacciones NO pendientes ($0 a programar), de TODA la
  /// historia (sin filtrar por período seleccionado).
  List<Txn> get _allRealizedTxns => _txns.where((t) => !t.isPending).toList();

  /// Total histórico de Ingresos (todas las transacciones TxType.ingreso,
  /// de cualquier período).
  double get totalIngresosHistorico => _allRealizedTxns
      .where((t) => t.type == TxType.ingreso)
      .fold(0.0, (s, t) => s + t.amount);

  /// Total histórico de Gastos reales (Gasto + Deuda). NUNCA incluye
  /// aportes de inversión — un aporte es un "destino" del dinero, no un
  /// gasto definitivo.
  double get totalGastosHistorico => _allRealizedTxns
      .where((t) => t.type == TxType.gasto || t.type == TxType.deuda)
      .fold(0.0, (s, t) => s + t.amount);

  /// Total histórico de Aportes de inversión (sin restar rescates).
  double get totalAportesHistorico => _allRealizedTxns
      .where((t) => t.type == TxType.inversion && !t.isWithdrawal)
      .fold(0.0, (s, t) => s + t.amount);

  /// Total histórico de Rescates de inversión.
  double get totalRescatesHistorico => _allRealizedTxns
      .where((t) => t.type == TxType.inversion && t.isWithdrawal)
      .fold(0.0, (s, t) => s + t.amount);

  /// KPI Inversiones: capital actualmente invertido = aportes - rescates,
  /// calculado sobre TODA la historia (nunca por período).
  double get inversionesActuales =>
      totalAportesHistorico - totalRescatesHistorico;

  /// Total interno (nunca mostrado directamente en la UI) usado solo para
  /// validar la ecuación fundamental: Gasto Total = Gastos + Inversiones.
  double get _gastoTotalHistorico => totalGastosHistorico + inversionesActuales;

  /// KPI Ingreso disponible: única fuente de dinero libre para gastar o
  /// aportar. Aumenta con cada Ingreso o Rescate; disminuye con cada Gasto
  /// o Aporte. Calculado como ESTADO acumulado (histórico completo), no
  /// como suma filtrada por período — así nunca se "pierde" el efecto de
  /// un aporte/rescate hecho en un mes fuera del filtro actual.
  double get ingresoDisponible => totalIngresosHistorico - _gastoTotalHistorico;

  /// Verifica que la ecuación fundamental de conservación de capital se
  /// mantenga siempre: ningún dólar puede desaparecer ni estar en dos
  /// estados a la vez. Devuelve `true` si todo está consistente.
  bool validateFinancialIntegrity({double epsilon = 0.01}) {
    final suma = ingresoDisponible + totalGastosHistorico + inversionesActuales;
    return (suma - totalIngresosHistorico).abs() <= epsilon;
  }

  double plannedTotalFor(Set<YearMonth> periods) {
    return _budgets
        .where((b) => periods.contains(YearMonth(b.year, b.month)))
        .fold(0.0, (s, b) => s + b.planned);
  }

  double get plannedTotalSelected => plannedTotalFor(selectedPeriods);

  /// Total planejado de Gastos (exclui itens vinculados a Objetivos, que
  /// são investimento, não gasto) para o período selecionado.
  double get plannedGastosSelected {
    return _budgets
        .where(
          (b) =>
              selectedPeriods.contains(YearMonth(b.year, b.month)) &&
              !b.isGoalContribution,
        )
        .fold(0.0, (s, b) => s + b.planned);
  }

  /// Meta planejada de Investimentos no período selecionado: soma dos
  /// aportes mensais previstos (itens de planejamento vinculados a
  /// objetivos) que caem dentro do período — única fonte de verdade da
  /// "meta" usada pelo KPI de Investimentos.
  double get investmentGoalPlannedSelected {
    final fromBudgets = _budgets
        .where(
          (b) =>
              selectedPeriods.contains(YearMonth(b.year, b.month)) &&
              b.isGoalContribution,
        )
        .fold(0.0, (s, b) => s + b.planned);
    if (fromBudgets > 0) return fromBudgets;
    // Fallback: si no hay ítems de planeamiento vinculados (objetivos sin
    // meta mensual calculable), usa la meta mensual directa de los goals.
    return _goals.fold(0.0, (s, g) => s + g.monthlyTarget);
  }

  double get goalsTargetTotal => _goals.fold(0.0, (s, g) => s + g.targetAmount);
  double get goalsCurrentTotal =>
      _goals.fold(0.0, (s, g) => s + g.currentAmount);

  // ================= KPIs Inteligentes (cabeçalho) =================
  // Gastos: ejecutado / planificado, con color según franja de progreso.
  double get gastosExecutedRatio {
    final planned = plannedGastosSelected;
    if (planned <= 0) return 0;
    return totalGastosYDeudas / planned;
  }

  BudgetProgressLevel get gastosProgressLevel =>
      budgetProgressLevelFor(gastosExecutedRatio);

  // Investimentos: aportado / meta planificada, con estado especial cuando
  // se alcanza o supera la meta.
  double get investmentExecutedRatio {
    final planned = investmentGoalPlannedSelected;
    if (planned <= 0) return 0;
    return totalInversiones / planned;
  }

  bool get investmentGoalCompleted =>
      investmentGoalPlannedSelected > 0 &&
      totalInversiones >= investmentGoalPlannedSelected - 0.01;
  bool get investmentGoalExceeded =>
      investmentGoalPlannedSelected > 0 &&
      totalInversiones > investmentGoalPlannedSelected + 0.01;

  // ============================================================
  // ============= 4 KPIs DEL DASHBOARD (Disponible / Gastos /
  // ============= Objetivos / Deudas) =============
  // ============================================================
  // Estos getters DESAGREGAN visualmente lo que [totalGastosHistorico] ya
  // hacía (Gasto + Deuda sumados) en dos KPIs independientes, y renombran
  // [inversionesActuales] como "Objetivos" (ya que, en la práctica, TODO
  // TxType.inversion está siempre vinculado a un goalId — no existe
  // "inversión libre" sin objetivo, ver contributeToGoal/withdrawFromGoal).
  // No se introduce ningún cálculo nuevo de dinero: es la misma ecuación
  // fundamental (ingresoDisponible + totalGastosHistorico + inversionesActuales
  // == totalIngresosHistorico), solo que totalGastosHistorico ahora se
  // expone dividido en 2 números que siguen sumando exactamente lo mismo.
  // Invariante: totalGastosPurosHistorico + totalDeudaHistorico ==
  // totalGastosHistorico (siempre).

  /// KPI Gastos (SOLO gasto normal, sin deuda ni objetivos) — histórico
  /// completo, igual criterio que [totalGastosHistorico].
  double get totalGastosPurosHistorico => _allRealizedTxns
      .where((t) => t.type == TxType.gasto)
      .fold(0.0, (s, t) => s + t.amount);

  /// KPI Deudas (SOLO cuotas de deuda pagadas) — histórico completo.
  double get totalDeudaHistorico => _allRealizedTxns
      .where((t) => t.type == TxType.deuda)
      .fold(0.0, (s, t) => s + t.amount);

  /// KPI Objetivos: alias semántico de [inversionesActuales] — mismo
  /// valor, nombre alineado con el concepto de producto ("Objetivos").
  double get objetivosActuales => inversionesActuales;

  // ============================================================
  // ============= NUEVA LÓGICA DE KPIs (dashboard Resumen) =====
  // ============================================================
  // A partir de esta versión, los 4 KPIs del dashboard se dividen en dos
  // categorías claramente distintas:
  //
  // 1) INDICADORES DE FLUJO (dependen del período seleccionado):
  //    - Ingresos del período  -> [totalIngresos] (ya existía, filtrado por
  //      selectedPeriods).
  //    - Gastos del período    -> [totalGastosPurosSelected] (NUEVO: antes
  //      el card "Gastos" usaba totalGastosPurosHistorico, que es histórico
  //      completo; ahora refleja solo el período filtrado).
  //
  // 2) INDICADORES DE SITUACIÓN FINANCIERA ACTUAL (NO dependen del período):
  //    - Saldo Disponible -> [ingresoDisponible] (ya era histórico, sin
  //      cambios).
  //    - Objetivos actuales -> [objetivosActuales] (ya era histórico, sin
  //      cambios).
  //    - Deudas: saldo PENDIENTE actual -> [totalDeudaPendiente] (NUEVO:
  //      antes el card "Deudas" mostraba totalDeudaHistorico, que es la
  //      suma de cuotas YA PAGADAS -- un concepto de flujo acumulado. El
  //      nuevo requisito pide el saldo actual de la deuda, es decir, cuánto
  //      se debe TODAVÍA -- suma de Debt.remainingAmount de todas las
  //      deudas activas).
  //
  // Los filtros avanzados NUNCA afectan ninguno de estos getters -- solo
  // filtran listas/gráficos/análisis detallados en sus propias pantallas.
  // ============================================================

  /// Gastos puros (SOLO TxType.gasto, sin deuda ni objetivos) del período
  /// seleccionado — KPI de FLUJO, cambia con el filtro global de período.
  double get totalGastosPurosSelected => totalByType(TxType.gasto);

  /// Saldo PENDIENTE de todas las deudas activas (cuánto se debe todavía)
  /// — KPI de SITUACIÓN FINANCIERA, NO depende del período seleccionado.
  double get totalDeudaPendiente =>
      _debts.fold(0.0, (s, d) => s + d.remainingAmount);

  // -------- Progreso ABSOLUTO de Objetivos y Deudas (barras de KPI) ------
  // Estas barras de progreso comparan el TOTAL de la meta/deuda contra lo
  // YA pagado/aportado en TODA la historia -- son KPIs de SITUACIÓN
  // FINANCIERA (igual que su tarjeta), por lo que NUNCA deben depender del
  // filtro global de período ni de filtros avanzados. Ej.: si un objetivo
  // tiene meta de $1000 y ya se aportaron $500, la barra siempre muestra
  // 500/1000 sin importar qué mes/período esté seleccionado.

  /// Meta TOTAL de todos los objetivos (suma de targetAmount) — absoluto.
  double get goalsTargetTotalAbs =>
      _goals.fold(0.0, (s, g) => s + g.targetAmount);

  /// Progreso absoluto de Objetivos: aportado total / meta total.
  double get goalsProgressRatioAbs {
    final target = goalsTargetTotalAbs;
    if (target <= 0) return 0;
    return objetivosActuales / target;
  }

  bool get goalsCompletedAbs =>
      goalsTargetTotalAbs > 0 &&
      objetivosActuales >= goalsTargetTotalAbs - 0.01;
  bool get goalsExceededAbs =>
      goalsTargetTotalAbs > 0 && objetivosActuales > goalsTargetTotalAbs + 0.01;

  /// Monto TOTAL de todas las deudas (suma de totalAmount) — absoluto.
  double get debtsTotalAmountAbs =>
      _debts.fold(0.0, (s, d) => s + d.totalAmount);

  /// Total YA pagado de todas las deudas (suma de paidAmount) — absoluto.
  double get debtsPaidAmountAbs => _debts.fold(0.0, (s, d) => s + d.paidAmount);

  /// Progreso absoluto de Deudas: pagado total / monto total de deuda.
  double get debtsProgressRatioAbs {
    final total = debtsTotalAmountAbs;
    if (total <= 0) return 0;
    return debtsPaidAmountAbs / total;
  }

  /// Planificado de Gasto puro (excluye deuda y objetivos) en el período
  /// seleccionado — usado para la barra de progreso del KPI Gastos.
  double get plannedGastosPurosSelected {
    return _budgets
        .where(
          (b) =>
              selectedPeriods.contains(YearMonth(b.year, b.month)) &&
              !b.isGoalContribution &&
              !b.isDebtInstallment,
        )
        .fold(0.0, (s, b) => s + b.planned);
  }

  /// Planificado de cuotas de Deuda en el período seleccionado — usado
  /// para la barra de progreso del KPI Deudas.
  double get plannedDeudaSelected {
    return _budgets
        .where(
          (b) =>
              selectedPeriods.contains(YearMonth(b.year, b.month)) &&
              b.isDebtInstallment,
        )
        .fold(0.0, (s, b) => s + b.planned);
  }

  double get gastosPurosExecutedRatio {
    final planned = plannedGastosPurosSelected;
    if (planned <= 0) return 0;
    return totalByType(TxType.gasto) / planned;
  }

  double get deudaExecutedRatio {
    final planned = plannedDeudaSelected;
    if (planned <= 0) return 0;
    return totalByType(TxType.deuda) / planned;
  }

  /// Balanço de um mês específico (usado para cálculo de rollover de déficit).
  /// Rescates de inversión (isWithdrawal=true) suman al saldo disponible
  /// en vez de restar, ya que representan dinero que vuelve al usuario.
  double balanceForMonth(YearMonth ym) {
    final list = txnsForPeriods({ym});
    final ing = list
        .where((t) => t.type == TxType.ingreso)
        .fold(0.0, (s, t) => s + t.amount);
    final out = list
        .where((t) => t.type == TxType.gasto || t.type == TxType.deuda)
        .fold(0.0, (s, t) => s + t.amount);
    final aportes = list
        .where((t) => t.type == TxType.inversion && !t.isWithdrawal)
        .fold(0.0, (s, t) => s + t.amount);
    final rescates = list
        .where((t) => t.type == TxType.inversion && t.isWithdrawal)
        .fold(0.0, (s, t) => s + t.amount);
    return ing + rescates - out - aportes;
  }

  /// Verifica se o mês anterior teve déficit e, caso ainda não tenha sido
  /// rolado, cria automaticamente uma transação "Déficit anterior" no mês
  /// atual (ym), evitando duplicidade.
  void _applyDeficitRolloverIfNeeded(YearMonth ym) {
    final prev = ym.previous();
    final prevBalance = balanceForMonth(prev);
    if (prevBalance >= 0) return;

    final alreadyRolled = _txns.any(
      (t) =>
          t.isDeficitRollover &&
          t.year == ym.year &&
          t.month == ym.month &&
          t.description.contains(monthLabel(prev)),
    );
    if (alreadyRolled) return;

    final deficit = -prevBalance;
    if (deficit <= 0) return;

    _txns.add(
      Txn(
        id: _uuid.v4(),
        type: TxType.gasto,
        status: TxStatus.pendiente,
        country: _countries.isNotEmpty ? _countries.first : 'El Salvador',
        category: 'Otros',
        subcategory: 'Déficit anterior',
        amount: deficit,
        date: DateTime(ym.year, ym.month, 1),
        description:
            'Déficit de ${monthLabel(prev)} transferido automáticamente',
        isDeficitRollover: true,
      ),
    );
    _persistTxns();
  }

  /// Executa a verificação de rollover para todos os meses conhecidos
  /// (chamado ao carregar o app, para garantir consistência histórica).
  void reconcileDeficitRollovers() {
    final Set<YearMonth> months = {};
    for (final t in _txns) {
      months.add(YearMonth(t.year, t.month));
    }
    for (final b in _budgets) {
      months.add(YearMonth(b.year, b.month));
    }
    months.add(YearMonth.fromDate(DateTime.now()));
    final sorted = months.toList()..sort();
    for (final m in sorted) {
      _applyDeficitRolloverIfNeeded(m);
    }
  }

  // ---------------- Alertas: próximos pagamentos pendentes ----------------
  /// Itens de planejamento com vencimento próximo que ainda não foram
  /// cubiertos por transações executadas (ver [isBudgetItemCovered]) — não
  /// depende mais de um campo manual de Estado, que foi eliminado da UI por
  /// ser irrelevante/duplicado com a información real de transações.
  List<BudgetItem> upcomingDue({int days = 7}) {
    final now = DateTime.now();
    final limit = now.add(Duration(days: days));
    final debtById = {for (final d in _debts) d.id: d};
    final goalById = {for (final g in _goals) g.id: g};
    final result = <BudgetItem>[];
    final seenKeys = <String>{};

    // BUGFIX DE RAÍZ (vencimientos fantasma): la cobertura mes-a-mes
    // ([isBudgetItemCovered]/comparar por [YearMonth] exacto) falla cuando
    // el usuario paga/aporta un monto que no cae exactamente en el mes de
    // una cuota específica — ej.: liquidar una deuda con UN solo pago que
    // cubre varias cuotas futuras de una vez, o adelantar varios meses de
    // aporte de un objetivo en un solo movimiento. En esos casos, las
    // cuotas de los meses siguientes NUNCA reciben su propia transacción
    // (porque la deuda/objetivo ya fue resuelto/adelantado), y quedaban
    // "pendientes" para siempre — apareciendo como vencimientos de algo
    // que, en la práctica, ya no existe en la app.
    //
    // Solución definitiva: para ítems vinculados a Deuda/Objetivo, en vez
    // de comparar transacciones del MISMO mes, se compara el TOTAL PAGADO/
    // APORTADO acumulado (fuente única de verdad: [Debt.paidAmount]/
    // [InvestmentGoal.currentAmount]) contra la SUMA ACUMULADA de lo
    // planificado hasta (e incluyendo) ese ítem, en orden cronológico. Si
    // lo acumulado ya cubre lo esperado hasta ese punto, el ítem se
    // considera cubierto sin importar en qué mes exacto cayó el pago.
    final Map<String, List<BudgetItem>> byDebt = {};
    final Map<String, List<BudgetItem>> byGoal = {};
    for (final b in _budgets) {
      if (b.linkedDebtId != null) {
        byDebt.putIfAbsent(b.linkedDebtId!, () => []).add(b);
      }
      if (b.linkedGoalId != null) {
        byGoal.putIfAbsent(b.linkedGoalId!, () => []).add(b);
      }
    }
    int cmpByDue(BudgetItem a, BudgetItem b) =>
        (a.dueDate ?? DateTime(a.year, a.month)).compareTo(
          b.dueDate ?? DateTime(b.year, b.month),
        );
    for (final list in byDebt.values) {
      list.sort(cmpByDue);
    }
    for (final list in byGoal.values) {
      list.sort(cmpByDue);
    }

    for (final b in _budgets) {
      if (b.dueDate == null) continue;
      // Defensa extra: nunca mostrar un ítem vinculado a una Deuda/Objetivo
      // que ya no existe (huérfano) — se limpian en [init], pero esto
      // garantiza que jamás aparezcan aunque queden datos residuales.
      if (b.linkedDebtId != null && !debtById.containsKey(b.linkedDebtId)) {
        continue;
      }
      if (b.linkedGoalId != null && !goalById.containsKey(b.linkedGoalId)) {
        continue;
      }

      if (b.linkedDebtId != null) {
        final debt = debtById[b.linkedDebtId]!;
        if (debt.isSettled) continue;
        final schedule = byDebt[b.linkedDebtId] ?? [b];
        final idx = schedule.indexOf(b);
        final acumuladoEsperado = schedule
            .take(idx + 1)
            .fold(0.0, (s, x) => s + x.planned);
        if (debt.paidAmount >= acumuladoEsperado - 0.01) continue;
      } else if (b.linkedGoalId != null) {
        final goal = goalById[b.linkedGoalId]!;
        if (goal.isCompleted) continue;
        final schedule = byGoal[b.linkedGoalId] ?? [b];
        final idx = schedule.indexOf(b);
        final acumuladoEsperado = schedule
            .take(idx + 1)
            .fold(0.0, (s, x) => s + x.planned);
        if (goal.currentAmount >= acumuladoEsperado - 0.01) continue;
      } else {
        // Planificación de Gasto normal (sin vínculo): mantiene la
        // cobertura por mes exacto, que sí es correcta en este caso (no
        // existe "cronograma" ni pagos adelantados fuera de mes).
        if (isBudgetItemCovered(b)) continue;
      }

      final isDue =
          b.dueDate!.isAfter(now.subtract(const Duration(days: 1))) &&
          b.dueDate!.isBefore(limit);
      if (!isDue) continue;
      // Defensa extra contra duplicados: no repetir el mismo
      // mes+categoría+subcategoría+vínculo dos veces en la lista.
      final key =
          '${b.year}-${b.month}-${b.category}-${b.subcategory}-${b.linkedDebtId}-${b.linkedGoalId}';
      if (seenKeys.contains(key)) continue;
      seenKeys.add(key);
      result.add(b);
    }
    result.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    return result;
  }

  // ---------------- Resumo Inteligente (motor de insights) ----------------
  /// IMPORTANTE: los mensajes de "vencimiento próximo" (deudas/objetivos)
  /// del Resumo Inteligente usan la MISMA lista ya calculada por
  /// [upcomingDue] (fuente única de verdad, con cobertura acumulada) — en
  /// vez de que [InsightsEngine] recalcule esto por su cuenta con lógica
  /// propia. Esto evita que ambas secciones del Resumen (el aviso en
  /// lenguaje natural y la lista de "Próximos vencimientos") queden
  /// desincronizadas y muestren mensajes contradictorios o "fantasma"
  /// sobre planificaciones que, en la práctica, ya están cubiertas.
  List<Insight> generateInsights() {
    final engine = InsightsEngine(
      allTxns: _txns,
      allBudgets: _budgets,
      expenseCategories: _expenseCategories,
      goals: _goals,
      debts: _debts,
    );
    return engine.generate(_selectedRange, upcomingDueItems: upcomingDue(days: 10));
  }

  // ---------------- Export/Import ----------------
  Map<String, dynamic> exportSnapshot() => storage.exportAll();

  Future<void> importSnapshot(Map<String, dynamic> data) async {
    await storage.importAll(data);
    _loadFromStorage();
    notifyListeners();
  }

  /// Borra TODOS los datos del usuario (transacciones, planificación,
  /// objetivos, deudas) y reinicia el app al estado vacío de fábrica
  /// (solo con la taxonomía base de categorías/países). NO reintroduce
  /// ningún dato de ejemplo/demostración.
  Future<void> resetToSeed() async {
    await storage.clearAll();
    await storage.init();
    await _seed();
    _loadFromStorage();
    _selectedRange = PeriodRange.singleMonth(
      YearMonth.fromDate(DateTime.now()),
    );
    notifyListeners();
  }

  // ---------------- Utilitário ----------------
  double randomJitter() => Random().nextDouble();
}
