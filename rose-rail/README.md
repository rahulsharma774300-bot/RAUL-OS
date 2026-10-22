# Rose Rail — Midnight Express

A separate Godot 4.5 rail runner in RAUL-OS. Earlier prototypes are untouched.

Mika is an original raspberry feline in a bomber jacket, cap, sunglasses and sneakers. All meshes, skin weights and five skeletal clips are built from the included Blender source. No Pink Panther or Subway Surfers assets are included.

## Play

Swipe left/right to change lanes, up to jump, down to roll. Gold ramps lead to train roofs. Moving express trains have no ramps. Collect M/S/J/2× pickups for magnet, one-hit shield, jump boost and doubled score. Missions raise the permanent score multiplier. One free revive is available per run. Bank coins at the end of a run. Arrow keys/WASD work on desktop; P pauses.

## Build

1. Run `blender --background --python tools/create_art.py` from this directory.
2. Run `python3 generate_audio.py`.
3. Import `project.godot` in Godot 4.5.
4. Run `godot --headless --path . -- --smoke` for gameplay regression.
5. Export **Android Debug** using Godot 4.5 Android templates, JDK 17 and Android SDK 35.

The `Rose Rail Android` GitHub workflow builds art and sound, runs a 6 km gameplay regression, renders a screenshot, verifies the APK signature and installs/launches the APK in an Android 35 x86_64 emulator. The universal debug APK also includes ARM64 for phones.

## Performance and limits

Six recycled 48 m scenery chunks, instanced sleepers, bounded hazards/pickups, pooled SFX and the OpenGL compatibility renderer target mobile devices. Shadow distance is capped. This is a playable indie implementation, not equivalent to a professionally art-directed commercial runner. The original character is a stylized segmented skinned model, scenery patterns repeat, audio is synthesized, and physical ARM64 device frame-rate/battery testing remains necessary. No store signing, ads, purchases or online services are included.

## Asset provenance

All game art and audio are generated from original source in this folder; no external game artwork or models are downloaded. Godot and Blender are build/runtime tools under their respective licenses. The previous prototypes' external assets are not used.
