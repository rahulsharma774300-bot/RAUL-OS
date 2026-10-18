# PosePilot Android

PosePilot is a native Android camera-based photography pose coach.

## Current upgraded build
- CameraX live camera preview with front/back camera toggle.
- On-device ML Kit image labeling attempts to classify scene objects/backgrounds.
- Rule-of-thirds composition grid and a selectable pose-template line overlay.
- Scene-informed pose recommendations and 12 original pose prompts for travel, nature, water, street, cafés, cinematic and casual photography.
- Camera permission requested at runtime; scene labeling runs on-device.
- GitHub Actions builds a debug APK artifact.

## Important limitations
- The green body lines are selectable pose templates, not a live body skeleton fitted to a detected person.
- Scene recognition uses general image labels, so it may misclassify complex scenes and should be treated as suggestions.
- GPS-based location identification, photo capture/save controls, automatic human pose landmark detection, and voice guidance are not implemented yet.
- Pinterest is used as a source of broad inspiration categories, not scraped or copied image assets. See examples: [mountain pose ideas](https://in.pinterest.com/riya_rrd/mountain-pose/) and [river/travel poses](https://in.pinterest.com/riyachetry216/river/).

## Build
The GitHub Actions workflow at `.github/workflows/posepilot.yml` builds `app-debug.apk` and uploads it as `PosePilot-debug-apk`.
