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
          const PeriodSelector(),
          const SizedBox(height: 8),
          const KpiHeader(),
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
