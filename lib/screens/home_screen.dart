import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/kpi_header.dart';
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
          _FocusToggleButton(
            active: _focusOnList,
            onTap: () => setState(() => _focusOnList = !_focusOnList),
          ),
          const SizedBox(width: 4),
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
          const SizedBox(height: 4),
          // El selector de período ahora comparte la misma fila que los
          // KPIs de Ingresos/Gastos/Inversiones (ver KpiHeader), para no
          // ocupar una línea completa solo para el filtro.
          KpiHeader(
            compact: _focusOnList,
            onGastosTap: () => setState(() => _tab = 2),
            onInversionesTap: () => setState(() => _tab = 2),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),
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

/// Botón que alterna el modo "enfocar listado" (KPIs reducidos, más
/// espacio para las listas de Resumen/Transacciones/Planificación/Análisis).
class _FocusToggleButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _FocusToggleButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: active
          ? 'Mostrar KPIs completos'
          : 'Enfocar listado (reducir KPIs)',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: active
                ? AppColors.brandAmber.withValues(alpha: 0.18)
                : null,
            border: Border.all(
              color: active
                  ? AppColors.brandAmber
                  : AppColors.darkBorder,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            active
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            size: 18,
            color: active ? AppColors.brandAmber : null,
          ),
        ),
      ),
    );
  }
}
