# R-280 Godot Stage 01

Godot 4.5.1 stable / GDScript / Compatibility renderer / Android ARM64. Open GodotProject/project.godot in the matching editor. F5 starts the prototype. No paid engine license or secrets needed for the debug APK.

Touch: drag on the lower left half to drive or adjust flight throttle/bank, right half to look/pitch. Hold the bottom center area to brake. Top buttons select camera, reset, FPS target, pause, or menu. Desktop: WASD, arrows, Space.

Temporary test range, generic pickup and van, fictional unarmed flying prototype and green HUD. Not a calibrated simulation or a finished game. No imported vehicle assets or actual screenshots yet. The current renderer prioritizes compatibility; the 30/60 FPS toggle sets a cap, not a measured guarantee. Camera seat changes do not implement crew combat. No multiplayer, AI, weapons, damage, terrain streaming or advanced audio.

GitHub Actions: pushes to godot-stage-01 run a headless smoke test and export a signed debug APK. Download R280-stage01-APK from the successful workflow run. The debug signing key is generated per CI run, so uninstall the previous debug build before installing a new one if Android rejects the update; this removes local app data. No Unity credentials are needed. No Play Store release is configured.

The real Android installation, touch, visual fidelity and FPS must be tested on a phone.
