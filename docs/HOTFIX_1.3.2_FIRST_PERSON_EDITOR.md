# MZ Computer 1.3.2 - First-person terminal editor

## Goal

Make `/mztela` calibrate a world computer from the same point of view the final player will use, without replacing the existing DUI/surface renderer or changing notebook behaviour.

## Editor flow

1. Select the monitor through `mz_world_editor`.
2. Mark top-left, top-right and bottom-left screen corners.
3. Use the existing external calibration preview to verify the mapped glass.
4. Press ENTER to enter **live first-person simulation**.
5. Walk with WASD and look with the mouse until the real use position/view feels correct.
6. Press ENTER to capture:
   - prop-local `playerAnchor` position;
   - relative player heading;
   - eye offset relative to the mapped screen basis;
   - exact looked-at point on the screen plane;
   - gameplay camera FOV.
7. The editor immediately reproduces that capture with the same scripted first-person camera used by runtime.
8. Press ENTER to save or `R` to return to live first-person calibration.

The interaction anchor defaults to the captured player position. `interactionDistance` remains configurable from the existing settings dialog.

## Compatibility

- Existing terminals without captured first-person fields continue using `Config.WorldDisplay` defaults.
- Existing `terminals.json` format version remains `1`; the new display fields are optional.
- Personal notebook NUI is unchanged.
- `mz_world_editor` is unchanged and remains responsible only for entity selection.

## Safety

The server bounds all captured first-person offsets before persistence. Camera eye offsets are limited to +/-0.5 m and screen target offsets to +/-2 m. Invalid registrations are rejected instead of being published.
