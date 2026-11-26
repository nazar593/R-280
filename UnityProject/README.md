# R-280 — Unity Stage 01

Unity 6.0 LTS (6000.0.23f1). This is a separate native Android prototype, not a WebView wrapper. The browser project in the root remains unchanged.

## Open and run
1. Install Unity Hub and Unity 6000.0.23f1 with Android Build Support, Android SDK & NDK Tools, and OpenJDK.
2. Open the UnityProject directory, not the repository root. Wait for package import.
3. Choose R-280 > Create or open Stage 01, then Play. The scene is constructed at runtime.
4. Select Pickup, Utility van, or UAV.
5. Desktop: WASD movement/steer, arrows look/pitch, Space brake, C view, R reset, Esc pause.
6. Android: drag on the left/right lower halves; release to center. Hold the bottom middle area to brake. VIEW, RESET, PAUSE are in the top bar.
7. Switch platform to Android through File > Build Profiles. Choose R-280 > Build Android APK. Output: Builds/R280-stage01.apk (ARM64, IL2CPP, debug signing).

## Stage 01 source implemented
- Role selection and two generic wheeled vehicle shapes; basic WheelCollider suspension and smoothed steering.
- Generic fictional flight controller with in-air spawn; flight is not validated against a real airframe.
- Third-person and seat camera modes (gunner and commander are camera positions, no weapons).
- Touch and keyboard command abstraction, fixed-step simulation, reset and pause.
- Small procedural test range; asphalt and gravel are visual only.
- UAV screen with green horizontal bars, circle and vertically moving cross.
- Three graphics choices and target frame-rate caps; not measured on hardware.

## Known limitations
- No imported Hilux, UAZ or Hornet model, no textures or real-world calibration. Temporary primitive geometry.
- No armament, combat, AI, damage, sound assets, large terrain, surface-dependent traction, real launch/landing, connection simulation or networking.
- Built-in renderer for this first prototype. URP migration and shader/LOD work planned.
- Fixed logical HUD layout; safe area, accessibility, control resizing and localization not finished.
- No Unity Editor available in authoring environment. Compilation, APK build, FPS and device screenshots remain unverified. Do not describe this as a tested release.
- Multiplayer boundary: PlayerCommand and IControllable decouple input from simulation. Future authority, state replication, prediction and reconciliation need implementation. PhysX is not deterministic across clients.

## Acceptance test (not yet run)
- Start each of the three roles; check cameras and reset.
- Drive forward/backward, turn and brake; verify wheels contact the test range.
- Fly, change throttle and bank/pitch; inspect the camera and vertical-only cross.
- Check two-finger operation and pause/menu transitions on an Android device.
- Build APK and record screenshots, frame time, memory and temperatures on actual hardware.

## Roadmap
01 project and controls; 02 terrain and surface materials; 03 suspension and vehicle handling; 04 component damage; 05 fictional gameplay combat effects; 06 audio; 07 VFX; 08 flight and HUD refinement; 09 game AI; 10 Android profiling and build. Multiplayer after the offline vertical slice.

## GitHub Actions (optional)
The Unity workflow on this branch is triggered by commits affecting UnityProject or its workflow file. Configure a valid Unity CI license in GitHub repository Actions secrets using https://game.ci/docs/github/activation/ (do not share login credentials in chat or commit them). A failed run can be rerun after setup. On success, download R280-stage01-APK from the run's Artifacts section. The existing browser APK workflow is untouched. F12 during desktop play saves a real in-game screenshot to Application.persistentDataPath. Android screenshots can be captured with the phone's built-in screenshot feature.
