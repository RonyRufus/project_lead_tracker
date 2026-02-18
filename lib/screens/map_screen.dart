import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/leads_provider.dart';
import '../models/project_lead.dart';
import '../theme.dart';
import '../widgets/voice_capture_dialog.dart';
import 'detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  LatLng _currentLatLng = const LatLng(-33.8688, 151.2093); // Default: Sydney
  bool _locationReady = false;
  bool _followUser = true;
  ProjectLead? _selectedLead;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  Future<void> _startTracking() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      setState(() {
        _currentLatLng = LatLng(pos.latitude, pos.longitude);
        _locationReady = true;
      });
      if (_followUser) {
        _mapController.move(_currentLatLng, 16);
      }
    } catch (_) {}

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() => _currentLatLng = LatLng(pos.latitude, pos.longitude));
      if (_followUser && mounted) {
        _mapController.move(_currentLatLng, _mapController.camera.zoom);
      }
    });
  }

  Future<void> _openManualSave() async {
    final result = await showDialog<ProjectLead>(
      context: context,
      builder: (_) => const VoiceCaptureDialog(voiceMode: false),
    );
    if (result != null && mounted) {
      await context.read<LeadsProvider>().addLead(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Lead "${result.title}" saved!'),
          backgroundColor: AppTheme.triggerGreen.withOpacity(0.9),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final leads = context.watch<LeadsProvider>().leads;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLatLng,
              initialZoom: 14,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && _followUser) {
                  setState(() => _followUser = false);
                }
              },
              onTap: (_, __) => setState(() => _selectedLead = null),
            ),
            children: [
              // OpenStreetMap tile layer
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.leadtracker.app',
                maxZoom: 19,
              ),
              // Lead markers
              MarkerLayer(
                markers: [
                  // Current position
                  if (_locationReady)
                    Marker(
                      point: _currentLatLng,
                      width: 20,
                      height: 20,
                      child: _currentLocationDot(),
                    ),
                  // Lead markers
                  ...leads.map((lead) {
                    final isSelected = _selectedLead?.id == lead.id;
                    return Marker(
                      point: LatLng(lead.latitude, lead.longitude),
                      width: isSelected ? 44 : 36,
                      height: isSelected ? 44 : 36,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedLead = lead);
                          _mapController.move(
                            LatLng(lead.latitude, lead.longitude),
                            _mapController.camera.zoom < 15
                                ? 15
                                : _mapController.camera.zoom,
                          );
                        },
                        child: _leadMarker(lead, isSelected),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // Attribution
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.75),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontSize: 9, color: Colors.black54),
              ),
            ),
          ),

          // Selected lead popup
          if (_selectedLead != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 90,
              child: _leadPopup(_selectedLead!),
            ),

          // Top-right controls
          Positioned(
            top: 60,
            right: 12,
            child: _mapControls(),
          ),

          // GPS status
          if (!_locationReady)
            Positioned(
              top: 60,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.accent,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('Getting GPS fix…',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'manual_save',
            onPressed: _openManualSave,
            backgroundColor: AppTheme.primary,
            icon: const Icon(Icons.add_location_alt, color: Colors.white),
            label: const Text('Save Location',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _currentLocationDot() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
              color: Colors.blue, blurRadius: 8, spreadRadius: 2, blurStyle: BlurStyle.outer)
        ],
      ),
    );
  }

  Widget _leadMarker(ProjectLead lead, bool selected) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppTheme.triggerGreen : AppTheme.markerColor,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: (selected ? AppTheme.triggerGreen : AppTheme.markerColor)
                .withOpacity(0.5),
            blurRadius: 6,
            spreadRadius: 1,
            blurStyle: BlurStyle.outer,
          )
        ],
      ),
      child: Icon(
        lead.isManual ? Icons.push_pin : Icons.mic,
        color: Colors.white,
        size: selected ? 20 : 16,
      ),
    );
  }

  Widget _leadPopup(ProjectLead lead) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(lead: lead)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                lead.isManual ? Icons.push_pin : Icons.mic,
                color: AppTheme.accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lead.title,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(lead.subtitle,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  Text(lead.formattedDate,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _mapControls() {
    return Column(
      children: [
        _controlBtn(
          Icons.add,
          () {
            _mapController.move(
                _mapController.camera.center, _mapController.camera.zoom + 1);
          },
        ),
        const SizedBox(height: 4),
        _controlBtn(
          Icons.remove,
          () {
            _mapController.move(
                _mapController.camera.center, _mapController.camera.zoom - 1);
          },
        ),
        const SizedBox(height: 8),
        _controlBtn(
          _followUser ? Icons.gps_fixed : Icons.gps_not_fixed,
          () {
            setState(() => _followUser = true);
            _mapController.move(_currentLatLng, 16);
          },
          color: _followUser ? AppTheme.accent : AppTheme.textSecondary,
        ),
      ],
    );
  }

  Widget _controlBtn(IconData icon, VoidCallback onTap,
      {Color color = AppTheme.textSecondary}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
