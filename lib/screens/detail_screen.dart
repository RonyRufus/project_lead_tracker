import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/project_lead.dart';
import '../providers/leads_provider.dart';
import '../theme.dart';

class DetailScreen extends StatefulWidget {
  final ProjectLead lead;
  const DetailScreen({super.key, required this.lead});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late ProjectLead _lead;
  bool _editing = false;

  // Edit controllers
  late final TextEditingController _buildingTypeCtrl;
  late final TextEditingController _architectCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _companyCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _addressCtrl;

  @override
  void initState() {
    super.initState();
    _lead = widget.lead;
    _initControllers();
  }

  void _initControllers() {
    _buildingTypeCtrl = TextEditingController(text: _lead.buildingType);
    _architectCtrl = TextEditingController(text: _lead.architectName);
    _phoneCtrl = TextEditingController(text: _lead.phoneNumber);
    _companyCtrl = TextEditingController(text: _lead.companyName);
    _notesCtrl = TextEditingController(text: _lead.notes);
    _addressCtrl = TextEditingController(text: _lead.address);
  }

  @override
  void dispose() {
    _buildingTypeCtrl.dispose();
    _architectCtrl.dispose();
    _phoneCtrl.dispose();
    _companyCtrl.dispose();
    _notesCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveEdits() async {
    final updated = _lead.copyWith(
      buildingType: _buildingTypeCtrl.text.trim(),
      architectName: _architectCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      companyName: _companyCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
    );
    await context.read<LeadsProvider>().updateLead(updated);
    setState(() {
      _lead = updated;
      _editing = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Lead updated.')));
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Delete Lead',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.recordingRed)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<LeadsProvider>().deleteLead(_lead.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_lead.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (_editing)
            TextButton(
              onPressed: _saveEdits,
              child: const Text('Save',
                  style: TextStyle(
                      color: AppTheme.triggerGreen, fontWeight: FontWeight.bold)),
            )
          else
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppTheme.accent),
              onPressed: () => setState(() => _editing = true),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.recordingRed),
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Mini map
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 180,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(_lead.latitude, _lead.longitude),
                  initialZoom: 16,
                  interactionOptions:
                      const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.leadtracker.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_lead.latitude, _lead.longitude),
                        width: 36,
                        height: 36,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.markerColor,
                            border:
                                Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.markerColor.withOpacity(0.6),
                                blurRadius: 8,
                                blurStyle: BlurStyle.outer,
                              )
                            ],
                          ),
                          child: const Icon(Icons.location_pin,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Date & coordinates
          _infoCard(children: [
            _infoRow(Icons.schedule, 'Date & Time', _lead.formattedDate),
            const Divider(color: Colors.white10, height: 1),
            _infoRow(Icons.my_location, 'Coordinates', _lead.coordsString,
                copyable: true),
            if (_lead.address.isNotEmpty) ...[
              const Divider(color: Colors.white10, height: 1),
              _editing
                  ? _editField(_addressCtrl, 'Address', Icons.location_city)
                  : _infoRow(Icons.location_city, 'Address', _lead.address),
            ],
            _infoRow(
                _lead.isManual ? Icons.push_pin_outlined : Icons.mic_none,
                'Method',
                _lead.isManual ? 'Manual save' : 'Voice trigger'),
          ]),

          const SizedBox(height: 12),

          // Lead details
          _sectionHeader('Lead Details'),
          _infoCard(children: [
            _editing
                ? _editField(_buildingTypeCtrl, 'Building Type', Icons.business)
                : _infoRow(Icons.business, 'Building Type',
                    _lead.buildingType.isEmpty ? '—' : _lead.buildingType),
            const Divider(color: Colors.white10, height: 1),
            _editing
                ? _editField(_architectCtrl, 'Architect / Contact', Icons.person_outline)
                : _infoRow(Icons.person_outline, 'Architect / Contact',
                    _lead.architectName.isEmpty ? '—' : _lead.architectName),
            const Divider(color: Colors.white10, height: 1),
            _editing
                ? _editField(_phoneCtrl, 'Phone Number', Icons.phone_outlined,
                    keyboard: TextInputType.phone)
                : _infoRow(Icons.phone_outlined, 'Phone Number',
                    _lead.phoneNumber.isEmpty ? '—' : _lead.phoneNumber,
                    copyable: true),
            const Divider(color: Colors.white10, height: 1),
            _editing
                ? _editField(_companyCtrl, 'Company', Icons.domain_outlined)
                : _infoRow(Icons.domain_outlined, 'Company',
                    _lead.companyName.isEmpty ? '—' : _lead.companyName),
          ]),

          const SizedBox(height: 12),

          // Notes
          _sectionHeader('Notes'),
          _infoCard(children: [
            _editing
                ? _editField(_notesCtrl, 'Notes', Icons.notes_outlined,
                    maxLines: 4)
                : Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      _lead.notes.isEmpty
                          ? 'No notes recorded.'
                          : _lead.notes,
                      style: TextStyle(
                        color: _lead.notes.isEmpty
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                        fontSize: 14,
                        fontStyle: _lead.notes.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
          ]),

          // Raw transcript
          if (_lead.rawTranscript.isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionHeader('Raw Transcript'),
            _infoCard(children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  '"${_lead.rawTranscript}"',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ),
            ]),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _infoCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(children: children),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 14)),
              ],
            ),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Copied: $value')),
                );
              },
              child: const Icon(Icons.copy_outlined,
                  size: 15, color: AppTheme.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _editField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 16),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}
