import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'google_auth_service.dart';

/// Nombre del archivo de Google Sheets que Prospera crea (una sola
/// vez) dentro del Google Drive del propio usuario para guardar el
/// respaldo completo de sus datos.
const String prosperaBackupSheetName = 'Prospera Backup';

/// Tamaño máximo de texto por celda que usamos al partir el JSON en
/// varios trozos (el límite real de Google Sheets es 50.000
/// caracteres por celda; dejamos margen de seguridad).
const int _kChunkSize = 40000;

/// Excepción específica para errores de la sincronización con
/// Google Sheets, para poder mostrar mensajes claros al usuario.
class GoogleSheetsException implements Exception {
  final String message;
  GoogleSheetsException(this.message);
  @override
  String toString() => message;
}

/// Servicio responsable de:
/// 1. Encontrar (o crear) la hoja de cálculo "Prospera Backup" en el
///    Google Drive del usuario.
/// 2. Escribir en ella el snapshot JSON completo de la app
///    (transacciones, planificación, objetivos, deudas, categorías,
///    países, colaboradores, ajustes — es decir, exactamente lo que
///    devuelve `AppState.exportSnapshot()`).
/// 3. Leer ese snapshot de vuelta, para restaurarlo automáticamente
///    cuando el usuario reinstala la app.
///
/// El snapshot se guarda como texto JSON partido en varias celdas de
/// la columna A (a partir de la fila 2) de la pestaña "Backup",
/// porque Google Sheets limita cada celda a 50.000 caracteres. La
/// fila 1 guarda metadatos (versión, fecha de actualización y
/// cantidad de trozos) para poder reconstruir el JSON al leer.
class GoogleSheetsService {
  final GoogleAuthService auth;
  GoogleSheetsService(this.auth);

  static const String _sheetsBase = 'https://sheets.googleapis.com/v4/spreadsheets';
  static const String _driveBase = 'https://www.googleapis.com/drive/v3/files';

  String? _cachedSpreadsheetId;

  Future<Map<String, String>> _headers({bool interactive = false}) async {
    final h = await auth.authHeaders(promptIfNecessary: interactive);
    if (h == null) {
      throw GoogleSheetsException(
        'No se pudo obtener autorización de Google. Vuelve a conectar tu cuenta.',
      );
    }
    return {...h, 'Content-Type': 'application/json'};
  }

  /// Busca en el Drive del usuario un archivo de Sheets creado por
  /// esta app con el nombre [prosperaBackupSheetName]. Devuelve su
  /// `id` o null si no existe todavía (por ejemplo, primera vez que
  /// el usuario activa la sincronización, o app recién reinstalada
  /// pero backup nunca creado).
  Future<String?> _findExistingSpreadsheetId({bool interactive = false}) async {
    final headers = await _headers(interactive: interactive);
    final query = Uri.encodeQueryComponent(
      "name='$prosperaBackupSheetName' and mimeType='application/vnd.google-apps.spreadsheet' and trashed=false",
    );
    final uri = Uri.parse(
      '$_driveBase?q=$query&fields=files(id,name,modifiedTime)&spaces=drive',
    );
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode != 200) {
      throw GoogleSheetsException(
        'Error buscando el respaldo en Google Drive (${resp.statusCode}).',
      );
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final files = (data['files'] as List?) ?? [];
    if (files.isEmpty) return null;
    // Si por alguna razón hay más de un archivo con ese nombre, usa
    // el más reciente.
    files.sort((a, b) => (b['modifiedTime'] as String).compareTo(
          a['modifiedTime'] as String,
        ));
    return files.first['id'] as String;
  }

