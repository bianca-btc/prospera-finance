import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

/// Tela de bloqueio por PIN. Como o app é pensado para uma pessoa
/// específica (com possibilidade de acesso compartilhado via link),
/// o PIN protege o acesso local ao abrir o app.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _entered = '';
  String? _error;

  void _tap(String digit) {
    if (_entered.length >= 6) return;
    setState(() {
      _entered += digit;
      _error = null;
    });
    if (_entered.length == 4) {
      _check();
    }
  }

  void _backspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  void _check() {
    final state = context.read<AppState>();
    final ok = state.tryUnlock(_entered);
    if (!ok) {
      setState(() {
        _error = 'PIN incorrecto';
        _entered = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppLogo(size: 72),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Prospera',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Ingresa tu PIN para continuar',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final filled = i < _entered.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled
                              ? AppColors.brandAmber
                              : Colors.transparent,
                          border: Border.all(color: AppColors.brandAmber),
                        ),
                      );
                    }),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.gasto),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  _NumPad(onTap: _tap, onBackspace: _backspace),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NumPad extends StatelessWidget {
  final void Function(String) onTap;
  final VoidCallback onBackspace;
  const _NumPad({required this.onTap, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.4,
      children: keys.map((k) {
        if (k.isEmpty) return const SizedBox.shrink();
        return Material(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => k == '⌫' ? onBackspace() : onTap(k),
            child: Center(
              child: Text(
                k,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
