import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_listen_options.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/project_lead.dart';
import 'speech_parser.dart';

const String kTriggerPhrase = 'save location';
const int kNotificationId = 888;
const String kChannelId = 'lead_tracker_service';
const String kChannelName = 'Lead Tracker Background';
const String kPorcupineAccessKey =
    String.fromEnvironment('PORCUPINE_ACCESS_KEY', defaultValue: '');
const String kPorcupineKeywordPath =
    String.fromEnvironment('PORCUPINE_KEYWORD_PATH', defaultValue: '');

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
      .createNotificationChannel(channel);

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

  final speech = stt.SpeechToText();
  final recorder = AudioRecorder();

  bool listeningForTrigger = false;
  bool capturingContext = false;
  String contextBuffer = '';
  int contextRestartCount = 0;
  PorcupineManager? porcupineManager;

  late void Function() startTriggerListening;
  late void Function() startContextListening;

  final speechAvailable = await speech.initialize(
    onError: (e) => debugPrint('STT error: $e'),
    onStatus: (status) {
      if (capturingContext &&
          (status == stt.SpeechToText.doneStatus ||
              status == stt.SpeechToText.notListeningStatus)) {
        Timer(const Duration(milliseconds: 400), startContextListening);
      }
    },
  );

  if (!speechAvailable) {
    service.invoke('status', {'message': 'Speech recognition unavailable'});
    return;
  }

  void updateNotification(String content) {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Lead Tracker Active',
        content: content,
      );
    }
  }

  Future<void> stopRecorderIfNeeded() async {
    if (await recorder.isRecording()) {
      await recorder.stop();
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
      final db = await openDatabase(p.join(dbPath, 'project_leads.db'));
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

  startContextListening = () {
    if (capturingContext) return;
    capturingContext = true;
    contextBuffer = '';
    contextRestartCount = 0;
    updateNotification('🎙 Recording context… speak now');

    () async {
      try {
        final Directory tempDir = await getTemporaryDirectory();
        final recordingPath = p.join(
          tempDir.path,
          'context_${DateTime.now().millisecondsSinceEpoch}.wav',
        );
        await recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            bitRate: 128000,
            numChannels: 1,
          ),
          path: recordingPath,
        );
      } catch (e) {
        debugPrint('Recorder start failed: $e');
      }
    }();

    void listenLoop() {
      if (!capturingContext) return;
      speech.listen(
        onResult: (result) {
          contextBuffer = result.recognizedWords;
          if (result.finalResult) {
            contextRestartCount++;
            if (contextRestartCount >= 2 || contextBuffer.length > 50) {
              capturingContext = false;
              final transcript = contextBuffer.trim();
              contextBuffer = '';
              contextRestartCount = 0;
              () async {
                await stopRecorderIfNeeded();
                if (transcript.isNotEmpty) {
                  await saveLeadFromContext(transcript);
                }
                startTriggerListening();
              }();
            } else {
              Timer(const Duration(milliseconds: 500), () {
                if (capturingContext) listenLoop();
              });
            }
          }
        },
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          cancelOnError: false,
          partialResults: true,
        ),
      );
    }

    listenLoop();

    Timer(const Duration(seconds: 20), () {
      if (capturingContext) {
        capturingContext = false;
        final transcript = contextBuffer.trim();
        contextBuffer = '';
        () async {
          await stopRecorderIfNeeded();
          if (transcript.isNotEmpty) {
            await saveLeadFromContext(transcript);
          }
          startTriggerListening();
        }();
      }
    });
  };

  startTriggerListening = () {
    if (listeningForTrigger) return;
    listeningForTrigger = true;
    updateNotification('👂 Listening for "Save Location"…');

    final keywordPaths =
        kPorcupineKeywordPath.isEmpty ? <String>[] : [kPorcupineKeywordPath];

    if (kPorcupineAccessKey.isNotEmpty && keywordPaths.isNotEmpty) {
      () async {
        try {
          porcupineManager ??= await PorcupineManager.fromKeywordPaths(
            kPorcupineAccessKey,
            keywordPaths,
            (int keywordIndex) {
              if (!listeningForTrigger) return;
              listeningForTrigger = false;
              updateNotification('🎯 Trigger detected! Speak your notes…');
              service.invoke('trigger_detected', {'keywordIndex': keywordIndex});
              startContextListening();
            },
            sensitivities: [0.6],
          );
          await porcupineManager?.start();
        } catch (e) {
          debugPrint('Porcupine start failed: $e');
        }
      }();
      return;
    }

    void listenLoop() {
      if (!listeningForTrigger) return;
      speech.listen(
        onResult: (result) {
          final text = result.recognizedWords.toLowerCase();
          if (text.contains(kTriggerPhrase)) {
            listeningForTrigger = false;
            speech.stop();
            updateNotification('🎯 Trigger detected! Speak your notes…');
            service.invoke('trigger_detected', {});
            Timer(const Duration(milliseconds: 300), () {
              startContextListening();
            });
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          cancelOnError: false,
          partialResults: true,
        ),
      );
    }

    listenLoop();
  };

  service.on('start_manual_context').listen((_) async {
    listeningForTrigger = false;
    await porcupineManager?.stop();
    await speech.stop();
    startContextListening();
  });

  service.on('stop_service').listen((_) async {
    listeningForTrigger = false;
    capturingContext = false;
    await porcupineManager?.stop();
    await porcupineManager?.delete();
    await speech.stop();
    await stopRecorderIfNeeded();
    service.stopSelf();
  });

  startTriggerListening();
}
