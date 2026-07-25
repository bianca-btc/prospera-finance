import 'dart:math';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/enums.dart';
import '../models/transaction.dart';
import '../models/budget_item.dart';
import '../models/taxonomy.dart';
import '../services/storage_service.dart';
import '../services/seed_data.dart';
import '../utils/period.dart';

const _uuid = Uuid();

/// Estado global do app Prospera: transações, orçamentos, objetivos,
/// taxonomias customizáveis e filtros de período. Toda a lógica de
/// negócio (KPIs, rollover de déficit, alertas) vive aqui.
class AppState extends ChangeNotifier {
  final StorageService storage;
  AppState(this.storage);

  List<Txn> _txns = [];
  List<BudgetItem> _budgets = [];
  List<InvestmentGoal> _goals = [];
  List<CategoryDef> _expenseCategories = [];
  List<CategoryDef> _incomeCategories = [];
  List<String> _countries = [];

  Set<YearMonth> _selectedPeriods = {};
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
  List<CategoryDef> get expenseCategories =>
      List.unmodifiable(_expenseCategories);
  List<CategoryDef> get incomeCategories =>
      List.unmodifiable(_incomeCategories);
  List<String> get countries => List.unmodifiable(_countries);
  Set<YearMonth> get selectedPeriods => Set.unmodifiable(_selectedPeriods);
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

