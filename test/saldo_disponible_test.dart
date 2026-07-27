import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/models/enums.dart';
import 'package:flutter_app/models/transaction.dart';
import 'package:flutter_app/services/storage_service.dart';
import 'package:flutter_app/state/app_state.dart';
import 'package:flutter_app/utils/period.dart';

/// Testes de regressão da fórmula do KPI "Saldo Disponible".
///
/// Regla de negocio (confirmada por la usuaria):
///   Saldo Disponible = Ingresos Totales (todo el período)
///                     - Gastos Totales (todo el período)
///                     - Pagos acumulados de Deuda (todo el período)
///                     - Aporte acumulado en Objetivos (todo el período)
///
/// Regla especial de rescate: cuando el usuario rescata dinero de un
/// objetivo, ese valor vuelve a componer el Saldo Disponible Y se resta
/// del total ya aportado a ese objetivo (nunca "desaparece" ni se
/// duplica).
void main() {
  Future<AppState> buildState() async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(StorageService());
    await state.init();
    return state;
  }

  test('Saldo Disponible = Ingresos - Gastos - Deudas - Aportes (sin rescates)', () async {
    final state = await buildState();

    await state.addTxn(
      Txn(
        id: 'ing1',
        type: TxType.ingreso,
        status: TxStatus.pagado,
        country: 'El Salvador',
        category: 'Ingresos',
        subcategory: 'Salario',
        amount: 1000,
        date: DateTime(2025, 1, 10),
      ),
    );
    await state.addTxn(
      Txn(
        id: 'gas1',
        type: TxType.gasto,
        status: TxStatus.pagado,
        country: 'El Salvador',
        category: 'Comida',
        subcategory: 'Supermercado',
        amount: 200,
        date: DateTime(2025, 1, 12),
      ),
    );
    await state.addTxn(
      Txn(
        id: 'deu1',
        type: TxType.deuda,
        status: TxStatus.pagado,
        country: 'El Salvador',
        category: 'Deudas',
        subcategory: 'Tarjeta',
        amount: 150,
        date: DateTime(2025, 1, 15),
      ),
    );
    await state.addTxn(
      Txn(
        id: 'inv1',
        type: TxType.inversion,
        status: TxStatus.pagado,
        country: 'El Salvador',
        category: 'Inversiones',
        subcategory: 'Fondo',
        amount: 100,
        date: DateTime(2025, 1, 20),
        isWithdrawal: false,
      ),
    );

    // Ingresos(1000) - Gastos(200) - Deudas(150) - Aportes(100) = 550
    expect(state.ingresoDisponible, 550);
    expect(state.totalIngresosHistorico, 1000);
    expect(state.totalGastosHistorico, 350); // 200 gasto + 150 deuda
    expect(state.inversionesActuales, 100);
    expect(state.validateFinancialIntegrity(), true);
  });

  test('Un rescate de objetivo vuelve al Saldo Disponible y se resta del aportado', () async {
    final state = await buildState();

    await state.addTxn(
      Txn(
        id: 'ing1',
        type: TxType.ingreso,
        status: TxStatus.pagado,
        country: 'El Salvador',
        category: 'Ingresos',
        subcategory: 'Salario',
        amount: 1000,
        date: DateTime(2025, 1, 10),
      ),
    );
    await state.addTxn(
      Txn(
        id: 'inv1',
        type: TxType.inversion,
        status: TxStatus.pagado,
        country: 'El Salvador',
        category: 'Inversiones',
        subcategory: 'Fondo',
        amount: 300,
        date: DateTime(2025, 1, 15),
        isWithdrawal: false,
      ),
    );

    // Ingresos(1000) - Aportes(300) = 700
    expect(state.ingresoDisponible, 700);
    expect(state.inversionesActuales, 300);

    await state.addTxn(
      Txn(
        id: 'resc1',
        type: TxType.inversion,
        status: TxStatus.pagado,
        country: 'El Salvador',
        category: 'Inversiones',
        subcategory: 'Fondo',
        amount: 120,
        date: DateTime(2025, 1, 25),
        isWithdrawal: true,
      ),
    );

    // El rescate (120) vuelve al Saldo Disponible: 700 + 120 = 820
    expect(state.ingresoDisponible, 820);
    // Y se resta del aportado acumulado: 300 - 120 = 180
    expect(state.inversionesActuales, 180);
    // Invariante fundamental sigue cumpliéndose siempre.
    expect(state.validateFinancialIntegrity(), true);
  });

  test('El filtro de período NUNCA afecta el Saldo Disponible (KPI absoluto)', () async {
    final state = await buildState();

    await state.addTxn(
      Txn(
        id: 'ing_viejo',
        type: TxType.ingreso,
        status: TxStatus.pagado,
        country: 'El Salvador',
        category: 'Ingresos',
        subcategory: 'Salario',
        amount: 500,
        date: DateTime(2020, 1, 10), // fuera de cualquier período reciente
      ),
    );

    final disponibleAntes = state.ingresoDisponible;
    expect(disponibleAntes, 500);

    // Cambiar el período seleccionado (simula el filtro global) no debe
    // alterar el KPI, que siempre se calcula sobre el histórico completo.
    state.setSelectedRange(
      PeriodRange.singleMonth(const YearMonth(2025, 6)),
    );

    expect(state.ingresoDisponible, disponibleAntes);
  });
}
