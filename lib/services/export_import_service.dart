import '../state/app_state.dart';

/// Arquitetura de exportação/importação em CSV/TXT — cobre Transações,
/// Planejamento, Objetivos, Dívidas, Categorias, Subcategorias, Países,
/// Permissões (colaboradores) e Configurações, evitando digitação manual.
/// Cada entidade é serializada como uma tabela CSV independente; o export
/// completo concatena todas as tabelas em um único arquivo TXT com
/// separadores de seção, para não depender de múltiplos arquivos.
class ExportImportService {
  static String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String _row(List<dynamic> cols) =>
      cols.map((c) => _csvEscape(c?.toString() ?? '')).join(',');

  static String transactionsCsv(AppState state) {
    final lines = <String>[
      _row([
        'id',
        'tipo',
        'categoria',
        'subcategoria',
        'valor',
        'fecha',
        'pais',
        'estado',
        'descripcion',
      ]),
    ];
    for (final t in state.txns) {
      lines.add(
        _row([
          t.id,
          t.type.name,
          t.category,
          t.subcategory,
          t.amount,
          t.date.toIso8601String().split('T').first,
          t.country,
          t.status.name,
          t.description,
        ]),
      );
    }
    return lines.join('\n');
  }

  static String budgetsCsv(AppState state) {
    final lines = <String>[
      _row([
        'id',
        'mes',
        'ano',
        'categoria',
        'subcategoria',
        'pais',
        'planificado',
        'prioridad',
        'estado',
        'vencimiento',
      ]),
    ];
    for (final b in state.budgets) {
      lines.add(
        _row([
          b.id,
          b.month,
          b.year,
          b.category,
          b.subcategory,
          b.country,
          b.planned,
          b.priority.name,
          b.status.name,
          b.dueDate?.toIso8601String().split('T').first ?? '',
        ]),
      );
    }
    return lines.join('\n');
  }

  static String goalsCsv(AppState state) {
    final lines = <String>[
      _row([
        'id',
        'nombre',
        'meta_total',
        'acumulado',
        'fecha_objetivo',
        'aporte_mensual',
      ]),
    ];
    for (final g in state.goals) {
      lines.add(
        _row([
          g.id,
          g.name,
          g.targetAmount,
          g.currentAmount,
          g.targetDate?.toIso8601String().split('T').first ?? '',
          g.monthlyTarget.toStringAsFixed(2),
        ]),
      );
    }
    return lines.join('\n');
  }

  static String debtsCsv(AppState state) {
    final lines = <String>[
      _row([
        'id',
        'nombre',
        'valor_total',
        'fecha_inicial',
        'meses',
        'cuota_mensual',
        'cuotas_pagadas',
      ]),
    ];
    for (final d in state.debts) {
      lines.add(
        _row([
          d.id,
          d.name,
          d.totalAmount,
          d.startDate.toIso8601String().split('T').first,
          d.months,
          d.monthlyInstallment.toStringAsFixed(2),
          d.paidInstallments,
        ]),
      );
    }
    return lines.join('\n');
  }

  static String categoriesCsv(AppState state) {
    final lines = <String>[
      _row(['nombre', 'tipo', 'estandar', 'subcategorias']),
    ];
    for (final c in state.expenseCategories) {
      lines.add(
        _row([c.name, 'gasto', !c.isCustom, c.subcategories.join('|')]),
      );
    }
    for (final c in state.incomeCategories) {
      lines.add(
        _row([c.name, 'ingreso', !c.isCustom, c.subcategories.join('|')]),
      );
    }
    return lines.join('\n');
  }

  static String countriesCsv(AppState state) {
    final lines = <String>['pais'];
    lines.addAll(state.countries);
    return lines.join('\n');
  }

  static String collaboratorsCsv(AppState state) {
    final lines = <String>[
      _row(['id', 'nombre', 'email', 'rol', 'invitado_en']),
    ];
    for (final c in state.collaborators) {
      lines.add(
        _row([
          c.id,
          c.name,
          c.email,
          c.role.name,
          c.invitedAt.toIso8601String(),
        ]),
      );
    }
    return lines.join('\n');
  }

  static String settingsCsv(AppState state) {
    final lines = <String>[
      _row(['clave', 'valor']),
      _row(['tema', state.themeMode.name]),
      _row(['propietario', state.ownerName]),
      _row(['cards_visibles', state.visibleCards.join('|')]),
    ];
    return lines.join('\n');
  }

  /// Gera um único arquivo TXT com todas as seções, separadas por
  /// cabeçalhos "=== Nombre ===" — formato simples e legível, adequado
  /// para backup completo sem depender de múltiplos arquivos/planilhas.
  static String fullExportTxt(AppState state) {
    final buffer = StringBuffer();
    void section(String title, String csv) {
      buffer.writeln('=== $title ===');
      buffer.writeln(csv);
      buffer.writeln();
    }

    section('Transacciones', transactionsCsv(state));
    section('Planificacion', budgetsCsv(state));
    section('Objetivos', goalsCsv(state));
    section('Deudas', debtsCsv(state));
    section('Categorias', categoriesCsv(state));
    section('Paises', countriesCsv(state));
    section('Permisos', collaboratorsCsv(state));
    section('Configuraciones', settingsCsv(state));
    return buffer.toString();
  }

  /// Parser simples de CSV de transações para importação — arquitetura
  /// mínima que demuestra el flujo; puede ampliarse a Excel real
  /// integrando un parser de .xlsx en el futuro.
  static List<Map<String, String>> parseCsv(String csv) {
    final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];
    final headers = lines.first.split(',');
    final rows = <Map<String, String>>[];
    for (final line in lines.skip(1)) {
      final cols = line.split(',');
      final map = <String, String>{};
      for (var i = 0; i < headers.length && i < cols.length; i++) {
        map[headers[i].trim()] = cols[i].trim();
      }
      rows.add(map);
    }
    return rows;
  }
}
