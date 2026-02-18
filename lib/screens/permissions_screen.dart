import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme.dart';

class PermissionsScreen extends StatefulWidget {
  final VoidCallback onGranted;
  const PermissionsScreen({super.key, required this.onGranted});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _locationGranted = false;
  bool _micGranted = false;
  bool _notifGranted = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() => _checking = true);
    _locationGranted = await Permission.locationWhenInUse.isGranted;
    _micGranted = await Permission.microphone.isGranted;
    _notifGranted = await Permission.notification.isGranted;
    setState(() => _checking = false);
  }

  bool get _allGranted =>
      _locationGranted && _micGranted && _notifGranted;

  Future<void> _requestAll() async {
    setState(() => _checking = true);

    // Location
    final locStatus = await Permission.locationWhenInUse.request();
    _locationGranted = locStatus.isGranted;

    // Background location (Android 10+)
    if (_locationGranted) {
      await Permission.locationAlways.request();
    }

    // Microphone
    final micStatus = await Permission.microphone.request();
    _micGranted = micStatus.isGranted;

    // Notifications (Android 13+)
    final notifStatus = await Permission.notification.request();
    _notifGranted = notifStatus.isGranted;

    setState(() => _checking = false);

    if (_allGranted) widget.onGranted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.location_searching,
                    color: AppTheme.accent, size: 40),
              ),
              const SizedBox(height: 24),
              const Text(
                'Lead Tracker\nneeds a few permissions',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'These allow the app to track your GPS location, listen for the "Save Location" voice trigger in the background, and send you notifications when a lead is saved.',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 36),
              _permRow(
                icon: Icons.location_on_outlined,
                title: 'Location',
                subtitle: 'Precise GPS for lead coordinates',
                granted: _locationGranted,
              ),
              const SizedBox(height: 16),
              _permRow(
                icon: Icons.mic_outlined,
                title: 'Microphone',
                subtitle: 'Voice trigger & speech-to-text capture',
                granted: _micGranted,
              ),
              const SizedBox(height: 16),
              _permRow(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Alert you when a lead is saved',
                granted: _notifGranted,
              ),
              const Spacer(),
              if (_checking)
                const Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
                )
              else ...[
                if (!_allGranted)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _requestAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Grant Permissions',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                if (_allGranted)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onGranted,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.triggerGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '✅ All set — Continue',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                if (!_allGranted) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: widget.onGranted,
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool granted,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.accent, size: 20),
        ),
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
        Icon(
          granted ? Icons.check_circle : Icons.radio_button_unchecked,
          color: granted ? AppTheme.triggerGreen : AppTheme.textSecondary,
          size: 22,
        ),
      ],
    );
  }
}
