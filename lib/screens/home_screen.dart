import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/leads_provider.dart';
import '../theme.dart';
import 'map_screen.dart';
import 'list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _triggerDetected = false;
  bool _serviceRunning = false;
  StreamSubscription? _triggerSub;
  StreamSubscription? _leadSub;
  Timer? _triggerBannerTimer;

  final _pages = const [MapScreen(), ListScreen()];

  @override
  void initState() {
    super.initState();
    _setupServiceListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeadsProvider>().loadLeads();
    });
  }

  void _setupServiceListeners() {
    final service = FlutterBackgroundService();

    // Listen for trigger detection
    _triggerSub = service.on('trigger_detected').listen((_) {
      if (!mounted) return;
      setState(() => _triggerDetected = true);
      _triggerBannerTimer?.cancel();
      _triggerBannerTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _triggerDetected = false);
      });
    });

    // Listen for newly saved leads from background
    _leadSub = service.on('lead_saved').listen((data) {
      if (!mounted || data == null) return;
      context.read<LeadsProvider>().onLeadSavedFromBackground(data);
      // Show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.triggerGreen, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '✅ Lead saved: ${data['buildingType'] ?? data['notes'] ?? 'New location'}',
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.cardBg,
          duration: const Duration(seconds: 4),
        ),
      );
    });

    // Check if service is running
    service.isRunning().then((running) {
      if (mounted) setState(() => _serviceRunning = running);
    });
  }

  @override
  void dispose() {
    _triggerSub?.cancel();
    _leadSub?.cancel();
    _triggerBannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _pages[_currentIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.location_searching,
                color: AppTheme.accent, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Lead Tracker'),
        ],
      ),
      bottom: _triggerDetected
          ? PreferredSize(
              preferredSize: const Size.fromHeight(36),
              child: _triggerBanner(),
            )
          : null,
      actions: [
        // Voice service indicator
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _serviceRunning
                      ? AppTheme.triggerGreen
                      : AppTheme.recordingRed,
                  boxShadow: [
                    BoxShadow(
                      color: (_serviceRunning
                              ? AppTheme.triggerGreen
                              : AppTheme.recordingRed)
                          .withOpacity(0.5),
                      blurRadius: 4,
                      blurStyle: BlurStyle.outer,
                    ),
                  ],
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .fade(
                    begin: 1,
                    end: 0.4,
                    duration: 1200.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(width: 6),
              Text(
                _serviceRunning ? 'Active' : 'Off',
                style: TextStyle(
                  color: _serviceRunning
                      ? AppTheme.triggerGreen
                      : AppTheme.recordingRed,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: _showSettingsSheet,
        ),
      ],
    );
  }

  Widget _triggerBanner() {
    return Container(
      color: AppTheme.triggerGreen.withOpacity(0.15),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic, color: AppTheme.triggerGreen, size: 14)
              .animate(onPlay: (c) => c.repeat())
              .fade(begin: 1, end: 0.3, duration: 600.ms),
          const SizedBox(width: 6),
          const Text(
            'Trigger detected! Recording context…',
            style: TextStyle(
                color: AppTheme.triggerGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ).animate().slideY(begin: -0.5, end: 0, duration: 200.ms);
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (i) => setState(() => _currentIndex = i),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.map_outlined),
          activeIcon: Icon(Icons.map),
          label: 'Map',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list_outlined),
          activeIcon: Icon(Icons.list),
          label: 'Leads',
        ),
      ],
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SettingsSheet(serviceRunning: _serviceRunning),
    ).then((_) {
      FlutterBackgroundService().isRunning().then((running) {
        if (mounted) setState(() => _serviceRunning = running);
      });
    });
  }
}

class _SettingsSheet extends StatelessWidget {
  final bool serviceRunning;
  const _SettingsSheet({required this.serviceRunning});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Settings & Info',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _tile(
            icon: Icons.mic_outlined,
            title: 'Background Voice Service',
            subtitle: 'Listens for "Save Location" trigger phrase',
            trailing: Switch(
              value: serviceRunning,
              activeColor: AppTheme.accent,
              onChanged: (val) async {
                final service = FlutterBackgroundService();
                if (val) {
                  await service.startService();
                } else {
                  service.invoke('stop_service');
                }
                Navigator.pop(context);
              },
            ),
          ),
          const Divider(color: Colors.white10),
          _tile(
            icon: Icons.info_outline,
            title: 'How to use',
            subtitle: 'Say "Save Location" then speak building type, architect, phone number and notes',
          ),
          const Divider(color: Colors.white10),
          _tile(
            icon: Icons.map_outlined,
            title: 'Maps',
            subtitle: 'Using OpenStreetMap — works offline with cached tiles',
          ),
          const Divider(color: Colors.white10),
          _tile(
            icon: Icons.storage_outlined,
            title: 'Storage',
            subtitle: 'All data stored locally on device (SQLite). No cloud sync.',
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Lead Tracker v1.0  •  Offline-first',
              style: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.5), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accent, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
