import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml/whisper_ggml.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/project_lead.dart';
import 'speech_parser.dart';

const int kNotificationId = 888;
const String kChannelId = 'lead_tracker_service';
const String kChannelName = 'Lead Tracker Background';

// Picovoice access key for wake word detection.
const String kPicovoiceAccessKey = 'ed5W7sSGFJVOmpltPcXW06167GJEU1taIGLczQeNKz2yCC+mvF7PpA==';
// Path inside assets where you place the Porcupine keyword file.
const String kKeywordAssetPath = 'assets/porcupine/location_en_android_v4_0_0.ppn';

Future<void> initBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    kChannelId,
    kChannelName,
    description: 'Listening for "Save Location" trigger',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onServiceStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: kChannelId,
      initialNotificationTitle: 'Lead Tracker Active',
      initialNotificationContent: 'Listening for "Save Location"…',
      foregroundServiceNotificationId: kNotificationId,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onServiceStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();
  await notifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  final audioRecorder = Record();
  final whisperController = WhisperController();
  PorcupineManager? porcupineManager;

  void updateNotification(String content) {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Lead Tracker Active',
        content: content,
      );
    }
  }

  Future<void> saveLeadFromContext(String transcript) async {
    try {
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (_) {}

      if (pos == null) return;

      final parsed = SpeechParser.parse(transcript);
      final lead = ProjectLead(
        id: const Uuid().v4(),
        latitude: pos.latitude,
        longitude: pos.longitude,
        timestamp: DateTime.now(),
        rawTranscript: transcript,
        buildingType: parsed['buildingType'] ?? '',
        architectName: parsed['architectName'] ?? '',
        phoneNumber: parsed['phoneNumber'] ?? '',
        companyName: parsed['companyName'] ?? '',
        notes: parsed['notes'] ?? '',
        isManual: false,
      );

      final dbPath = await getDatabasesPath();
      final db =
          await openDatabase(p.join(dbPath, 'project_leads.db'));
      await db.insert('leads', lead.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await db.close();

      service.invoke('lead_saved', lead.toMap());

      await notifications.show(
        kNotificationId + 1,
        '✅ Lead Saved!',
        '${lead.title} – ${lead.formattedDate}',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            kChannelId,
            kChannelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error saving lead: $e');
    }
  }

  Future<void> transcribeWithWhisper(String audioPath) async {
    try {
      updateNotification('🧠 Transcribing notes…');
      final result = await whisperController.transcribe(
        model: WhisperModel.tinyEn,
        audioPath: audioPath,
        lang: 'en',
      );
      final transcript = result?.transcription.text?.trim() ?? '';
      if (transcript.isNotEmpty) {
        await saveLeadFromContext(transcript);
      }
      updateNotification('👂 Listening for "Save Location"…');
    } catch (e) {
      debugPrint('Whisper transcription error: $e');
      updateNotification('⚠️ Error transcribing notes');
    }
  }

  Future<void> startContextRecording() async {
    try {
      if (!await audioRecorder.hasPermission()) {
        updateNotification('⚠️ Mic permission missing');
        return;
      }

      if (await audioRecorder.isRecording()) {
        await audioRecorder.stop();
      }

      final dir = await getTemporaryDirectory();
      final filePath = p.join(dir.path, 'lead_context_${DateTime.now().millisecondsSinceEpoch}.wav');

      updateNotification('🎙 Recording context… speak now');

      await audioRecorder.start(
        path: filePath,
        encoder: AudioEncoder.wav,
        bitRate: 128000,
        samplingRate: 16000,
      );

      Timer(const Duration(seconds: 15), () async {
        final path = await audioRecorder.stop();
        if (path != null) {
          await transcribeWithWhisper(path);
        } else {
          updateNotification('👂 Listening for "Save Location"…');
        }
      });
    } catch (e) {
      debugPrint('Recording error: $e');
      updateNotification('⚠️ Error recording notes');
    }
  }

  porcupineManager = await PorcupineManager.fromKeywordPaths(
    accessKey: kPicovoiceAccessKey,
    keywordPaths: [kKeywordAssetPath],
    sensitivities: [0.6],
    onKeywordDetected: (index) async {
      updateNotification('🎯 Trigger detected! Recording notes…');
      service.invoke('trigger_detected', {});
      await startContextRecording();
    },
  );

  await porcupineManager.start();

  service.on('start_manual_context').listen((_) async {
    updateNotification('🎙 Manual recording… speak now');
    await startContextRecording();
  });

  service.on('stop_service').listen((_) async {
    await audioRecorder.stop();
    await porcupineManager?.stop();
    service.stopSelf();
  });
}
