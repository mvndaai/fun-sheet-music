# Community Library

This folder contains sheet music shared by users. Songs added here are automatically indexed and made available in the app under the "Community" library.

## How to add a song

1. Place your MusicXML file (`.xml`) in the `songs/` directory.
2. Ensure your MusicXML file has a proper title and optionally a composer and icon (stored in `miscellaneous-field` with name `icon`).
3. Commit and push your changes.
4. The GitHub Action will automatically update `songs_manifest.json`.

## Technical Details

The app fetches `songs_manifest.json` from the `main` branch on every startup to discover new songs. When a user selects a song to add, it downloads the XML file directly from GitHub's raw content CDN.
