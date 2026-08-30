# 📍 GPS App (Smart Mosque Geo-Silencer & Prayer Companion)

An offline-first Flutter application designed to automatically silence your smartphone upon entering a Mosque/Masjid boundary and restore the ringer mode when leaving. Built with intelligent GPS smoothing, teleport rejection, asymmetric hysteresis, prayer-time gating, and real-time diagnostics.

---

## 🌟 Key Features

- 🔕 **Automatic Ringer Management**: Automatically silences the phone when stepping inside a saved Masjid and restores the previous sound mode upon exiting.
- 📡 **Offline-First GPS Architecture**: Designed to function reliably without internet or mobile data by directly communicating with the device's GPS chip (with automatic fallback to Google Play Services).
- 🧠 **Intelligent Proximity Engine**:
  - **Median Filter (Window Size 5)**: Smooths GPS distance readings and eliminates sudden noisy spikes.
  - **Teleport / Speed Rejection**: Discards impossible speed jumps (> 12 m/s / ~43 km/h) caused by multipath interference or weak satellite signals.
  - **Asymmetric Hysteresis (15m Exit Buffer)**: Prevents ringer toggling/flapping when standing near boundary borders.
  - **Accuracy Filtering**: Automatically ignores low-confidence fixes with reported accuracy worse than ±30m.
  - **Confidence Classification**: Instant silencing for decisive readings; 20-second dwell confirmation for ambiguous boundary readings.
  - **State Persistence**: Preserves zone states across phone reboots and app restarts to prevent false "exit" triggers.
  - **Active Ringer Watcher & Visit Pause**: Detects if the phone is accidentally un-silenced while inside and re-silences it, while offering a 1-tap notification action to pause enforcement for the current visit.
- 🕌 **Prayer Time Engine (`adhan_dart`)**: Calculates accurate daily prayer times (Fajr, Dhuhr, Asr, Maghrib, Isha) based on mosque geographic coordinates, with optional prayer-time gating.
- 📊 **Live Diagnostics Dashboard**: Real-time telemetry displaying active provider (GPS chip vs Google Play Services), accuracy margin, raw vs smoothed distance, fix timers, and live rejection event logs.
- 💾 **Local Database (`drift` + SQLite)**: Fast, reactive offline persistence for managing Masjids with custom geofence radii and settings.
- 🔔 **Background Foreground Service**: Reliable persistent background monitoring with wake-lock support and status notifications.

---

## 🏗️ Project Architecture

```
lib/
├── app.dart                          # MaterialApp setup & startup gate
├── app_scope.dart                    # Dependency injection & service locator
├── main.dart                         # Entry point
├── background/
│   └── proximity_engine.dart         # Core proximity detection, filtering & zone management
├── core/
│   ├── location/
│   │   └── location_service.dart     # Location helper & provider settings
│   ├── notifications/
│   │   └── notification_service.dart # Flutter local notifications & action handling
│   ├── permissions/
│   │   └── permission_service.dart   # Permission checking & request flows
│   ├── prayer/
│   │   └── prayer_time_service.dart  # Adhan prayer times calculation & gating
│   └── ringer/
│       ├── ringer_change_watcher.dart# Stream listener for live ringer/DND mode changes
│       └── ringer_service.dart       # Sound mode switcher (Normal, Silent, Vibrate, DND)
├── data/
│   ├── db/
│   │   ├── app_database.dart         # Drift SQLite database definition
│   │   └── daos/
│   │       └── mosque_dao.dart       # Mosque data access object
│   └── repositories/
│       └── mosque_repository.dart    # Mosque repository interface
└── features/
    ├── home/
    │   └── home_page.dart            # Main dashboard, toggle switch & prayer card
    ├── diagnostics/
    │   └── diagnostics_page.dart     # Live GPS telemetry & event debugger
    ├── mosque/
    │   ├── add_mosque_page.dart      # Add / edit mosque coordinates & radius
    │   └── mosque_list_page.dart     # Saved mosques management
    ├── onboarding/
    │   └── permission_onboarding_page.dart # Step-by-step permission setup flow
    └── settings/
        └── settings_page.dart        # Application preferences & testing toggles
```

---

## 🛠️ Tech Stack & Dependencies

- **Framework**: [Flutter](https://flutter.dev) (Dart SDK `^3.12.2`)
- **Location & Geolocation**: [`geolocator: ^14.0.3`](https://pub.dev/packages/geolocator)
- **Local Database**: [`drift: ^2.34.3`](https://pub.dev/packages/drift) + [`drift_flutter: ^0.3.1`](https://pub.dev/packages/drift_flutter)
- **Prayer Times**: [`adhan_dart: ^2.0.1`](https://pub.dev/packages/adhan_dart)
- **Audio & Sound Mode**: [`sound_mode_advanced: ^4.0.0`](https://pub.dev/packages/sound_mode_advanced)
- **Notifications**: [`flutter_local_notifications: ^22.3.0`](https://pub.dev/packages/flutter_local_notifications)
- **Permissions**: [`permission_handler: ^13.0.0`](https://pub.dev/packages/permission_handler)
- **Key-Value Storage**: [`shared_preferences: ^2.5.5`](https://pub.dev/packages/shared_preferences)

---

## 📱 Permissions Required

To operate continuously in the background and manage sound profiles, this app requires:

1. **Location Permissions**:
   - `ACCESS_FINE_LOCATION` & `ACCESS_COARSE_LOCATION` (Foreground)
   - `ACCESS_BACKGROUND_LOCATION` ("Allow all the time" for background geofencing)
2. **Do Not Disturb (DND) / Audio Access**:
   - `ACCESS_NOTIFICATION_POLICY` (To change ringer mode to Silent/Normal)
3. **Notifications & Foreground Service**:
   - `POST_NOTIFICATIONS`
   - `FOREGROUND_SERVICE` & `FOREGROUND_SERVICE_LOCATION`
   - `WAKE_LOCK`

---

## 🚀 Getting Started

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.24+ recommended)
- Android Studio / VS Code with Flutter extension
- An Android physical device (recommended for testing GPS and DND ringer switching)

### 2. Clone the Repository
```bash
git clone https://github.com/MuhammadAwais-Automation/GPS-App.git
cd GPS-App
```

### 3. Install Dependencies
```bash
flutter pub get
```

### 4. Code Generation (Drift Database)
If modifying database models, generate Drift boilerplate:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 5. Run the App
```bash
flutter run
```

---

## 🧪 Testing the Proximity Engine

1. Open the app and complete the **Permission Onboarding**.
2. Add a test location (e.g., your current coordinates) with a small radius (e.g., 20m–30m).
3. Open the **Live Diagnostics** page to monitor real-time satellite accuracy, distance smoothing, and zone transitions.
4. In **Settings**, you can toggle **"Ignore Prayer Times"** to test proximity silencing at any time of the day.

---

## 👤 Author

- **Muhammad Awais** - [@MuhammadAwais-Automation](https://github.com/MuhammadAwais-Automation)

---

## 📄 License

This project is licensed under the MIT License.
