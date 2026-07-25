import 'package:uuid/uuid.dart';
import '../models/enums.dart';
import '../models/transaction.dart';
import '../models/budget_item.dart';
import '../models/taxonomy.dart';
import '../models/goal.dart';
import '../models/debt.dart';

const _uuid = Uuid();

/// Dados oficiais do usuário (Info.txt), reorganizados nas categorías
/// padrão do Prospera. Ano de referência: 2025 (meses 8 a 12).
class SeedData {
  static const seedYear = 2025;
  static const seedCountry = 'El Salvador';

  // IDs fixos para os objetivos de demonstração — usados tanto em [goals]
  // quanto nas transações de aporte geradas em [buildTransactions], para
  // que InvestmentGoal.currentAmount (derivado das transações vinculadas,
  // única fonte de verdade) reflita o progreso de demonstração pretendido.
  static final String _emergencyGoalId = _uuid.v4();
  static final String _equipmentGoalId = _uuid.v4();

  static List<Txn> buildTransactions() {
    final List<Txn> list = [];
    for (final month in [8, 9, 10, 11, 12]) {
      final date = DateTime(seedYear, month, 5);

      list.add(
        Txn(
          id: _uuid.v4(),
          type: TxType.ingreso,
          status: TxStatus.pagado,
          country: seedCountry,
          category: 'Negocios',
          subcategory: 'Ceremonias',
          amount: 2280,
          date: date,
          description: 'Ingreso por ceremonias del mes',
        ),
      );

      list.add(
        Txn(
          id: _uuid.v4(),
          type: TxType.gasto,
          status: TxStatus.pagado,
          country: seedCountry,
          category: 'Negocios',
          subcategory: 'Alquiler de espacio',
          amount: 250,
          date: date,
          description: 'Alquiler del espacio para la ceremonia',
        ),
      );

      list.add(
        Txn(
          id: _uuid.v4(),
          type: TxType.gasto,
          status: TxStatus.pagado,
          country: seedCountry,
          category: 'Negocios',
          subcategory: 'Equipo y staff',
          amount: 250,
          date: date,
          description: 'Pago al equipo/staff de apoyo',
        ),
      );

      list.add(
        Txn(
          id: _uuid.v4(),
          type: TxType.gasto,
          status: TxStatus.pagado,
          country: seedCountry,
          category: 'Transporte',
          subcategory: 'Pasajes',
          amount: 350,
          date: date,
          description: 'Pasaje de vuelo',
        ),
      );

      list.add(
        Txn(
          id: _uuid.v4(),
          type: TxType.gasto,
          status: TxStatus.pagado,
          country: seedCountry,
          category: 'Transporte',
          subcategory: 'Alquiler de vehículo',
          amount: 100,
          date: date,
          description: 'Alquiler de carro',
        ),
      );

      list.add(
        Txn(
          id: _uuid.v4(),
          type: TxType.gasto,
          status: TxStatus.pagado,
          country: seedCountry,
          category: 'Transporte',
          subcategory: 'Gasolina',
          amount: 100,
          date: date,
          description: 'Gasolina del vehículo',
        ),
      );

      list.add(
        Txn(
          id: _uuid.v4(),
          type: TxType.gasto,
          status: TxStatus.pagado,
          country: seedCountry,
          category: 'Vivienda',
          subcategory: 'Alquiler',
          amount: 315,
          date: date,
          description: 'Alquiler de la casa',
        ),
      );

      // Pendiente $0 (a programar) — não conta nos totais.
      list.add(
        Txn(
          id: _uuid.v4(),
          type: TxType.gasto,
          status: TxStatus.pendiente,
          country: seedCountry,
          category: 'Vivienda',
          subcategory: 'Alquiler',
          amount: 0,
          date: date,
          description: 'Pendiente de programar',
          isPending: true,
        ),
      );
    }

    // Aportes de demonstração vinculados aos objetivos (única fonte de
    // verdade: InvestmentGoal.currentAmount é recalculado a partir destas
    // transações, então elas precisam existir para reproduzir o progreso
    // esperado nos dados de exemplo).
    list.add(
      Txn(
        id: _uuid.v4(),
        type: TxType.inversion,
        status: TxStatus.pagado,
        country: seedCountry,
        category: 'Inversiones',
        subcategory: 'Fondo de emergencia',
        amount: 450,
        date: DateTime(seedYear, 9, 10),
        description: 'Aporte a "Fondo de emergencia"',
        goalId: _emergencyGoalId,
      ),
    );
    list.add(
      Txn(
        id: _uuid.v4(),
        type: TxType.inversion,
        status: TxStatus.pagado,
        country: seedCountry,
        category: 'Inversiones',
        subcategory: 'Nuevo equipo de ceremonia',
        amount: 200,
        date: DateTime(seedYear, 10, 15),
        description: 'Aporte a "Nuevo equipo de ceremonia"',
        goalId: _equipmentGoalId,
      ),
    );
    return list;
  }

