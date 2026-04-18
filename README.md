# flutter-music

A Flutter app that reads MusicXML files and displays color-coded sheet music for kids.

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
├── models/
│   ├── music_note.dart        # Note data model (pitch, duration, type)
│   ├── measure.dart           # Measure (bar) data model
│   └── song.dart              # Song data model + JSON serialization
├── services/
│   ├── musicxml_parser.dart   # MusicXML → Song parser
│   ├── storage_service.dart   # SharedPreferences-based local storage
│   ├── cloud_service.dart     # HTTP fetcher for GCS / public URLs
│   └── audio_service.dart     # Microphone capture + FFT pitch detection
├── providers/
│   └── song_provider.dart     # ChangeNotifier state management
├── screens/
│   ├── home_screen.dart       # Song library + tag filtering
│   ├── sheet_music_screen.dart# Full sheet music display
│   ├── upload_screen.dart     # File upload & URL download
│   └── practice_screen.dart  # Practice mode with microphone
├── widgets/
│   ├── note_widget.dart       # Color circle for a single note
│   ├── sheet_music_widget.dart# Full scrollable sheet music view
│   └── tag_chip.dart          # Tag chip + tag editor dialog
└── utils/
    ├── note_colors.dart       # Xylophone color palette
    └── music_constants.dart   # MIDI / frequency helpers
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
