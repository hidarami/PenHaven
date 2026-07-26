import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'providers/atmosphere_state.dart';
import 'providers/editor_state.dart';
import 'providers/community_state.dart';
import 'screens/splash_screen.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await NotificationService.instance.init();
  unawaited(NotificationService.instance.requestPermission());
  runApp(const PenHavenApp());
}

class PenHavenApp extends StatelessWidget {
  const PenHavenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => AtmosphereState()),
        ChangeNotifierProvider(create: (_) => EditorState()),
        ChangeNotifierProvider(create: (_) => CommunityState()),
      ],
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            title: 'PenHaven',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