  static List<BudgetItem> buildBudgets() {
    final List<BudgetItem> list = [];
    for (final month in [8, 9, 10, 11, 12]) {
      list.addAll([
        BudgetItem(
          id: _uuid.v4(),
          month: month,
          year: seedYear,
          category: 'Negocios',
          subcategory: 'Alquiler de espacio',
          country: seedCountry,
          planned: 250,
          priority: Priority.alta,
        ),
        BudgetItem(
          id: _uuid.v4(),
          month: month,
          year: seedYear,
          category: 'Negocios',
          subcategory: 'Equipo y staff',
          country: seedCountry,
          planned: 250,
          priority: Priority.media,
        ),
        BudgetItem(
          id: _uuid.v4(),
          month: month,
          year: seedYear,
          category: 'Transporte',
          subcategory: 'Pasajes',
          country: seedCountry,
          planned: 350,
          priority: Priority.alta,
        ),
        BudgetItem(
          id: _uuid.v4(),
          month: month,
          year: seedYear,
          category: 'Transporte',
          subcategory: 'Alquiler de vehículo',
          country: seedCountry,
          planned: 100,
          priority: Priority.media,
        ),
        BudgetItem(
          id: _uuid.v4(),
          month: month,
          year: seedYear,
          category: 'Transporte',
          subcategory: 'Gasolina',
          country: seedCountry,
          planned: 100,
          priority: Priority.baja,
        ),
        BudgetItem(
          id: _uuid.v4(),
          month: month,
          year: seedYear,
          category: 'Vivienda',
          subcategory: 'Alquiler',
          country: seedCountry,
          planned: 315,
          priority: Priority.alta,
          dueDate: DateTime(seedYear, month, 5),
        ),
      ]);
    }
    return list;
  }

  /// Categorías padrão do Prospera (conforme brief). isCustom=false para
  /// que a UI sempre as liste primeiro, com as categorías do usuário depois.
  static List<CategoryDef> expenseCategories() => [
    CategoryDef(
      name: 'Vivienda',
      subcategories: ['Alquiler', 'Servicios básicos', 'Mantenimiento'],
      icon: 'home',
      controllability: Controllability.pocoControlable,
    ),
    CategoryDef(
      name: 'Alimentación',
      subcategories: ['Supermercado', 'Restaurantes'],
      icon: 'restaurant',
      controllability: Controllability.semiControlable,
      subControllability: {'Restaurantes': Controllability.controlable},
    ),
    CategoryDef(
      name: 'Transporte',
      subcategories: [
        'Pasajes',
        'Alquiler de vehículo',
        'Gasolina',
        'Mantenimiento',
      ],
      icon: 'directions_car',
      controllability: Controllability.controlable,
    ),
    CategoryDef(
      name: 'Salud',
      subcategories: ['Consultas', 'Medicamentos', 'Seguro'],
      icon: 'local_hospital',
      controllability: Controllability.pocoControlable,
    ),
    CategoryDef(
      name: 'Educación',
      subcategories: ['Cursos', 'Materiales', 'Colegiatura'],
      icon: 'school',
      controllability: Controllability.pocoControlable,
    ),
    CategoryDef(
      name: 'Negocios',
      subcategories: [
        'Ceremonias',
        'Alquiler de espacio',
        'Equipo y staff',
        'Marketing',
      ],
      icon: 'volunteer_activism',
      controllability: Controllability.semiControlable,
    ),
    CategoryDef(
      name: 'Ocio',
      subcategories: ['Entretenimiento', 'Viajes', 'Compras', 'Regalos'],
      icon: 'sports_esports',
      controllability: Controllability.controlable,
    ),
    CategoryDef(
      name: 'Impuestos',
      subcategories: ['Impuesto sobre la renta', 'Otros impuestos'],
      icon: 'account_balance',
      controllability: Controllability.pocoControlable,
    ),
    CategoryDef(
      name: 'Deudas',
      subcategories: ['Préstamos', 'Tarjetas de crédito'],
      icon: 'credit_card',
      controllability: Controllability.pocoControlable,
    ),
    CategoryDef(
      name: 'Otros',
      subcategories: ['Varios'],
      icon: 'more_horiz',
      controllability: Controllability.semiControlable,
    ),
  ];

  static List<CategoryDef> incomeCategories() => [
    CategoryDef(
      name: 'Ingresos',
      subcategories: [
        'Salario',
        'Ceremonias',
        'Consultorías',
        'Ventas',
        'Otros ingresos',
      ],
      icon: 'attach_money',
    ),
    CategoryDef(
      name: 'Inversiones',
      subcategories: ['Rendimientos', 'Dividendos'],
      icon: 'trending_up',
    ),
  ];

  static List<String> countries() => [
    'Panamá',
    'El Salvador',
    'Honduras',
    'Brasil',
    'Argentina',
  ];

  static List<InvestmentGoal> goals() => [
    InvestmentGoal(
      id: _emergencyGoalId,
      name: 'Fondo de emergencia',
      targetAmount: 3000,
      // currentAmount es derivado automáticamente por AppState a partir de
      // las transacciones vinculadas (goalId) — ver aportes en
      // buildTransactions(). No se fija manualmente aquí (fuente única).
      targetDate: DateTime(seedYear + 1, 6, 1),
      description: 'Cobertura de 3 meses de gastos fijos',
      icon: 'savings',
      category: 'Inversiones',
      subcategory: 'Fondo de emergencia',
      country: seedCountry,
    ),
    InvestmentGoal(
      id: _equipmentGoalId,
      name: 'Nuevo equipo de ceremonia',
      targetAmount: 1200,
      targetDate: DateTime(seedYear, 12, 1),
      icon: 'flag',
      category: 'Inversiones',
      subcategory: 'Nuevo equipo de ceremonia',
      country: seedCountry,
    ),
  ];

  static List<Debt> debts() => [];
}
