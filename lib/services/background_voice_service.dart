import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_listen_options.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/project_lead.dart';
import 'speech_parser.dart';

const String kTriggerPhrase = 'save location';
const int kNotificationId = 888;
const String kChannelId = 'lead_tracker_service';
const String kChannelName = 'Lead Tracker Background';

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

  final speech = stt.SpeechToText();
  final speechAvailable = await speech.initialize(
    onError: (e) => debugPrint('STT error: $e'),
    onStatus: (s) => debugPrint('STT status: $s'),
  );

  if (!speechAvailable) {
    service.invoke('status', {'message': 'Speech recognition unavailable'});
    return;
  }

  bool listeningForTrigger = false;
  bool capturingContext = false;
  String contextBuffer = '';
  int contextRestartCount = 0;

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

  // Forward-declare as late so they can reference each other
  late void Function() startTriggerListening;
  late void Function() startContextListening;

  startContextListening = () {
    if (capturingContext) return;
    capturingContext = true;
    contextBuffer = '';
    contextRestartCount = 0;
    updateNotification('🎙 Recording context… speak now');

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
              if (transcript.isNotEmpty) {
                saveLeadFromContext(transcript);
              }
              startTriggerListening();
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
        if (transcript.isNotEmpty) {
          saveLeadFromContext(transcript);
        }
        startTriggerListening();
      }
    });
  };

  startTriggerListening = () {
    if (listeningForTrigger) return;
    listeningForTrigger = true;
    updateNotification('👂 Listening for "Save Location"…');

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

    speech.statusListener = (status) {
      if (listeningForTrigger &&
          (status == stt.SpeechToText.doneStatus ||
              status == stt.SpeechToText.notListeningStatus)) {
        Timer(const Duration(seconds: 1), listenLoop);
      }
    };
  };

  service.on('start_manual_context').listen((_) async {
    listeningForTrigger = false;
    await speech.stop();
    startContextListening();
  });

  service.on('stop_service').listen((_) async {
    listeningForTrigger = false;
    capturingContext = false;
    await speech.stop();
    service.stopSelf();
  });

  startTriggerListening();
}
