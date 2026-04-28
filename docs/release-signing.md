# Release Signing for Android

The CI workflow (`Build Android`) currently signs the APK with the **debug key**,
which is fine for sideloading and personal testing but is **not acceptable for
Google Play Store submission**.

Follow these steps when you are ready to publish to the Play Store.

---

## 1. Generate a release keystore

```bash
keytool -genkey -v \
  -keystore flutter-music-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias flutter-music
```

Keep this file **private** – never commit it to the repository.

---

## 2. Encode the keystore as a Base64 secret

```bash
base64 -w 0 flutter-music-release.jks
```

Copy the output.

---

## 3. Add GitHub Actions secrets

In your repository go to **Settings → Secrets and variables → Actions → New repository secret** and add:

| Secret name              | Value                                    |
|--------------------------|------------------------------------------|
| `KEYSTORE_BASE64`        | Base64-encoded keystore (from step 2)    |
| `KEYSTORE_PASSWORD`      | Password you chose when generating       |
| `KEY_ALIAS`              | `flutter-music` (or whatever you chose)  |
| `KEY_PASSWORD`           | Key password (often same as store pass)  |

---

## 4. Create `android/key.properties`

This file is listed in `.gitignore` and must **not** be committed.  The CI
workflow creates it at build time from the secrets above.  For local release
builds, create it manually:

```properties
storePassword=<KEYSTORE_PASSWORD>
keyPassword=<KEY_PASSWORD>
keyAlias=flutter-music
storeFile=../flutter-music-release.jks
```

---

## 5. Reference `key.properties` in `android/app/build.gradle`

Add the following **before** the `android {}` block:

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

Inside `android { ... }` add a `signingConfigs` block and reference it in
`buildTypes.release`:

```groovy
signingConfigs {
    release {
        keyAlias     keystoreProperties['keyAlias']
        keyPassword  keystoreProperties['keyPassword']
        storeFile    keystoreProperties['storeFile'] ?
                         file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}

buildTypes {
    release {
        signingConfig signingConfigs.release
        // ...
    }
}
```

---

## 6. Update the CI workflow

In `.github/workflows/build-android.yml`, add a step **before** the build steps
that decodes the keystore and writes `key.properties`:

```yaml
- name: Decode release keystore
  env:
    KEYSTORE_BASE64:   ${{ secrets.KEYSTORE_BASE64 }}
    KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
    KEY_ALIAS:         ${{ secrets.KEY_ALIAS }}
    KEY_PASSWORD:      ${{ secrets.KEY_PASSWORD }}
  run: |
    echo "$KEYSTORE_BASE64" | base64 --decode > android/flutter-music-release.jks
    cat > android/key.properties <<EOF
    storePassword=${KEYSTORE_PASSWORD}
    keyPassword=${KEY_PASSWORD}
    keyAlias=${KEY_ALIAS}
    storeFile=flutter-music-release.jks
    EOF
```

---

## 7. Flip the Play Store flag

Once the app is published, update `lib/config/app_links.dart`:

```dart
static const bool androidOnPlayStore = true;
static const String playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.example.fun_sheet_music';
```

The in-app QR code and download button will automatically switch to the
Play Store listing.
