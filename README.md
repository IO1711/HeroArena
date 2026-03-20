# HeroArena

## Overview

This project is currently a small iOS `SwiftUI + RealityKit` character preview app.
It is set up as the first step toward the workshop flow where students build a character in code and immediately see the result in the app.

Right now the app supports:

- one playable body type: `orc`
- four weapon choices: `sword`, `axe`, `spear`, `mace`
- idle and weapon-specific attack animation playback
- weapon attachment to the exported rig at `mixamorig:RightHandThumb3`

There is no combat system yet.
This project is only the preview / asset-pipeline stage.

## Current Student Workflow

The editing workflow is intentionally centered on one file:

- [CharacterConfigurer.swift](/Users/bilolbekrayimov/games/SwiftUi/HeroArena/HeroArena/CharacterConfigurer.swift)

At the top of that file, the user changes:

```swift
let selectedBody: BodyType = .orc
let selectedWeapon: WeaponType = .axe
```

The same file also contains:

- the `BodyType` and `WeaponType` enums
- the mapping from enums to asset file names
- the `CharacterConfigurerView`
- a SwiftUI preview so Xcode Preview reflects the current selection

The app entry point is very small:

- [HeroArenaApp.swift](/Users/bilolbekrayimov/games/SwiftUi/HeroArena/HeroArena/HeroArenaApp.swift)
- [ContentView.swift](/Users/bilolbekrayimov/games/SwiftUi/HeroArena/HeroArena/ContentView.swift)

`ContentView` simply shows `CharacterConfigurerView()`.

## Current Runtime Behavior

The RealityKit scene is managed by:

- [ModelSceneController.swift](/Users/bilolbekrayimov/games/SwiftUi/HeroArena/HeroArena/ModelSceneController.swift)
- [ModelViewerView.swift](/Users/bilolbekrayimov/games/SwiftUi/HeroArena/HeroArena/ModelViewerView.swift)

Current behavior:

- load the selected body model
- load the selected weapon model
- attach the weapon to `mixamorig:RightHandThumb3`
- fall back to `mixamorig:RightHand` if that socket is missing
- show two buttons: `Play Idle` and `Play Attack`
- load animation clips from separate USD files and play them on the loaded body

Important implementation detail:

- the visible body model must be rigged
- separate animation files only work when they use the exact same skeleton, bone names, hierarchy, and rest pose as the body model

## Current Asset Mapping

### Body

Only one body is wired right now:

- `BodyType.orc`

Body asset mapping:

- preview / body model: `Models/orc_idle.usdc`
- idle animation: `Models/orc_idle.usdc`

Attack animation mapping:

- sword: `Models/orc_sword_attack.usdc`
- axe: `Models/orc_axe_attack.usdc`
- spear: `Models/orc_spear_attack.usdc`
- mace: `Models/orc_mace_attack.usdc`

### Weapons

Weapon assets currently come from `Models/weapon`:

- `Models/weapon/sword.usdz`
- `Models/weapon/axe.usdz`
- `Models/weapon/spear.usdz`
- `Models/weapon/mace.usdz`

There are also duplicate top-level weapon assets in `Models/`, but the app currently uses the files in `Models/weapon/`.

## Project Structure

- [README_ARMATURE.md](/Users/bilolbekrayimov/games/SwiftUi/HeroArena/README_ARMATURE.md)
  Canonical exported rig contract for playable bodies.
- [HeroArena/CharacterConfigurer.swift](/Users/bilolbekrayimov/games/SwiftUi/HeroArena/HeroArena/CharacterConfigurer.swift)
  Main student-facing file and preview workflow.
- [HeroArena/ModelSceneController.swift](/Users/bilolbekrayimov/games/SwiftUi/HeroArena/HeroArena/ModelSceneController.swift)
  Loads body and weapon assets, attaches the weapon, and plays animations.
- [HeroArena/ModelViewerView.swift](/Users/bilolbekrayimov/games/SwiftUi/HeroArena/HeroArena/ModelViewerView.swift)
  Wraps `ARView` in SwiftUI.
- [HeroArena/Models](/Users/bilolbekrayimov/games/SwiftUi/HeroArena/HeroArena/Models)
  Body, animation, weapon, and texture assets.

## Armature Contract

The current rig contract is documented in:

- [README_ARMATURE.md](/Users/bilolbekrayimov/games/SwiftUi/HeroArena/README_ARMATURE.md)

The most important runtime assumption right now is:

- weapon socket bone: `mixamorig:RightHandThumb3`

If future models or animations break that contract, weapon attachment and animation playback may fail.

## Build

Build command used successfully for the current project:

```bash
xcodebuild -project HeroArena.xcodeproj -scheme HeroArena -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/HeroArenaDerivedData CODE_SIGNING_ALLOWED=NO build
```

## Known Limitations

- Only `orc` is supported as a body enum case right now.
- There is no combat loop, stats system, or gameplay engine yet.
- The app currently assumes one weapon socket on the body rig.
- Animation playback depends on correct export from Blender and matching skeletons across files.
- `HeroArena/Models/README.md` was originally written for an older `ViewerConfiguration.swift` workflow and has now been updated, but older discussions may still refer to that deleted file.

## Recommended Next Steps

- add the remaining body enum cases and their asset mappings
- decide on the final asset naming convention for all bodies and attacks
- attach weapons with explicit offsets if needed after more model testing
- add stats and character-definition data on top of this preview workflow
- later build the combat / showdown layer once the asset pipeline is stable
