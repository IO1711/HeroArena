# Mixamo Armature Contract

## Overview

This document is the canonical armature layout for all playable body models in HeroArena.
Future code must read the exact bone names listed here.
All future body variants must preserve this hierarchy and naming.

## Naming Contract

Bone names are exact and case-sensitive.
The `mixamorig:` prefix is part of the contract.
Code should not rename, normalize, or guess missing bones at load time.

## Current Bone Hierarchy

```text
mixamorig:Hips
├── mixamorig:Spine
│   └── mixamorig:Spine1
│       └── mixamorig:Spine2
│           ├── mixamorig:Neck
│           │   └── mixamorig:Head
│           │       └── mixamorig:HeadTop_End
│           ├── mixamorig:LeftShoulder
│           │   └── mixamorig:LeftArm
│           │       └── mixamorig:LeftForeArm
│           │           └── mixamorig:LeftHand
│           │               ├── mixamorig:LeftHandThumb1
│           │               │   └── mixamorig:LeftHandThumb2
│           │               │       └── mixamorig:LeftHandThumb3
│           │               │           └── mixamorig:LeftHandThumb4
│           │               └── mixamorig:LeftHandIndex1
│           │                   └── mixamorig:LeftHandIndex2
│           │                       └── mixamorig:LeftHandIndex3
│           │                           └── mixamorig:LeftHandIndex4
│           └── mixamorig:RightShoulder
│               └── mixamorig:RightArm
│                   └── mixamorig:RightForeArm
│                       └── mixamorig:RightHand
│                           ├── mixamorig:RightHandThumb1
│                           │   └── mixamorig:RightHandThumb2
│                           │       └── mixamorig:RightHandThumb3
│                           │           └── mixamorig:RightHandThumb4
│                           └── mixamorig:RightHandIndex1
│                               └── mixamorig:RightHandIndex2
│                                   └── mixamorig:RightHandIndex3
│                                       └── mixamorig:RightHandIndex4
├── mixamorig:LeftUpLeg
│   └── mixamorig:LeftLeg
│       └── mixamorig:LeftFoot
│           └── mixamorig:LeftToeBase
│               └── mixamorig:LeftToe_End
└── mixamorig:RightUpLeg
    └── mixamorig:RightLeg
        └── mixamorig:RightFoot
            └── mixamorig:RightToeBase
                └── mixamorig:RightToe_End
```

## Code-Facing Anchor Bones

- Skeleton root: `mixamorig:Hips`
- Upper torso chain: `mixamorig:Spine` -> `mixamorig:Spine1` -> `mixamorig:Spine2`
- Head anchor: `mixamorig:Head`
- Left hand anchor: `mixamorig:LeftHand`
- Right hand anchor: `mixamorig:RightHand`
- Weapon socket: `mixamorig:RightHandThumb3`
- Left foot anchor: `mixamorig:LeftFoot`
- Right foot anchor: `mixamorig:RightFoot`

## Weapon Socket

Use `mixamorig:RightHandThumb3` as the weapon socket in app code.
Its parent path is `mixamorig:RightHand` -> `mixamorig:RightHandThumb1` -> `mixamorig:RightHandThumb2` -> `mixamorig:RightHandThumb3`.
Weapon attachment logic should target this bone directly.
If the weapon socket bone cannot be resolved, code should fall back to `mixamorig:RightHand`.

## Rig Compatibility Rules

- All future body models must keep the exact same exported hierarchy.
- Existing bone names must not be renamed.
- No extra parent may be inserted above `mixamorig:Hips`.
- Adding helper bones is allowed only if existing names and parent-child paths stay intact.
- If future attack animations are added, they must target this same skeleton contract.

## Verification Notes

- Compare the hierarchy above line by line against the Blender armature screenshots.
- Verify every future exported body contains `mixamorig:Hips` and the full published chain structure.
- Verify code can always resolve `mixamorig:RightHand`.
- Verify code can always resolve `mixamorig:RightHandThumb3`.
- Reject or flag any future model export that renames the `mixamorig:` bones or changes their parent-child relationships.

## Assumptions

- The screenshot set is the full public armature contract for now.
- Only the visible Mixamo bones are guaranteed; hidden control rig bones are not part of this contract.
- This README documents the current exact rig, not a normalized alias layer.
- The future app should prefer exact exported names rather than trying to infer alternate skeleton layouts.