    // Período padrão: meses com dados do seed, ou mês atual.
    if (_txns.isNotEmpty) {
      final months =
          _txns.map((t) => YearMonth(t.year, t.month)).toSet().toList()..sort();
      _selectedPeriods = {months.last};
    } else {
      _selectedPeriods = {YearMonth.fromDate(DateTime.now())};
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> _seed() async {
    _txns = SeedData.buildTransactions();
    _budgets = SeedData.buildBudgets();
    _expenseCategories = SeedData.expenseCategories();
    _incomeCategories = SeedData.incomeCategories();
    _countries = SeedData.countries();
    _goals = [
      InvestmentGoal(
        id: _uuid.v4(),
        name: 'Fondo de emergencia',
        targetAmount: 3000,
        currentAmount: 450,
        description: 'Cobertura de 3 meses de gastos fijos',
      ),
      InvestmentGoal(
        id: _uuid.v4(),
        name: 'Nuevo equipo de ceremonia',
        targetAmount: 1200,
        currentAmount: 200,
      ),
    ];
    await _persistAll();
    await storage.setSeeded();
  }

  void _loadFromStorage() {
    _txns = storage.loadTxns().map(Txn.fromJson).toList();
    _budgets = storage.loadBudgets().map(BudgetItem.fromJson).toList();
    _goals = storage.loadGoals().map(InvestmentGoal.fromJson).toList();
    _expenseCategories = storage
        .loadExpenseCategories()
        .map(CategoryDef.fromJson)
        .toList();
    _incomeCategories = storage
        .loadIncomeCategories()
        .map(CategoryDef.fromJson)
        .toList();
    _countries = storage.loadCountries();

    if (_expenseCategories.isEmpty)
      _expenseCategories = SeedData.expenseCategories();
    if (_incomeCategories.isEmpty)
      _incomeCategories = SeedData.incomeCategories();
    if (_countries.isEmpty) _countries = SeedData.countries();
  }

  Future<void> _persistAll() async {
    await storage.saveTxns(_txns.map((e) => e.toJson()).toList());
    await storage.saveBudgets(_budgets.map((e) => e.toJson()).toList());
    await storage.saveGoals(_goals.map((e) => e.toJson()).toList());
    await storage.saveExpenseCategories(
      _expenseCategories.map((e) => e.toJson()).toList(),
    );
    await storage.saveIncomeCategories(
      _incomeCategories.map((e) => e.toJson()).toList(),
    );
    await storage.saveCountries(_countries);
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

  // ---------------- Filtros de período ----------------
  void togglePeriod(YearMonth ym) {
    if (_selectedPeriods.contains(ym)) {
      if (_selectedPeriods.length > 1) _selectedPeriods.remove(ym);
    } else {
      _selectedPeriods.add(ym);
    }
    notifyListeners();
  }

  void setPeriods(Set<YearMonth> periods) {
    if (periods.isEmpty) return;
    _selectedPeriods = periods;
    notifyListeners();
  }

  void selectSinglePeriod(YearMonth ym) {
    _selectedPeriods = {ym};
    notifyListeners();
  }

  /// Todos os meses conhecidos (com transações ou orçamentos), + o mês atual
  /// e uma janela futura, para permitir planejar anos futuros livremente.
  List<YearMonth> get availablePeriods {
    final Set<YearMonth> set = {};
    for (final t in _txns) {
      set.add(YearMonth(t.year, t.month));
    }
    for (final b in _budgets) {
      set.add(YearMonth(b.year, b.month));
    }
    final now = YearMonth.fromDate(DateTime.now());
    set.add(now);
    // Janela de 12 meses futuros e 6 meses passados a partir de hoje.
    var cursor = now;
    for (int i = 0; i < 12; i++) {
      cursor = cursor.next();
      set.add(cursor);
    }
    cursor = now;
    for (int i = 0; i < 6; i++) {
      cursor = cursor.previous();
      set.add(cursor);
    }
    final list = set.toList()..sort();
    return list;
  }

  // ---------------- Transações CRUD ----------------
  Future<void> addTxn(Txn txn) async {
    _txns.add(txn);
    await _persistTxns();
    _applyDeficitRolloverIfNeeded(YearMonth(txn.year, txn.month));
    notifyListeners();
  }

  Future<void> updateTxn(Txn txn) async {
    final idx = _txns.indexWhere((t) => t.id == txn.id);
    if (idx != -1) {
      _txns[idx] = txn;
      await _persistTxns();
      notifyListeners();
    }
  }

  Future<void> deleteTxn(String id) async {
    _txns.removeWhere((t) => t.id == id);
    await _persistTxns();
    notifyListeners();
  }

  Future<void> duplicateTxn(String id) async {
    final t = _txns.firstWhere((t) => t.id == id);
    final copy = Txn(
      id: _uuid.v4(),
      type: t.type,
      nature: t.nature,
      status: TxStatus.pendiente,
      country: t.country,
      category: t.category,
      subcategory: t.subcategory,
      amount: t.amount,
      date: t.date,
      method: t.method,
      description: t.description,
    );
    _txns.add(copy);
    await _persistTxns();
    notifyListeners();
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

  Future<void> deleteBudget(String id) async {
    _budgets.removeWhere((b) => b.id == id);
    await _persistBudgets();
    notifyListeners();
  }

  /// Replica o planejamento de um mês para outro mês (Planificación > Replicar mes).
  Future<void> replicateBudgetMonth({
    required YearMonth from,
    required YearMonth to,
  }) async {
    final source = _budgets
        .where((b) => b.year == from.year && b.month == from.month)
        .toList();
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
            nature: b.nature,
            priority: b.priority,
            status: TxStatus.pendiente,
            description: b.description,
            method: b.method,
            dueDate: b.dueDate != null
                ? DateTime(to.year, to.month, b.dueDate!.day)
                : null,
          ),
        );
      }
    }
    await _persistBudgets();
    notifyListeners();
  }

  // ---------------- Objetivos de investimento CRUD ----------------
  Future<void> addGoal(InvestmentGoal goal) async {
    _goals.add(goal);
    await _persistGoals();
    notifyListeners();
  }

  Future<void> updateGoal(InvestmentGoal goal) async {
    final idx = _goals.indexWhere((g) => g.id == goal.id);
    if (idx != -1) {
      _goals[idx] = goal;
      await _persistGoals();
      notifyListeners();
    }
  }

  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((g) => g.id == id);
    await _persistGoals();
    notifyListeners();
  }

  // ---------------- Categorias / Subcategorias / Países customizáveis ----------------
  Future<void> addExpenseCategory(CategoryDef cat) async {
    _expenseCategories.add(cat);
    await _persistCategories();
    notifyListeners();
  }

  Future<void> addIncomeCategory(CategoryDef cat) async {
    _incomeCategories.add(cat);
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

  List<Txn> get txnsForSelectedPeriods => txnsForPeriods(_selectedPeriods);

  double totalByType(TxType type, {Set<YearMonth>? periods}) {
    final list = txnsForPeriods(periods ?? _selectedPeriods);
    return list
        .where((t) => t.type == type)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalIngresos => totalByType(TxType.ingreso);
  double get totalGastosYDeudas =>
      totalByType(TxType.gasto) + totalByType(TxType.deuda);
  double get totalInversiones => totalByType(TxType.inversion);
  double get balance => totalIngresos - totalGastosYDeudas - totalInversiones;

  double plannedTotalFor(Set<YearMonth> periods) {
    return _budgets
        .where((b) => periods.contains(YearMonth(b.year, b.month)))
        .fold(0.0, (s, b) => s + b.planned);
  }

  double get plannedTotalSelected => plannedTotalFor(_selectedPeriods);

  double get goalsTargetTotal => _goals.fold(0.0, (s, g) => s + g.targetAmount);
  double get goalsCurrentTotal =>
      _goals.fold(0.0, (s, g) => s + g.currentAmount);

  /// Balanço de um mês específico (usado para cálculo de rollover de déficit).
  double balanceForMonth(YearMonth ym) {
    final list = txnsForPeriods({ym});
    final ing = list
        .where((t) => t.type == TxType.ingreso)
        .fold(0.0, (s, t) => s + t.amount);
    final out = list
        .where((t) => t.type == TxType.gasto || t.type == TxType.deuda)
        .fold(0.0, (s, t) => s + t.amount);
    final inv = list
        .where((t) => t.type == TxType.inversion)
        .fold(0.0, (s, t) => s + t.amount);
    return ing - out - inv;
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
        nature: TxNature.variable,
        status: TxStatus.pendiente,
        country: _countries.isNotEmpty ? _countries.first : 'El Salvador',
        category: 'Déficit anterior',
        subcategory: 'Rollover',
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
    final months = availablePeriods;
    for (final m in months) {
      _applyDeficitRolloverIfNeeded(m);
    }
    notifyListeners();
  }

  // ---------------- Alertas: próximos pagamentos pendentes ----------------
  List<BudgetItem> upcomingDue({int days = 7}) {
    final now = DateTime.now();
    final limit = now.add(Duration(days: days));
    return _budgets.where((b) {
      if (b.status == TxStatus.pagado) return false;
      if (b.dueDate == null) return false;
      return b.dueDate!.isAfter(now.subtract(const Duration(days: 1))) &&
          b.dueDate!.isBefore(limit);
    }).toList()..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  }

  // ---------------- Export/Import ----------------
  Map<String, dynamic> exportSnapshot() => storage.exportAll();

  Future<void> importSnapshot(Map<String, dynamic> data) async {
    await storage.importAll(data);
    _loadFromStorage();
    notifyListeners();
  }

  Future<void> resetToSeed() async {
    await storage.clearAll();
    await storage.init();
    await _seed();
    _loadFromStorage();
    _selectedPeriods = {YearMonth(SeedData.seedYear, 12)};
    notifyListeners();
  }

  // ---------------- Utilitário ----------------
  double randomJitter() => Random().nextDouble();
}
