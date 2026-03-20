# Weapon Attachment Reference

This document explains the current working weapon-attachment logic in HeroArena.

Use this as the source of truth when changing preview weapon rendering.
The preview and battle renderers are intentionally separate.

## Canonical Bone Contract

The skeleton contract is defined in `README_ARMATURE.md`.

The weapon socket bone is:

- `mixamorig:RightHandThumb3`

Its contract path is:

- `mixamorig:Hips`
- `mixamorig:Spine`
- `mixamorig:Spine1`
- `mixamorig:Spine2`
- `mixamorig:RightShoulder`
- `mixamorig:RightArm`
- `mixamorig:RightForeArm`
- `mixamorig:RightHand`
- `mixamorig:RightHandThumb1`
- `mixamorig:RightHandThumb2`
- `mixamorig:RightHandThumb3`

If the socket cannot be resolved, the fallback bone is:

- `mixamorig:RightHand`

## Current Preview Logic

The current preview weapon logic lives in `HeroArena/ModelSceneController.swift`.

Main pieces:

- `CharacterPreviewSceneController`
- `attachPreviewWeaponToBody`
- `updateWeaponAttachment`
- `updatePreviewWeaponAttachmentTransform`
- `makeCharacterPreviewWeaponMount`
- `WeaponAttachmentContract`

## Important Rule

In the preview, the weapon mount must stay under the preview root entity, not under the armature or hand joint entity.

This is the key behavior that keeps the weapon visible.
Earlier attempts parented the weapon directly under skeleton entities, and the weapon disappeared from the preview.

## How Preview Attachment Works

1. Load the body and weapon assets.
2. Create `modelRoot`.
3. Add the body to `modelRoot`.
4. Create a separate `weaponMount` entity.
5. Keep `weaponMount` as a child of `modelRoot`.
6. Resolve the attachment source from the body skeleton.
7. Copy the socket transform onto `weaponMount`.
8. Re-apply that transform every frame while the preview is running.

The weapon is not attached by parenting it under the hand bone.
It is attached by following the hand bone transform from outside the skeleton hierarchy.

## Resolution Order

`attachPreviewWeaponToBody` currently resolves the source in this order:

1. Find the socket entity for `mixamorig:RightHandThumb3`.
2. If that fails, create a skeletal pin for `mixamorig:RightHandThumb3`.
3. If that fails, find the fallback entity for `mixamorig:RightHand`.
4. If all of those fail, keep the mount under `modelRoot` with no resolved socket source.

## Why There Are Entity And Pin Paths

RealityKit may expose the hand socket in different ways depending on the loaded USD hierarchy.

The code supports both:

- direct entity resolution
- skeletal pin resolution

The preview uses whichever of those resolves first, but the weapon mount still remains under `modelRoot`.

## Per-Frame Follow

The preview subscribes to `SceneEvents.Update`.

Every frame:

- if a socket entity was resolved, copy its `position(relativeTo: modelRoot)` and `orientation(relativeTo: modelRoot)` to `weaponMount`
- otherwise, if a skeletal pin was resolved, copy the pin position/orientation to `weaponMount`

This keeps the weapon aligned to the animated hand socket while the body animation plays.

## Local Weapon Orientation

`makeCharacterPreviewWeaponMount` applies the local preview rotation to the weapon before it is followed by the socket transform.

Current behavior:

- create `weaponMount`
- set `weapon.orientation = CharacterPreviewRules.weaponOrientationOffset`
- add the weapon under `weaponMount`

This means:

- socket transform controls where the weapon is
- local orientation offset controls how the weapon is rotated inside the hand

## Candidate Name Rules

`WeaponAttachmentContract` resolves both the contract names and USD-safe variants.

Examples:

- `mixamorig:RightHandThumb3`
- `mixamorig_RightHandThumb3`
- full contract path
- USD-safe full path

This is important because RealityKit may expose skeleton names with `:` converted to `_`.

## Do Not Regress

Do not do these in the preview unless there is a deliberate redesign:

- do not parent the visible weapon directly under the hand bone or thumb joint entity
- do not merge preview and battle attachment logic just to reduce code duplication
- do not change the canonical socket away from `mixamorig:RightHandThumb3`
- do not remove the fallback to `mixamorig:RightHand`

## Safe Extension Points

If the preview needs tuning later, the safest places to change are:

- `CharacterPreviewRules.weaponOrientationOffset`
- `makeCharacterPreviewWeaponMount`
- the source resolution order inside `attachPreviewWeaponToBody`

If visibility breaks again, first verify:

1. the weapon mount is still a child of `modelRoot`
2. the socket source still resolves from the current body asset
3. the per-frame transform copy is still running
