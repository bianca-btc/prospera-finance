import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'auth_service.dart';
import 'supabase_config.dart';
import '../state/app_state.dart';

/// Sincronización en la nube: sube/baja un snapshot JSON completo del
/// usuario a una única tabla Supabase (`user_data`), reutilizando
/// `AppState.exportSnapshot()` / `importSnapshot()`.
///
/// Diseño intencionalmente simple (sin cola de sincronización, sin
/// resolución de conflictos por campo): como no hay multi-usuario por
/// cuenta, "last write wins" vía `upsert` es correcto y suficiente.
class CloudSyncService {
  final AuthService auth;
  final AppState appState;

  CloudSyncService({required this.auth, required this.appState}) {
    auth.addListener(_onAuthChanged);
    appState.addListener(_onAppStateChanged);
  }

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  Timer? _debounce;
  bool _syncing = false;
  bool _suppressNextUpload = false;
  String? _lastUserId;

  bool get isSyncing => _syncing;
  String? lastError;

  void _onAuthChanged() {
    final userId = auth.currentUser?.id;
    if (userId != null && userId != _lastUserId) {
      _lastUserId = userId;
      // Sesión nueva: primero intentamos traer datos remotos.
      unawaited(downloadNow());
    } else if (userId == null) {
      _lastUserId = null;
    }
  }

  void _onAppStateChanged() {
    if (_suppressNextUpload) {
      _suppressNextUpload = false;
      return;
    }
    if (!auth.isSignedIn) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      unawaited(uploadNow());
    });
  }

  /// Sube el snapshot local actual a Supabase (sobrescribe el remoto).
  Future<void> uploadNow() async {
    final userId = auth.currentUser?.id;
    if (userId == null) return;
    _syncing = true;
    try {
      await _client.from(SupabaseConfig.userDataTable).upsert({
        'user_id': userId,
        'data': appState.exportSnapshot(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      lastError = null;
    } catch (e) {
      lastError = 'Error al sincronizar: $e';
      if (kDebugMode) debugPrint(lastError);
    } finally {
      _syncing = false;
    }
  }

  /// Descarga el snapshot remoto (si existe) y reemplaza los datos
  /// locales. Se llama automáticamente al iniciar sesión.
  Future<void> downloadNow() async {
    final userId = auth.currentUser?.id;
    if (userId == null) return;
    _syncing = true;
    try {
      final row = await _client
          .from(SupabaseConfig.userDataTable)
          .select('data')
          .eq('user_id', userId)
          .maybeSingle();
      final remoteData = row?['data'] as Map<String, dynamic>?;
      if (remoteData != null && remoteData.isNotEmpty) {
        _suppressNextUpload = true;
        await appState.importSnapshot(remoteData);
      } else {
        // No hay backup remoto todavía: subimos el estado local actual.
        await uploadNow();
      }
      lastError = null;
    } catch (e) {
      lastError = 'Error al descargar datos: $e';
      if (kDebugMode) debugPrint(lastError);
    } finally {
      _syncing = false;
    }
  }

  void dispose() {
    _debounce?.cancel();
    auth.removeListener(_onAuthChanged);
    appState.removeListener(_onAppStateChanged);
  }
}
