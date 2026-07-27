import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:flutter_app/main.dart';
import 'package:flutter_app/services/supabase_config.dart';

void main() {
  setUpAll(() async {
    // main() nunca corre en tests (usamos ProsperaApp directamente), por
    // lo que Supabase.initialize debe llamarse aquí manualmente: varios
    // servicios (AuthService) acceden a Supabase.instance.client, que a
    // su vez usa shared_preferences para persistir la sesión — se
    // necesita el mock antes de inicializar.
    SharedPreferences.setMockInitialValues({});
    await sb.Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  });

  testWidgets('Prospera app starts and shows splash or lock/home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProsperaApp());
    await tester.pump();

    // App should build without throwing and show a MaterialApp.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
