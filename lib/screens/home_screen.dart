import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/app_logo.dart';
import '../widgets/kpi_header.dart';
import '../widgets/period_selector.dart';
import 'resumen_screen.dart';
import 'transacciones_screen.dart';
import 'planificacion_screen.dart';
import 'analisis_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  // Cuando está activo, los KPIs se muestran en una versión reducida para
  // dejar más espacio en pantalla a los listados (Resumen/Transacciones/
  // Planificación/Análisis).
  bool _focusOnList = false;

  final _pages = const [
    ResumenScreen(),
    TransaccionesScreen(),
    PlanificacionScreen(),
    AnalisisScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 28),
            const SizedBox(width: 10),
            const Text(
              'Prospera',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          // Filtro global de período: siempre en la misma posición/tamaño
          // en TODAS las pestañas (Resumen/Transacciones/Planificación/
          // Análisis), a la izquierda del ícono de ajustes — reducido y
          // en la primera línea de la pantalla para minimizar el espacio
          // vertical ocupado (en Resumen, libera el espacio que antes
          // ocupaba, dejándolo disponible para los KPIs).
          const PeriodSelector(appBar: true),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          if (state.hasPin)
            IconButton(
              tooltip: 'Bloquear',
              icon: const Icon(Icons.lock_outline_rounded),
              onPressed: () => state.lock(),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Los KPIs solo tienen sentido como resumen general del estado
          // financiero -- por eso aparecen ÚNICAMENTE en la pestaña Resumen.
          // En las demás pestañas (Transacciones/Planificación/Análisis) se
          // ocultan por completo para dejar toda la pantalla enfocada en su
          // propio listado, evitando la redundancia de repetir el mismo
          // resumen en todas partes.
          if (_tab == 0) ...[
            const SizedBox(height: 4),
            KpiHeader(
              compact: _focusOnList,
              onGastosTap: () => setState(() => _tab = 2),
              onInversionesTap: () => setState(() => _tab = 2),
              onDeudasTap: () => setState(() => _tab = 2),
            ),
            // Control discreto para colapsar/expandir los KPIs: una franja
            // fina y centrada (chevron), pegada al header, en vez de un
            // botón grande en la AppBar. Su posición contextual (justo
            // debajo del propio contenido que controla) lo hace mucho más
            // intuitivo y visualmente ligero.
            _KpiCollapseHandle(
              collapsed: _focusOnList,
              onTap: () => setState(() => _focusOnList = !_focusOnList),
            ),
          ],
          Expanded(child: _pages[_tab]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Resumen',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transacciones',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: 'Planificación',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Análisis',
          ),
        ],
      ),
    );
  }
}

/// Control discreto para colapsar/expandir los KPIs — reemplaza al antiguo
/// botón grande de la AppBar ([_FocusToggleButton], eliminado por ser
/// demasiado grande e intrusivo). Se muestra como una franja delgada
/// pegada justo debajo del header de KPIs, con un pequeño chevron
/// centrado que indica la dirección del gesto (colapsar/expandir) — un
/// patrón visual común y liviano ("handle" de arrastre/colapso), que no
/// compite en tamaño ni protagonismo con el resto de la AppBar.
class _KpiCollapseHandle extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onTap;
  const _KpiCollapseHandle({required this.collapsed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(
      context,
    ).textTheme.bodySmall?.color?.withValues(alpha: 0.55);
    return Tooltip(
      message: collapsed ? 'Mostrar KPIs completos' : 'Reducir KPIs',
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 18,
          width: double.infinity,
          child: Center(
            child: Icon(
              collapsed
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
              size: 20,
              color: mutedColor,
            ),
          ),
        ),
      ),
    );
  }
}
