# 🕌 Mosque GPS Companion (Smart Auto-Vibrate & Islamic Suite)

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-API%2029%20--%2036-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://android.com)
[![Supabase](https://img.shields.io/badge/Supabase-Database%20%26%20Auth-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

An intelligent, offline-first Flutter & Native Android application designed to **automatically put smartphones on VIBRATE mode upon entering a Mosque/Masjid boundary** and restore normal sound mode upon exiting. Built with rock-solid background survival, strict GPS state gating, an interactive OpenStreetMap picker, Role-Based Cloud Sync (Imam & Namazi), a Digital Qibla Compass, a Daily Prayer Tracker, and a Dynamic Islamic Hijri Calendar.

---

## 🌟 Key Features

### 📳 1. Dual-Layer Auto-Vibrate Engine
- **Pure Vibrate Mode**: Automatically switches phone to Vibrate mode (never full silent, alarms remain audible) upon entering a saved mosque boundary.
- **Native Android Foreground Service (`MosqueForegroundService.kt`)**: Runs 100% independently of the Flutter engine, surviving background sleep, Doze mode, and app closures.
- **Task-Kill & Swipe Protection**: Configured with `stopWithTask="false"` and a native `ServiceRestarterReceiver` to survive aggressive OEM task killers (Vivo, Xiaomi, Oppo, Samsung).
- **Instant Repeated Re-Vibration Watchdog**: Listens natively to `RINGER_MODE_CHANGED_ACTION`. If a user manually un-mutes or switches to Normal mode while inside a mosque, the system **instantly and repeatedly forces Vibrate mode back on**.
- **Strict GPS State Gating**: Operates **only when device Location (GPS) is ON**. If the user disables GPS, the service immediately pauses and restores the normal ringer.

### 🧠 2. Intelligent Proximity & Jitter Filtering
- **Median Filter (5-Sample Sliding Window)**: Smooths GPS distance readings and eliminates noisy satellite spikes.
- **Asymmetric Hysteresis (+30m Exit Buffer)**: Eliminates ringer flickering when standing near boundary edges.
- **Minimum Dwell Lock (45s Lock on Enter)**: Prevents premature exit transitions during momentary indoor satellite attenuation.
- **Stationary Accuracy Gating (0m Threshold)**: Multi-provider listening (`FUSED`, `GPS`, `NETWORK`) with `0.0f` minDistance ensures continuous updates even when standing completely still.

### 🌙 3. Professional Islamic Hijri Calendar (تقویم ہجری)
- **Dual-Date Monthly Grid**: Displays prominent Arabic/English Hijri dates alongside corresponding Gregorian dates.
- **Month Navigation**: Seamlessly browse past and future Hijri months with Arabic calligraphy headers.
- **Ruet-e-Hilal (Moon Sighting) Adjuster**: Customizable offset controller (`-2`, `-1`, `0`, `+1`, `+2` days) to align with Pakistan or local moon sightings.
- **Sunnah Fasting Badges**: Highlights Ayyam al-Beed (13th, 14th, 15th) and Monday/Thursday Sunnah fasts.
- **Sacred Months & Islamic Events**: Master directory of annual historical events (Ramadan, Eidain, Ashura, Mawlid, Laylatul Qadr, Day of Arafah, etc.).

### 👥 4. Role-Based Cloud Sync (Imam vs Namazi)
- **Imam Mode**: Create & manage mosques, customize geofence radii on OpenStreetMap, update Jamaat prayer timings, post mosque announcements, and generate 6-character Share Codes.
- **Namazi (User) Mode**: Join mosques via Share Code or discover nearby registered masajid without edit permissions. Real-time announcement feeds and live Jamaat schedules.

### 🗺️ 5. Interactive Map & Geofencing Picker
- **OpenStreetMap Integration (`flutter_map`)**: Visual radius picker displaying live GPS user position, draggable pinpointing, and translucent geofence circles.

### 🧭 6. Accurate Digital Qibla Compass
- **Sensor Fusion Compass**: Calculates true North bearing and Kaaba direction based on live GPS coordinates, with haptic feedback on exact alignment.

### 📊 7. Daily Namaz Tracker & Diagnostics
- **5 Daily Prayers Tracker**: Track Fajr, Dhuhr, Asr, Maghrib, and Isha with streak monitoring and Jamaat vs Individual breakdown.
- **Live Diagnostics Dashboard**: Real-time telemetry displaying active provider, accuracy margin, raw vs smoothed distances, and live rejection logs.

---

## 🏗️ Project Architecture

```
lib/
├── app.dart                          # MaterialApp configuration & dark Islamic theme
├── app_scope.dart                    # Dependency injection & service locator
├── main.dart                         # Application entry point
├── background/
│   └── proximity_engine.dart         # Core proximity detection, filtering & zone management
├── core/
│   ├── discovery/                    # Nearby mosque discovery services
│   ├── location/                     # Location helper & provider settings
│   ├── native/                       # MethodChannel bridge to Kotlin foreground service
│   ├── notifications/                # Local notifications & action handling
│   ├── permissions/                  # Runtime permissions management
│   ├── prayer/                       # Adhan prayer times, tracker & Hijri calendar engine
│   ├── qibla/                        # Sensor fusion Qibla bearing calculations
│   ├── ringer/                       # Sound mode manager & event streams
│   ├── role/                         # Imam vs Namazi role management
│   ├── security/                     # Secure token storage & device ID
│   └── supabase/                     # Supabase cloud database & realtime client
├── data/
│   ├── db/
│   │   ├── app_database.dart         # Drift SQLite reactive local database
│   │   └── daos/                     # Data Access Objects (Mosques, Prayer Times)
│   └── repositories/                 # Mosque & announcement repositories
└── features/
    ├── announcements/                # Mosque community notices & alerts
    ├── calendar/                     # Full Islamic Hijri Calendar & events sheet
    ├── diagnostics/                  # Live GPS telemetry & event debugger
    ├── home/                         # Main Islamic dashboard & prayer times
    ├── map/                          # OpenStreetMap geofence picker
    ├── mosque/                       # Add, edit, join & discover mosques
    ├── onboarding/                   # Permission onboarding flow
    ├── prayer_tracker/               # Daily 5-prayer completion tracker
    ├── qibla/                        # Interactive digital Qibla compass
    ├── role/                         # Role selection (Imam / Namazi)
    └── settings/                     # Application preferences & toggles
```

---

## 🛠️ Tech Stack & Dependencies

- **Framework**: [Flutter](https://flutter.dev) (Dart SDK `^3.12.2`)
- **Native Android**: Kotlin (Foreground Services, `AudioManager`, `LocationManager`, `WakeLock`)
- **Backend & Cloud Sync**: [Supabase](https://supabase.com) (PostgreSQL, Realtime, Row Level Security)
- **Local Database**: [`drift: ^2.34.3`](https://pub.dev/packages/drift) + [`sqlite3`](https://pub.dev/packages/sqlite3)
- **Mapping**: [`flutter_map: ^8.3.2`](https://pub.dev/packages/flutter_map) + [`latlong2: ^0.10.1`](https://pub.dev/packages/latlong2)
- **Sensors & Compass**: [`sensors_plus: ^7.1.0`](https://pub.dev/packages/sensors_plus)
- **Prayer Calculations**: [`adhan_dart: ^2.0.1`](https://pub.dev/packages/adhan_dart)
- **Audio & Sound Profiles**: [`sound_mode_advanced: ^4.0.0`](https://pub.dev/packages/sound_mode_advanced)
- **Notifications**: [`flutter_local_notifications: ^22.3.0`](https://pub.dev/packages/flutter_local_notifications)
- **Permissions**: [`permission_handler: ^13.0.0`](https://pub.dev/packages/permission_handler)

---

## 📱 Permissions Required

To operate continuously in the background and manage sound profiles, this app requires:

1. **Location Permissions**:
   - `ACCESS_FINE_LOCATION` & `ACCESS_COARSE_LOCATION`
   - `ACCESS_BACKGROUND_LOCATION` ("Allow all the time" for geofencing)
2. **Notification & Sound Policy**:
   - `ACCESS_NOTIFICATION_POLICY` (Do Not Disturb access to toggle Vibrate/Normal)
   - `MODIFY_AUDIO_SETTINGS`
3. **Background Survival**:
   - `FOREGROUND_SERVICE` & `FOREGROUND_SERVICE_LOCATION`
   - `WAKE_LOCK` & `RECEIVE_BOOT_COMPLETED`
   - `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`

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

### 4. Code Generation (Drift SQLite)
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 5. Run the App
```bash
flutter run
```

---

## 👤 Author

- **Muhammad Awais** - [@MuhammadAwais-Automation](https://github.com/MuhammadAwais-Automation)

---

## 📄 License

This project is licensed under the MIT License.