  /// Crea una nueva hoja de cálculo "Prospera Backup" en el Drive del
  /// usuario, con una pestaña llamada "Backup" y encabezados.
  Future<String> _createSpreadsheet({bool interactive = true}) async {
    final headers = await _headers(interactive: interactive);
    final body = jsonEncode({
      'properties': {'title': prosperaBackupSheetName},
      'sheets': [
        {
          'properties': {'title': 'Backup'},
          'data': [
            {
              'startRow': 0,
              'startColumn': 0,
              'rowData': [
                {
                  'values': [
                    {
                      'userEnteredValue': {
                        'stringValue':
                            'metadata_json (no editar manualmente)'
                      }
                    }
                  ]
                }
              ]
            }
          ]
        }
      ],
    });
    final resp = await http.post(Uri.parse(_sheetsBase), headers: headers, body: body);
    if (resp.statusCode != 200) {
      throw GoogleSheetsException(
        'No se pudo crear la hoja de respaldo en Google Sheets (${resp.statusCode}): ${resp.body}',
      );
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['spreadsheetId'] as String;
  }

  /// Devuelve el `spreadsheetId` de la hoja de backup, buscándola o
  /// creándola si es necesario. Se cachea en memoria durante la
  /// sesión de la app para evitar llamadas repetidas.
  Future<String> _getOrCreateSpreadsheetId({bool interactive = true}) async {
    if (_cachedSpreadsheetId != null) return _cachedSpreadsheetId!;
    final existing = await _findExistingSpreadsheetId(interactive: interactive);
    final id = existing ?? await _createSpreadsheet(interactive: interactive);
    _cachedSpreadsheetId = id;
    return id;
  }

  /// Sube el snapshot completo de datos ([snapshot], igual al mapa
  /// devuelto por `AppState.exportSnapshot()`) a la hoja de Google
  /// Sheets del usuario, sobrescribiendo el contenido anterior.
  Future<void> uploadSnapshot(
    Map<String, dynamic> snapshot, {
    bool interactive = true,
  }) async {
    final id = await _getOrCreateSpreadsheetId(interactive: interactive);
    final jsonStr = jsonEncode(snapshot);
    final chunks = <String>[];
    for (var i = 0; i < jsonStr.length; i += _kChunkSize) {
      chunks.add(
        jsonStr.substring(
          i,
          i + _kChunkSize > jsonStr.length ? jsonStr.length : i + _kChunkSize,
        ),
      );
    }

    final metadata = jsonEncode({
      'app': 'prospera',
      'format': 'json_v1',
      'updatedAt': DateTime.now().toIso8601String(),
      'chunkCount': chunks.length,
    });

    // Fila 1: metadatos. Filas 2..N: trozos del JSON, uno por fila,
    // todos en la columna A.
    final values = <List<String>>[
      [metadata],
      ...chunks.map((c) => [c]),
    ];

    final headers = await _headers(interactive: interactive);
    // Limpia el rango anterior primero, por si el nuevo snapshot es
    // más corto que el anterior (menos filas).
    final clearUri = Uri.parse(
      '$_sheetsBase/$id/values/Backup!A1:A20000:clear',
    );
    await http.post(clearUri, headers: headers, body: jsonEncode({}));

    final updateUri = Uri.parse(
      '$_sheetsBase/$id/values/Backup!A1?valueInputOption=RAW',
    );
    final resp = await http.put(
      updateUri,
      headers: headers,
      body: jsonEncode({'values': values}),
    );
    if (resp.statusCode != 200) {
      throw GoogleSheetsException(
        'No se pudo guardar el respaldo en Google Sheets (${resp.statusCode}): ${resp.body}',
      );
    }
    if (kDebugMode) {
      debugPrint(
        'GoogleSheetsService: snapshot subido (${jsonStr.length} chars, ${chunks.length} trozos).',
      );
    }
  }

  /// Descarga y reconstruye el snapshot guardado en la hoja de
  /// Google Sheets del usuario. Devuelve null si no existe ningún
  /// respaldo todavía (hoja no creada, o vacía).
  Future<Map<String, dynamic>?> downloadSnapshot({
    bool interactive = false,
  }) async {
    final id = await _findExistingSpreadsheetId(interactive: interactive);
    if (id == null) return null;
    _cachedSpreadsheetId = id;

    final headers = await _headers(interactive: interactive);
    final uri = Uri.parse('$_sheetsBase/$id/values/Backup!A1:A20000');
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode != 200) {
      throw GoogleSheetsException(
        'No se pudo leer el respaldo de Google Sheets (${resp.statusCode}).',
      );
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final rows = (data['values'] as List?) ?? [];
    if (rows.isEmpty) return null;

    final firstRow = rows.first as List;
    if (firstRow.isEmpty) return null;
    Map<String, dynamic>? metadata;
    try {
      metadata = jsonDecode(firstRow.first as String) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    final chunkCount = (metadata['chunkCount'] as num?)?.toInt() ?? 0;
    if (chunkCount <= 0 || rows.length < chunkCount + 1) return null;

    final buffer = StringBuffer();
    for (var i = 1; i <= chunkCount; i++) {
      final row = rows[i] as List;
      if (row.isEmpty) continue;
      buffer.write(row.first as String);
    }
    try {
      return jsonDecode(buffer.toString()) as Map<String, dynamic>;
    } catch (e) {
      throw GoogleSheetsException(
        'El respaldo encontrado en Google Sheets está dañado o incompleto.',
      );
    }
  }

  /// Fecha de última actualización del respaldo (según los
  /// metadatos guardados en la hoja), o null si no hay respaldo.
  Future<DateTime?> lastUpdatedAt({bool interactive = false}) async {
    final id = await _findExistingSpreadsheetId(interactive: interactive);
    if (id == null) return null;
    final headers = await _headers(interactive: interactive);
    final uri = Uri.parse('$_sheetsBase/$id/values/Backup!A1');
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final rows = (data['values'] as List?) ?? [];
    if (rows.isEmpty) return null;
    final firstRow = rows.first as List;
    if (firstRow.isEmpty) return null;
    try {
      final metadata = jsonDecode(firstRow.first as String) as Map<String, dynamic>;
      final raw = metadata['updatedAt'] as String?;
      if (raw == null) return null;
      return DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Limpia el id cacheado (por ejemplo, tras cerrar sesión), para
  /// que la próxima operación vuelva a buscar/verificar la hoja.
  void resetCache() {
    _cachedSpreadsheetId = null;
  }
}
