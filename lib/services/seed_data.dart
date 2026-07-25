import 'package:uuid/uuid.dart';
import '../models/enums.dart';
import '../models/transaction.dart';
import '../models/budget_item.dart';
import '../models/taxonomy.dart';

const _uuid = Uuid();

/// Dados oficiais do usuário (Info.txt), reorganizados conforme o brief:
/// - "Ceremonia" separada em Ingreso (Servicios > Ceremonias) e Gastos
///   (Eventos > Alquiler de espacio, Eventos > Equipo/Staff).
/// - "Alquiler" consolidado em 3 subcategorias distintas conforme contexto:
///   Eventos > Alquiler de espacio, Vivienda > Alquiler, Transporte > Alquiler de vehículo.
/// - Itens com valor $0 marcados como pendentes de programação (isPending)
///   e não contabilizados nos totais.
/// Ano de referência: 2025 (meses 8 a 12 = Agosto a Diciembre).
class SeedData {
  static const seedYear = 2025;
  static const seedCountry = 'El Salvador';

  static List<Txn> buildTransactions() {
    final List<Txn> list = [];
    for (final month in [8, 9, 10, 11, 12]) {
      final date = DateTime(seedYear, month, 5);

      // INGRESO: Servicios > Ceremonias
      list.add(
        Txn(
          id: _uuid.v4(),
          type: TxType.ingreso,
          nature: TxNature.fijo,
          status: TxStatus.pendiente,
          country: seedCountry,
          category: 'Servicios',
          subcategory: 'Ceremonias',
          amount: 2280,
          date: date,
          description: 'Ingreso por ceremonias del mes',
        ),
      );

      // GASTO: Eventos > Alquiler de espacio
      list.add(
        Txn(
          id: _uuid.v4(),
          type: TxType.gasto,
          nature: TxNature.fijo,
          status: TxStatus.pendiente,
          country: seedCountry,
          category: 'Eventos',
          subcategory: 'Alquiler de espacio',
          amount: 250,
          date: date,
          description: 'Alquiler del espacio para la ceremonia',
        ),
      );

      // GASTO: Eventos > Equipo/Staff
      list.add(
        Txn(
          id: _uuid.v4(),
          type: TxType.gasto,
          nature: TxNature.variable,
          status: TxStatus.pendiente,
          country: seedCountry,
          category: 'Eventos',
          subcategory: 'Equipo/Staff',
          amount: 250,
          date: date,
          description: 'Pago al equipo/staff de apoyo',
        ),
      );

      // GASTO: Transporte > Pasajes (Vuelo)
      list.add(
        Txn(
          id: _uuid.v4(),
          type: TxType.gasto,
          nature: TxNature.variable,
          status: TxStatus.pendiente,
          country: seedCountry,
          category: 'Transporte',
          subcategory: 'Pasajes',
          amount: 350,
          date: date,
          description: 'Pasaje de vuelo',
        ),
      );

      // GASTO: Transporte > Alquiler de vehículo
      list.add(
        Txn(
          id: _uuid.v4(),
          type: TxType.gasto,
          nature: TxNature.variable,
          status: TxStatus.pendiente,
          country: seedCountry,
          category: 'Transporte',
          subcategory: 'Alquiler de vehículo',
          amount: 100,
          date: date,
          description: 'Alquiler de carro',
        ),
      );

      // GASTO: Transporte > Combustible
      list.add(
        Txn(
          id: _uuid.v4(),
          type: TxType.gasto,
          nature: TxNature.variable,
          status: TxStatus.pendiente,
          country: seedCountry,
          category: 'Transporte',
          subcategory: 'Combustible',
          amount: 100,
          date: date,
          description: 'Gasolina del vehículo',
        ),
      );

      // GASTO: Vivienda > Alquiler (valor principal $315)
      list.add(
        Txn(
          id: _uuid.v4(),
          type: TxType.gasto,
          nature: TxNature.fijo,
          status: TxStatus.pendiente,
          country: seedCountry,
          category: 'Vivienda',
          subcategory: 'Alquiler',
          amount: 315,
          date: date,
          description: 'Alquiler de la casa',
        ),
      );

      // PENDIENTE $0: Vivienda > Alquiler duplicado, a programar
      list.add(
        Txn(
          id: _uuid.v4(),
          type: TxType.gasto,
          nature: TxNature.fijo,
          status: TxStatus.pendiente,
          country: seedCountry,
          category: 'Vivienda',
          subcategory: 'Alquiler',
          amount: 0,
          date: date,
          description: 'Pendiente de programar (duplicado original)',
          isPending: true,
        ),
      );

      // PENDIENTE $0: Deudas > Préstamo (Gloria)
      list.add(
        Txn(
          id: _uuid.v4(),
          type: TxType.deuda,
          nature: TxNature.fijo,
          status: TxStatus.pendiente,
          country: seedCountry,
          category: 'Deudas',
          subcategory: 'Préstamo (Gloria)',
          amount: 0,
          date: date,
          description: 'Deuda pendiente de activación',
          isPending: true,
        ),
      );
    }
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
          category: 'Eventos',
          subcategory: 'Alquiler de espacio',
          country: seedCountry,
          planned: 250,
          nature: TxNature.fijo,
          priority: Priority.alta,
        ),
        BudgetItem(
          id: _uuid.v4(),
          month: month,
          year: seedYear,
          category: 'Eventos',
          subcategory: 'Equipo/Staff',
          country: seedCountry,
          planned: 250,
          nature: TxNature.variable,
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
          nature: TxNature.variable,
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
          nature: TxNature.variable,
          priority: Priority.media,
        ),
        BudgetItem(
          id: _uuid.v4(),
          month: month,
          year: seedYear,
          category: 'Transporte',
          subcategory: 'Combustible',
          country: seedCountry,
          planned: 100,
          nature: TxNature.variable,
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
          nature: TxNature.fijo,
          priority: Priority.alta,
          dueDate: DateTime(seedYear, month, 5),
        ),
      ]);
    }
    return list;
  }

  static List<CategoryDef> expenseCategories() => [
    CategoryDef(
      name: 'Eventos',
      subcategories: ['Alquiler de espacio', 'Equipo/Staff'],
      icon: 'event',
    ),
    CategoryDef(
      name: 'Transporte',
      subcategories: ['Pasajes', 'Alquiler de vehículo', 'Combustible'],
      icon: 'directions_car',
    ),
    CategoryDef(
      name: 'Vivienda',
      subcategories: ['Alquiler', 'Servicios básicos'],
      icon: 'home',
    ),
    CategoryDef(
      name: 'Deudas',
      subcategories: ['Préstamo (Gloria)'],
      icon: 'account_balance',
    ),
    CategoryDef(
      name: 'Alimentación',
      subcategories: ['Supermercado', 'Restaurantes'],
      icon: 'restaurant',
    ),
    CategoryDef(
      name: 'Ocio',
      subcategories: ['Entretenimiento', 'Viajes'],
      icon: 'sports_esports',
    ),
    CategoryDef(
      name: 'Educación',
      subcategories: ['Cursos', 'Materiales'],
      icon: 'school',
    ),
    CategoryDef(
      name: 'Salud',
      subcategories: ['Consultas', 'Medicamentos'],
      icon: 'local_hospital',
    ),
  ];

  static List<CategoryDef> incomeCategories() => [
    CategoryDef(
      name: 'Servicios',
      subcategories: ['Ceremonias', 'Consultorías'],
      icon: 'volunteer_activism',
    ),
    CategoryDef(
      name: 'Otros ingresos',
      subcategories: ['Regalos', 'Ventas'],
      icon: 'attach_money',
    ),
  ];

  static List<String> countries() => [
    'Panamá',
    'El Salvador',
    'Honduras',
    'Argentina',
    'Brasil',
  ];
}
