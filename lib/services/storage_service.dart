import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Camada simples de persistência local baseada em SharedPreferences,
/// guardando coleções serializadas em JSON. Serve como armazenamento
/// principal do MVP (dados ficam no dispositivo/navegador).
class StorageService {
  static const _kTxns = 'prospera_txns_v1';
  static const _kBudgets = 'prospera_budgets_v1';
  static const _kGoals = 'prospera_goals_v1';
  static const _kDebts = 'prospera_debts_v1';
  static const _kCategoriesExpense = 'prospera_cats_expense_v1';
  static const _kCategoriesIncome = 'prospera_cats_income_v1';
  static const _kCountries = 'prospera_countries_v1';
  static const _kSeeded = 'prospera_seeded_v3';
  static const _kPin = 'prospera_pin_v1';
  static const _kThemeMode = 'prospera_theme_mode_v1';
  static const _kShareToken = 'prospera_share_token_v1';
  static const _kOwnerName = 'prospera_owner_name_v1';
  static const _kCollaborators = 'prospera_collaborators_v1';
  static const _kVisibleCards = 'prospera_visible_cards_v1';
  static const _kPeriodRange = 'prospera_period_range_v1';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool get isSeeded => _prefs.getBool(_kSeeded) ?? false;
  Future<void> setSeeded() async => _prefs.setBool(_kSeeded, true);

  // ---- Genéricos JSON ----
  Future<void> _saveList(String key, List<Map<String, dynamic>> items) async {
    await _prefs.setString(key, jsonEncode(items));
  }

  List<Map<String, dynamic>> _loadList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded.cast<Map<String, dynamic>>();
  }

  // ---- Transações ----
  Future<void> saveTxns(List<Map<String, dynamic>> items) =>
      _saveList(_kTxns, items);
  List<Map<String, dynamic>> loadTxns() => _loadList(_kTxns);

  // ---- Orçamentos ----
  Future<void> saveBudgets(List<Map<String, dynamic>> items) =>
      _saveList(_kBudgets, items);
  List<Map<String, dynamic>> loadBudgets() => _loadList(_kBudgets);

  // ---- Objetivos de investimento ----
  Future<void> saveGoals(List<Map<String, dynamic>> items) =>
      _saveList(_kGoals, items);
  List<Map<String, dynamic>> loadGoals() => _loadList(_kGoals);

  // ---- Dívidas ----
  Future<void> saveDebts(List<Map<String, dynamic>> items) =>
      _saveList(_kDebts, items);
  List<Map<String, dynamic>> loadDebts() => _loadList(_kDebts);

  // ---- Categorias ----
  Future<void> saveExpenseCategories(List<Map<String, dynamic>> items) =>
      _saveList(_kCategoriesExpense, items);
  List<Map<String, dynamic>> loadExpenseCategories() =>
      _loadList(_kCategoriesExpense);

  Future<void> saveIncomeCategories(List<Map<String, dynamic>> items) =>
      _saveList(_kCategoriesIncome, items);
  List<Map<String, dynamic>> loadIncomeCategories() =>
      _loadList(_kCategoriesIncome);

  // ---- Países ----
  Future<void> saveCountries(List<String> items) async {
    await _prefs.setStringList(_kCountries, items);
  }

  List<String> loadCountries() => _prefs.getStringList(_kCountries) ?? [];

  // ---- Segurança / PIN ----
  Future<void> savePin(String? pin) async {
    if (pin == null || pin.isEmpty) {
      await _prefs.remove(_kPin);
    } else {
      await _prefs.setString(_kPin, pin);
    }
  }

  String? loadPin() => _prefs.getString(_kPin);

  // ---- Tema ----
  Future<void> saveThemeMode(String mode) async =>
      _prefs.setString(_kThemeMode, mode);
  String loadThemeMode() => _prefs.getString(_kThemeMode) ?? 'dark';

  // ---- Compartilhamento (link exclusivo) ----
  Future<void> saveShareToken(String? token) async {
    if (token == null) {
      await _prefs.remove(_kShareToken);
    } else {
      await _prefs.setString(_kShareToken, token);
    }
  }

  String? loadShareToken() => _prefs.getString(_kShareToken);

  Future<void> saveOwnerName(String name) async =>
      _prefs.setString(_kOwnerName, name);
  String loadOwnerName() => _prefs.getString(_kOwnerName) ?? 'Propietario';

  // ---- Colaboradores (Propietario/Editor/Visualizador) ----
  Future<void> saveCollaborators(List<Map<String, dynamic>> items) =>
      _saveList(_kCollaborators, items);
  List<Map<String, dynamic>> loadCollaborators() => _loadList(_kCollaborators);

  // ---- Personalização: quais cards aparecem no Resumen ----
  Future<void> saveVisibleCards(List<String> keys) async {
    await _prefs.setStringList(_kVisibleCards, keys);
  }

  List<String>? loadVisibleCards() => _prefs.getStringList(_kVisibleCards);

  // ---- Período selecionado (PeriodRange serializado) ----
  Future<void> savePeriodRange(Map<String, dynamic> json) async {
    await _prefs.setString(_kPeriodRange, jsonEncode(json));
  }

  Map<String, dynamic>? loadPeriodRange() {
    final raw = _prefs.getString(_kPeriodRange);
    if (raw == null || raw.isEmpty) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // ---- Export/Import completo ----
  Map<String, dynamic> exportAll() {
    return {
      'txns': loadTxns(),
      'budgets': loadBudgets(),
      'goals': loadGoals(),
      'debts': loadDebts(),
      'expenseCategories': loadExpenseCategories(),
      'incomeCategories': loadIncomeCategories(),
      'countries': loadCountries(),
      'collaborators': loadCollaborators(),
      'visibleCards': loadVisibleCards(),
    };
  }

  Future<void> importAll(Map<String, dynamic> data) async {
    if (data['txns'] != null) {
      await saveTxns((data['txns'] as List).cast<Map<String, dynamic>>());
    }
    if (data['budgets'] != null) {
      await saveBudgets((data['budgets'] as List).cast<Map<String, dynamic>>());
    }
    if (data['goals'] != null) {
      await saveGoals((data['goals'] as List).cast<Map<String, dynamic>>());
    }
    if (data['debts'] != null) {
      await saveDebts((data['debts'] as List).cast<Map<String, dynamic>>());
    }
    if (data['expenseCategories'] != null) {
      await saveExpenseCategories(
        (data['expenseCategories'] as List).cast<Map<String, dynamic>>(),
      );
    }
    if (data['incomeCategories'] != null) {
      await saveIncomeCategories(
        (data['incomeCategories'] as List).cast<Map<String, dynamic>>(),
      );
    }
    if (data['countries'] != null) {
      await saveCountries(
        (data['countries'] as List).map((e) => e.toString()).toList(),
      );
    }
    if (data['collaborators'] != null) {
      await saveCollaborators(
        (data['collaborators'] as List).cast<Map<String, dynamic>>(),
      );
    }
    if (data['visibleCards'] != null) {
      await saveVisibleCards(
        (data['visibleCards'] as List).map((e) => e.toString()).toList(),
      );
    }
  }

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
