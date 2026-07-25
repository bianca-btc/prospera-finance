import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Diálogo simples para adicionar um novo item de texto (categoria,
/// subcategoria ou país), reutilizado em vários pontos do app.
Future<String?> showAddItemDialog(
  BuildContext context, {
  required String title,
  String hint = 'Nombre',
}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('Agregar'),
        ),
      ],
    ),
  );
}

/// Diálogo de confirmação de remoção genérico.
Future<bool> showConfirmDeleteDialog(
  BuildContext context, {
  required String itemName,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: Text(
            '¿Deseas eliminar "$itemName"? Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Eliminar',
                style: TextStyle(color: AppColors.gasto),
              ),
            ),
          ],
        ),
      ) ??
      false;
}
