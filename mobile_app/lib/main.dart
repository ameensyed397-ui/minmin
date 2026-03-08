import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'ai_service.dart';
import 'chat_screen.dart';
import 'project_manager.dart';
import 'setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Force portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Dark status bar icons to match dark theme
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0D0D1A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const MinMinApp());
}

class MinMinApp extends StatelessWidget {
  const MinMinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AiService()..initFromSaved()),
        ChangeNotifierProvider(create: (_) => ProjectManager()),
      ],
      child: MaterialApp(
        title: 'MIN MIN',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF7C5CBF),
            secondary: Color(0xFF9D7FD4),
            surface: Color(0xFF13131F),
            onSurface: Color(0xFFE2E8F0),
            onPrimary: Colors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFF0D0D1A),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF13131F),
            foregroundColor: Color(0xFFE2E8F0),
            elevation: 0,
          ),
          drawerTheme: const DrawerThemeData(
            backgroundColor: Color(0xFF13131F),
          ),
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: Color(0xFF1A1A2E),
            contentTextStyle: TextStyle(color: Color(0xFFE2E8F0)),
            behavior: SnackBarBehavior.floating,
          ),
          useMaterial3: true,
        ),
        home: const _Root(),
      ),
    );
  }
}

/// Routes to SetupScreen until model is loaded, then to ChatScreen.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    return Consumer<AiService>(
      builder: (_, ai, __) {
        if (ai.status == ModelStatus.loading) {
          return const _LoadingScreen();
        }
        if (ai.isReady) {
          return const ChatScreen();
        }
        return const SetupScreen();
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D0D1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF7C5CBF)),
            SizedBox(height: 24),
            Text(
              'Loading AI model…',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
            ),
            SizedBox(height: 8),
            Text(
              'This takes 10–30 seconds on first launch',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
