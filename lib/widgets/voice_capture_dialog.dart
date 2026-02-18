import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_animate/flutter_animate.dart';
import '../theme.dart';
import '../services/speech_parser.dart';
import '../models/project_lead.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';

class VoiceCaptureDialog extends StatefulWidget {
  final bool voiceMode; // true = voice capture; false = manual form
  const VoiceCaptureDialog({super.key, this.voiceMode = false});

  @override
  State<VoiceCaptureDialog> createState() => _VoiceCaptureDialogState();
}

class _VoiceCaptureDialogState extends State<VoiceCaptureDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _buildingTypeCtrl = TextEditingController();
  final _architectCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Speech
  final _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isVoiceMode = false;
  String _liveTranscript = '';
  String _statusText = '';
  Timer? _autoStopTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _isVoiceMode = widget.voiceMode;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _initSpeech();
    if (widget.voiceMode) {
      Future.delayed(const Duration(milliseconds: 500), _startListening);
    }
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) {
        setState(() => _statusText = 'Error: ${e.errorMsg}');
        _isListening = false;
      },
    );
    setState(() {});
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) return;
    setState(() {
      _isListening = true;
      _liveTranscript = '';
      _statusText = 'Listening…';
    });

    _speech.listen(
      onResult: (result) {
        setState(() => _liveTranscript = result.recognizedWords);
        if (result.finalResult) {
          _stopListening();
          _applyTranscript(_liveTranscript);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      cancelOnError: true,
      partialResults: true,
    );

    _autoStopTimer = Timer(const Duration(seconds: 30), _stopListening);
  }

  void _stopListening() {
    _speech.stop();
    _autoStopTimer?.cancel();
    setState(() {
      _isListening = false;
      _statusText = _liveTranscript.isNotEmpty
          ? 'Transcript captured. Review & save.'
          : 'No speech detected.';
    });
  }

  void _applyTranscript(String transcript) {
    final parsed = SpeechParser.parse(transcript);
    _buildingTypeCtrl.text = parsed['buildingType'] ?? '';
    _architectCtrl.text = parsed['architectName'] ?? '';
    _phoneCtrl.text = parsed['phoneNumber'] ?? '';
    _companyCtrl.text = parsed['companyName'] ?? '';
    _notesCtrl.text = parsed['notes'] ?? '';
    setState(() {
      _isVoiceMode = false; // Switch to form to review
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (_) {}

    if (pos == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get GPS location.')),
      );
      return;
    }

    final lead = ProjectLead(
      id: const Uuid().v4(),
      latitude: pos!.latitude,
      longitude: pos.longitude,
      timestamp: DateTime.now(),
      rawTranscript: _liveTranscript,
      buildingType: _buildingTypeCtrl.text.trim(),
      architectName: _architectCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      companyName: _companyCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      isManual: !widget.voiceMode,
    );

    if (mounted) Navigator.of(context).pop(lead);
  }

  @override
  void dispose() {
    _speech.stop();
    _autoStopTimer?.cancel();
    _pulseController.dispose();
    _buildingTypeCtrl.dispose();
    _architectCtrl.dispose();
    _phoneCtrl.dispose();
    _companyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            if (_isVoiceMode) _buildVoiceSection() else _buildForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _isVoiceMode ? Icons.mic : Icons.add_location_alt,
            color: AppTheme.accent,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.voiceMode ? 'Voice Lead Capture' : 'Save Location',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                widget.voiceMode
                    ? 'Speak your notes – they\'ll be structured automatically'
                    : 'Fill in details for this location',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildVoiceSection() {
    return Column(
      children: [
        // Pulse animation for mic
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, __) => Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (_isListening ? AppTheme.recordingRed : AppTheme.primary)
                  .withOpacity(0.1 + 0.1 * _pulseController.value),
              border: Border.all(
                color: _isListening
                    ? AppTheme.recordingRed
                    : AppTheme.primary,
                width: 2,
              ),
            ),
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_off,
              color: _isListening
                  ? AppTheme.recordingRed
                  : AppTheme.textSecondary,
              size: 40,
            ),
          ),
        ).animate().scale(duration: 300.ms),
        const SizedBox(height: 16),
        Text(
          _statusText.isEmpty ? 'Tap mic to start recording' : _statusText,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        if (_liveTranscript.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '"$_liveTranscript"',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isListening ? _stopListening : _startListening,
                icon: Icon(_isListening ? Icons.stop : Icons.mic),
                label: Text(_isListening ? 'Stop' : 'Start'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _isListening
                      ? AppTheme.recordingRed
                      : AppTheme.accent,
                  side: BorderSide(
                    color: _isListening
                        ? AppTheme.recordingRed
                        : AppTheme.accent,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_liveTranscript.isNotEmpty) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _applyTranscript(_liveTranscript),
                  icon: const Icon(Icons.check),
                  label: const Text('Review'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _isVoiceMode = false),
          child: const Text(
            'Switch to Manual Form',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_liveTranscript.isNotEmpty)
            _rawTranscriptChip(),
          _field(
            controller: _buildingTypeCtrl,
            label: 'Building Type',
            icon: Icons.business,
            hint: 'e.g. Residential, Commercial…',
          ),
          _field(
            controller: _architectCtrl,
            label: 'Architect / Contact Name',
            icon: Icons.person_outline,
          ),
          _field(
            controller: _phoneCtrl,
            label: 'Phone Number',
            icon: Icons.phone_outlined,
            keyboard: TextInputType.phone,
          ),
          _field(
            controller: _companyCtrl,
            label: 'Company / Builder',
            icon: Icons.domain_outlined,
          ),
          _field(
            controller: _notesCtrl,
            label: 'Notes',
            icon: Icons.notes_outlined,
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (widget.voiceMode)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _isVoiceMode = true;
                      _liveTranscript = '';
                      _buildingTypeCtrl.clear();
                      _architectCtrl.clear();
                      _phoneCtrl.clear();
                      _companyCtrl.clear();
                      _notesCtrl.clear();
                      Future.delayed(
                          const Duration(milliseconds: 200), _startListening);
                    }),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Re-record'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              if (widget.voiceMode) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Save Lead'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.triggerGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rawTranscriptChip() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.record_voice_over,
              size: 14, color: AppTheme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _liveTranscript,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 18),
        ),
      ),
    );
  }
}
