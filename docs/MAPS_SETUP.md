# Google Maps setup

The app reads its Google Maps SDK key from **git-ignored** files, so the key is
never committed. Paste your key in the one file per platform below, then rebuild.

## Android
File: `android/local.properties` (git-ignored)

```properties
MAPS_API_KEY=AIza...your-android-key...
```

Gradle injects it into `AndroidManifest.xml` via `manifestPlaceholders`
(`com.google.android.geo.API_KEY`). No other edits needed — just
`flutter run -d android`.

## iOS
File: `ios/Flutter/Maps.xcconfig` (git-ignored)

```
MAPS_API_KEY = AIza...your-ios-key...
```

The key flows xcconfig → `Info.plist` (`MAPS_API_KEY`) → `AppDelegate.swift`
(`GMSServices.provideAPIKey`). After pasting, run:

```sh
cd ios && pod install && cd ..
flutter run -d ios
```

## Notes
- You can use one key for both platforms or one per platform. Restrict each key
  in Google Cloud Console: Android by package name
  (`com.wildlife.wildlife_conservation_system`) + SHA-1; iOS by bundle ID.
- Enable **Maps SDK for Android** and **Maps SDK for iOS** on the key, with
  billing enabled.
- If no key is set, the app still builds and runs; only the map tiles stay blank.
