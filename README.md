# Fun Sheet Music

An app for displaying colored sheet music.

## Features

- **MusicXML Support** – Upload `.xml`, `.mxl`, or `.musicxml` files from your device, or download directly from a Google Cloud Storage bucket (or any public URL).
- **Color-Coded Sheet Music** – Notes are displayed as colored circles matching a children's xylophone (C = Red, D = Orange, E = Yellow, F = Green, G = Teal, A = Blue, B = Purple).
- **Dual Note Names** – Toggle between letter notation (A, B, C), solfège (Do, Re, Mi), or both simultaneously.
- **Song Library with Tags** – All uploaded songs are stored locally in a Drift database and can be organized with custom tags for easy filtering.
- **Sheet Music Mode (Mic & Keyboard)** – The app listens to the microphone or physical keyboard, detects the pitch/key being played, highlights the current note, and automatically advances when the correct note is heard.
- **Tone Playback** – Play back songs using a built-in synthesizer to hear how they should sound.
- **PDF Export & Printing** – Export your color-coded sheet music to PDF or print directly from the app.
- **Sharing** – Share songs via QR codes or direct links.
- **Cross-Platform** – Targets Android, iOS, and Web with platform-specific optimizations.

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.6.0

### Run

```bash
flutter pub get
flutter run            # default device
flutter run -d chrome  # web
```

### Build

```bash
flutter build apk          # Android
flutter build ios          # iOS
flutter build web          # Web
```

### Assets & Icons

To update the app icons and favicon from a single source image:

1. Save your source image (square preferred) to `assets/images/icon_source.png`.
2. Run the icon generation script:
   ```bash
   dart run tool/generate_icons.dart
   ```
   This will automatically crop, resize, and update icons for Android and Web.

## Architecture

```
lib/
├── main.dart                  # App entry point
├── config/                    # App configuration and deep links
├── music_kit/                 # Core music rendering & logic
│   ├── models/                # Data structures (Song, Note, Measure, etc.)
│   ├── widgets/               # Visual components (Staff, Note, Renderer)
│   ├── utils/                 # Music math, PDF export, XML generation
│   └── sheet_music_constants.dart
├── services/
│   ├── musicxml_parser.dart   # MusicXML → Song parser
│   ├── database.dart          # Drift-based local database
│   ├── storage_service.dart   # File system and preferences storage
│   ├── pitch_detection_service.dart # Microphone capture + FFT pitch detection
│   ├── tone_player.dart       # Synthesized note playback
│   └── cloud_service.dart     # Remote file fetching
├── providers/                 # State management (Song, Instrument, Keyboard)
├── screens/
│   ├── home_screen.dart       # Song library + tag filtering
│   ├── sheet_music_screen.dart# Main viewer with playback & interactive modes
│   ├── upload_screen.dart     # File upload and URL import
│   ├── instruments_screen.dart# Instrument list & selection
│   ├── instrument_setup_screen.dart # Add/Edit instrument details
│   └── keyboard_setup_screen.dart   # Configure key-to-note mappings
├── widgets/                   # Shared UI components
└── platform/                  # Platform-specific abstractions (Web vs Native)
```

## Sample Songs

Several sample MusicXML files are included in `assets/sample_songs/`, including:
- Twinkle Twinkle Little Star
- Old MacDonald Had a Farm
- Mary Had a Little Lamb
- Concerning Hobbits

## Sheet Music Mode

1. Open a song and tap **Sheet Music**.
2. **Microphone**: Tap the microphone button (🎙) to start listening. Play the note on your instrument – the app advances when the correct pitch is detected.
3. **Keyboard**: Connect a physical keyboard (or use your laptop keys). The app maps keys to musical notes for silent practice.
4. The current note is highlighted on the staff, and its name/color is shown at the top.
5. Use the skip buttons (⏮ / ⏭) or tap notes to navigate manually.

## Permissions

| Platform | Permission       | Purpose                     |
|----------|------------------|-----------------------------|
| Android  | `RECORD_AUDIO`   | Microphone for sheet music mode|
| iOS      | `NSMicrophoneUsageDescription` | Microphone for sheet music mode |
| Web      | Browser mic prompt | Microphone for sheet music mode |
