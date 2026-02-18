# 📍 Lead Tracker — Flutter App

A native Android app for field workers to **capture project leads by voice while driving**, with live GPS tracking on OpenStreetMap, full offline storage, and CSV export for Excel.

---

## ✨ Features

| Feature | Details |
|---|---|
| 🗺️ Live GPS Map | OpenStreetMap (no Google Maps required), real-time position dot |
| 🎙️ Voice Trigger | Say **"Save Location"** — the background service detects only this phrase |
| 📝 Auto-structured Notes | Speech is parsed into: Building Type, Architect/Contact, Phone Number, Company, Notes |
| 📌 Map Markers | Every saved lead appears as a tappable pin on the map |
| 🔍 Searchable List | Full-text search across all fields |
| ✏️ Edit Leads | Open any lead to view/edit all fields, copy coordinates/phone |
| 💾 Manual Save | Button to save current location with a manual form |
| 📤 CSV Export | Share/download a properly formatted Excel-compatible CSV |
| 🔋 Offline-First | SQLite storage, OSM cached tiles — no internet required after setup |
| 🔒 Screen-lock Safe | Foreground service keeps the voice trigger running with screen off |

---

## 🛠️ Setup & Installation

### Prerequisites
- Flutter SDK 3.x (≥ 3.10)
- Android Studio or VS Code with Flutter extension
- Android device or emulator (API 21+)

### Steps

```bash
# 1. Clone / copy the project
cd project_lead_tracker

# 2. Install dependencies
flutter pub get

# 3. Connect Android device (with USB debugging enabled)
flutter devices

# 4. Run in debug mode
flutter run

# 5. Build release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## 🎙️ Voice Trigger — How it Works

```
┌─────────────────────────────────────────────────────────┐
│  FOREGROUND SERVICE (runs with screen locked)            │
│                                                          │
│  Phase 1: TRIGGER DETECTION                              │
│  ┌──────────────────────────────────────────────┐       │
│  │  Continuous mic listening                    │       │
│  │  Waiting for: "Save Location"               │       │
│  │  ✓ Ignores all other speech                  │       │
│  └──────────────┬───────────────────────────────┘       │
│                 │ Trigger detected!                       │
│                 ▼                                         │
│  Phase 2: CONTEXT RECORDING                              │
│  ┌──────────────────────────────────────────────┐       │
│  │  Records your spoken notes (up to 20 sec)   │       │
│  │  e.g. "Commercial building, John Smith,     │       │
│  │         0412 345 678, BuildCorp, new site"  │       │
│  └──────────────┬───────────────────────────────┘       │
│                 │ Auto-parses transcript                  │
│                 ▼                                         │
│  Phase 3: SAVE                                           │
│  ┌──────────────────────────────────────────────┐       │
│  │  Captures GPS, saves to SQLite               │       │
│  │  Shows notification: "✅ Lead Saved!"        │       │
│  └──────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────┘
```

### Example voice captures

| You say | Parsed result |
|---|---|
| `"Commercial building, architect Jane Doe, 0400 123 456, ABC Constructions"` | Building: Commercial · Architect: Jane Doe · Phone: 0400 123 456 · Company: ABC Constructions |
| `"Residential house, John Smith, 02 9000 1234, notes: front fence being built"` | Building: Residential House · Contact: John Smith · Phone: 02 9000 1234 · Notes: front fence being built |
| `"Retail, Smith & Jones, 0412 999 888, mixed use development"` | Building: Retail · Contact: Smith & Jones · Phone: 0412 999 888 · Notes: mixed use development |

---

## 📁 Project Structure

```
lib/
├── main.dart                        # App entry point
├── theme.dart                       # Dark navy design theme
├── models/
│   └── project_lead.dart            # Data model + CSV serialisation
├── services/
│   ├── background_voice_service.dart # Foreground service + STT loop
│   ├── database_service.dart         # SQLite CRUD operations
│   ├── location_service.dart         # GPS streaming
│   ├── speech_parser.dart            # Transcript → structured fields
│   └── export_service.dart           # CSV generation + sharing
├── providers/
│   └── leads_provider.dart           # State management (ChangeNotifier)
├── screens/
│   ├── permissions_screen.dart       # First-launch permission flow
│   ├── home_screen.dart              # Shell + bottom nav + service status
│   ├── map_screen.dart               # OpenStreetMap + markers
│   ├── list_screen.dart              # Searchable list + export
│   └── detail_screen.dart            # View/edit individual lead
└── widgets/
    └── voice_capture_dialog.dart     # Voice + manual save dialog
android/
├── app/
│   ├── build.gradle
│   └── src/main/
│       ├── AndroidManifest.xml       # All permissions + foreground service types
│       └── kotlin/.../MainActivity.kt
└── build.gradle
```

---

## 📋 CSV Export Format

The exported CSV is fully Excel-compatible with these columns:

| ID | Date/Time | Latitude | Longitude | Building Type | Architect/Contact | Phone | Company | Notes | Address | Raw Transcript | Entry Method |

---

## 🔐 Permissions Required

| Permission | Why |
|---|---|
| `ACCESS_FINE_LOCATION` | Precise GPS coordinates for leads |
| `ACCESS_BACKGROUND_LOCATION` | GPS access when app is backgrounded |
| `RECORD_AUDIO` | Voice trigger and speech capture |
| `FOREGROUND_SERVICE` | Keep voice service running with screen off |
| `FOREGROUND_SERVICE_MICROPHONE` | Android 14+ microphone foreground type |
| `FOREGROUND_SERVICE_LOCATION` | Android 14+ location foreground type |
| `POST_NOTIFICATIONS` | "Lead saved" confirmation notifications |

---

## 🗺️ Offline Maps

The app uses **OpenStreetMap tiles** via `flutter_map`. Tiles are cached after first load. For fully offline use, pre-cache your working region by panning the map while online.

---

## ⚡ Key Dependencies

| Package | Purpose |
|---|---|
| `flutter_map` | OSM map rendering |
| `geolocator` | GPS streaming |
| `speech_to_text` | On-device STT |
| `flutter_background_service` | Foreground service / background listening |
| `sqflite` | Local SQLite storage |
| `csv` + `share_plus` | Export & share CSV |
| `flutter_animate` | UI animations |
| `provider` | State management |

---

## 🐛 Troubleshooting

**Voice trigger not working with screen off:**
- Ensure "Battery Optimisation" is disabled for this app in Android settings
- Check that the foreground service is shown as "Active" (green dot) in the app bar

**GPS not getting fix:**
- Open app outdoors or near a window
- Check location permission is set to "Allow all the time"

**Speech not recognised:**
- Speak clearly after the beep/notification
- Ensure microphone permission is granted

**Background service stops:**
- Disable battery saver for this app
- Some OEM launchers (Xiaomi, Samsung, Huawei) kill background apps aggressively — add app to "Protected Apps" or disable "Adaptive Battery" for this app
