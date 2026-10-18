# PosePilot Android

Native Android starter app for a location-aware photography pose assistant.

## Current build
- Kotlin + Jetpack Compose dark UI
- 12 starter poses with category filters and instructions
- Scene selector for mountains, greenery, city and indoor
- Android camera and location dependencies are configured for the next integration step

## Current limitations
This first build is a UI prototype. The current scene selector is manual; GPS, live camera preview, image-labeling pipeline, pose overlays, and photo capture are not yet connected in the screen. Do not treat those features as completed.

## Build
The GitHub Actions workflow at .github/workflows/posepilot.yml builds a debug APK and uploads it as an artifact.
