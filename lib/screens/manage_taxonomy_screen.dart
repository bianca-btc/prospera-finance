import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/taxonomy.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/manage_lists_dialogs.dart';

/// Tela de gerenciamento de categorias/subcategorias (gastos ou ingresos).
/// Permite adicionar e remover livremente, conforme exigido pelo brief.
class ManageTaxonomyScreen extends StatelessWidget {
  final bool isExpense;
  const ManageTaxonomyScreen({super.key, required this.isExpense});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cats = isExpense ? state.expenseCategories : state.incomeCategories;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isExpense ? 'Categorías de gastos/deudas' : 'Categorías de ingresos',
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final name = await showAddItemDialog(
            context,
            title: 'Nueva categoría',
          );
          if (name != null && name.isNotEmpty) {
            final cat = CategoryDef(name: name, subcategories: []);
            if (isExpense) {
              await state.addExpenseCategory(cat);
            } else {
              await state.addIncomeCategory(cat);
            }
          }
        },
        child: const Icon(Icons.add_rounded),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          90,
        ),
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) {
          final cat = cats[i];
          return SectionCard(
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              leading: CategoryIcon(
                iconKey: cat.icon,
                color: AppColors.brandAmber,
                size: 34,
              ),
              title: Text(
                cat.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.gasto,
                ),
                onPressed: () async {
                  final ok = await showConfirmDeleteDialog(
                    context,
                    itemName: cat.name,
                  );
                  if (ok)
                    await state.removeCategory(
                      isExpense: isExpense,
                      category: cat.name,
                    );
                },
              ),
              children: [
                ...cat.subcategories.map(
                  (sub) => ListTile(
                    dense: true,
                    title: Text(sub, style: const TextStyle(fontSize: 13.5)),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.gasto,
                      ),
                      onPressed: () async {
                        final ok = await showConfirmDeleteDialog(
                          context,
                          itemName: sub,
                        );
                        if (ok)
                          await state.removeSubcategory(
                            isExpense: isExpense,
                            category: cat.name,
                            subcategory: sub,
                          );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Agregar subcategoría'),
                      onPressed: () async {
                        final name = await showAddItemDialog(
                          context,
                          title: 'Nueva subcategoría de ${cat.name}',
                        );
                        if (name != null && name.isNotEmpty) {
                          await state.addSubcategory(
                            isExpense: isExpense,
                            category: cat.name,
                            subcategory: name,
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Tela de gerenciamento de países (adicionar/remover).
class ManageCountriesScreen extends StatelessWidget {
  const ManageCountriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final countries = state.countries;

    return Scaffold(
      appBar: AppBar(title: const Text('Países / Ubicaciones')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final name = await showAddItemDialog(context, title: 'Nuevo país');
          if (name != null && name.isNotEmpty) {
            await state.addCountry(name);
          }
        },
        child: const Icon(Icons.add_rounded),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          90,
        ),
        itemCount: countries.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) {
          final c = countries[i];
          return SectionCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(Icons.flag_outlined, color: AppColors.brandAmber),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    c,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.gasto,
                  ),
                  onPressed: () async {
                    final ok = await showConfirmDeleteDialog(
                      context,
                      itemName: c,
                    );
                    if (ok) await state.removeCountry(c);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
