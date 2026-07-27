import '../models/transaction.dart';
import '../models/budget_item.dart';
import '../models/taxonomy.dart';
import '../models/goal.dart';
import '../models/debt.dart';
import '../models/enums.dart';

/// Datos iniciales del app: SOLO taxonomía base (categorías/subcategorías
/// y países predeterminados) necesaria para que el usuario pueda empezar a
/// registrar sus propios movimientos desde cero. NO contiene ningún dato
/// de ejemplo/demostración (transacciones, presupuestos, objetivos o
/// deudas) — el usuario final arranca siempre con el app completamente
/// vacío, listo para producción.
class SeedData {
  /// Ninguna transacción de ejemplo: el usuario comienza sin movimientos.
  static List<Txn> buildTransactions() => [];

  /// Ningún ítem de planificación de ejemplo.
  static List<BudgetItem> buildBudgets() => [];

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
        'Alquiler de espacio',
        'Equipo y suministros',
        'Marketing',
        'Servicios profesionales',
      ],
      icon: 'work',
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
        'Negocio propio',
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

  /// Ningún objetivo de ejemplo: el usuario crea sus propios objetivos.
  static List<InvestmentGoal> goals() => [];

  /// Ninguna deuda de ejemplo: el usuario registra sus propias deudas.
  static List<Debt> debts() => [];
}
