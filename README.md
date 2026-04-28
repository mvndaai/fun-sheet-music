# Fun Sheet Music

An app for displaying colored sheet music with practice modes.

## Features

- **MusicXML Support** – Upload `.xml`, `.mxl`, or `.musicxml` files from your device, or download directly from a Google Cloud Storage bucket (or any public URL).
- **Color-Coded Sheet Music** – Notes are displayed as colored circles matching a children's xylophone (C = Red, D = Orange, E = Yellow, F = Green, G = Teal, A = Blue, B = Purple).
- **Dual Note Names** – Toggle between letter notation (A, B, C), solfège (Do, Re, Mi), or both simultaneously.
- **Song Library with Tags** – All uploaded songs are stored locally and can be organized with custom tags for easy filtering.
- **Practice Mode (Microphone)** – The app listens to the microphone, detects the pitch being played, highlights the current note on the sheet music, and automatically advances when the correct note is heard.
- **Cross-Platform** – Targets Android, iOS, and Web.

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.0.0

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

## Architecture

```
lib/
├── main.dart                  # App entry point
├── music_kit/                 # Core music rendering & logic
│   ├── models/
│   │   ├── music_note.dart
│   │   ├── measure.dart
│   │   ├── song.dart
│   │   └── instrument_profile.dart
│   ├── widgets/
│   │   ├── note_renderer.dart
│   │   ├── sheet_music_renderer.dart
│   │   └── staff_painter.dart
│   └── utils/
│       ├── music_constants.dart
│       └── note_resolver.dart
├── services/
│   ├── musicxml_parser.dart   # MusicXML → Song parser
│   ├── storage_service.dart   # SharedPreferences-based local storage
│   └── pitch_detection_service.dart # Microphone capture + FFT pitch detection
├── providers/
│   ├── song_provider.dart     # Songs state management
│   └── instrument_provider.dart # Active instrument state management
├── screens/
│   ├── home_screen.dart       # Song library + tag filtering
│   ├── sheet_music_screen.dart# Full sheet music display
│   ├── practice_screen.dart   # Practice mode with microphone/keyboard
│   ├── instruments_screen.dart # Instrument list & selection
│   ├── instrument_editor_screen.dart # Edit instrument details
│   └── keyboard_config_screen.dart # Configure key-to-note mappings
├── widgets/
│   ├── note_widget.dart       # App-connected note circle
│   ├── sheet_music_widget.dart# App-connected sheet music view
│   └── instrument_setup/      # Multi-step setup wizards
│       ├── add_key_wizard.dart
│       └── tuning_wizard.dart
└── utils/
    └── note_colors.dart       # Default color palette
```

## Sample Song

A sample "Twinkle Twinkle Little Star" MusicXML file is included at
`assets/sample_songs/twinkle_twinkle.xml`.

## Microphone Practice Mode

1. Open a song and tap **Practice**.
2. Tap the microphone button (🎙) to start listening.
3. The current note to play is highlighted in large format at the top.
4. Play the note on your instrument – when the app detects the correct pitch it advances automatically.
5. Use the skip buttons (⏮ / ⏭) to navigate manually.

## Permissions

| Platform | Permission       | Purpose                     |
|----------|------------------|-----------------------------|
| Android  | `RECORD_AUDIO`   | Microphone for practice mode|
| iOS      | `NSMicrophoneUsageDescription` | Microphone for practice mode |
| Web      | Browser mic prompt | Microphone for practice mode |
