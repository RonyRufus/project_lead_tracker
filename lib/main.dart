import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/leads_provider.dart';
import 'services/background_voice_service.dart';
import 'screens/home_screen.dart';
import 'screens/permissions_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(
    ChangeNotifierProvider(
      create: (_) => LeadsProvider(),
      child: const LeadTrackerApp(),
    ),
  );
}

class LeadTrackerApp extends StatelessWidget {
  const LeadTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lead Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _Entrypoint(),
    );
  }
}

class _Entrypoint extends StatefulWidget {
  const _Entrypoint();

  @override
  State<_Entrypoint> createState() => _EntrypointState();
}

class _EntrypointState extends State<_Entrypoint> {
  bool _permsDone = false;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('perms_done') ?? false;
    if (done && mounted) {
      setState(() => _permsDone = true);
    }
  }

  Future<void> _onPermissionsGranted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('perms_done', true);
    // Start background service
    await initBackgroundService();
    if (mounted) setState(() => _permsDone = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_permsDone) return const HomeScreen();
    return PermissionsScreen(onGranted: _onPermissionsGranted);
  }
}
