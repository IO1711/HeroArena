import Combine
import Foundation
import RealityKit
import SwiftUI

@MainActor
final class CharacterPreviewSceneController: ObservableObject {
    @Published private(set) var statusMessage = "Loading preview..."
    @Published private(set) var isModelLoaded = false
    @Published private(set) var currentAnimationDescription = "Nothing selected"
    @Published private(set) var attackAnimationDuration: TimeInterval = 0

    var hasError: Bool {
        errorMessage != nil
    }

    private weak var arView: ARView?
    private let contentAnchor = AnchorEntity()
    private let cameraAnchor = AnchorEntity()
    private let lightAnchor = AnchorEntity()
    private let cameraEntity = PerspectiveCamera()
    private let selection: CharacterSelection
    private let modelPosition: SIMD3<Float>
    private let modelOrientation: simd_quatf
    private var modelRootEntity: Entity?
    private var bodyEntity: Entity?
    private var weaponEntity: Entity?
    private var weaponMountEntity: Entity?
    private var weaponAttachmentEntity: Entity?
    private var weaponAttachmentPin: GeometricPin?
    private var playbackController: AnimationPlaybackController?
    private var sceneUpdateSubscription: (any Cancellable)?
    private var transientAnimationTask: Task<Void, Never>?
    private var errorMessage: String?
    private var hasLoadedScene = false
    private var orbitAngle: Float = 0
    private var zoomFactor: Float = 1

    init(
        selection: CharacterSelection,
        modelPosition: SIMD3<Float> = CharacterPreviewRules.modelPosition,
        modelOrientation: simd_quatf = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    ) {
        self.selection = selection
        self.modelPosition = modelPosition
        self.modelOrientation = modelOrientation
    }

    func attach(to arView: ARView) {
        guard self.arView !== arView else { return }

        self.arView = arView
        configureScene(in: arView)

        guard !hasLoadedScene else { return }
        hasLoadedScene = true

        Task {
            await loadPreview()
        }
    }

    func playIdle() {
        transientAnimationTask?.cancel()

        Task {
            await playAnimationAsync(
                title: "Idle",
                asset: selection.idleAnimationAsset,
                repeats: true,
                playbackSpeed: 1
            )
        }
    }

    func playAttack() {
        transientAnimationTask?.cancel()

        Task {
            await playAnimationAsync(
                title: "\(selection.weapon.displayName) Attack",
                asset: selection.attackAnimationAsset,
                repeats: true,
                playbackSpeed: selection.attackAnimationPlaybackSpeed
            )
        }
    }

    func playAttackOnceThenIdle() {
        transientAnimationTask?.cancel()

        transientAnimationTask = Task {
            await playAnimationAsync(
                title: "\(selection.weapon.displayName) Attack",
                asset: selection.attackAnimationAsset,
                repeats: false,
                playbackSpeed: selection.attackAnimationPlaybackSpeed
            )

            guard !Task.isCancelled else { return }

            let recoveryDuration = max(
                attackAnimationDuration,
                CharacterPreviewRules.minimumAttackRecoveryDuration
            )
            let delayNanoseconds = UInt64(recoveryDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delayNanoseconds)

            guard !Task.isCancelled else { return }

            await playAnimationAsync(
                title: "Idle",
                asset: selection.idleAnimationAsset,
                repeats: true,
                playbackSpeed: 1
            )
        }
    }

    func rotateView(by angleDelta: Float) {
        orbitAngle += angleDelta
        updateCameraTransform()
    }

    func zoomView(by scaleDelta: Float) {
        let adjustedZoom = zoomFactor / scaleDelta
        zoomFactor = min(max(adjustedZoom, ShowdownSceneRules.minZoomFactor), ShowdownSceneRules.maxZoomFactor)
        updateCameraTransform()
    }

    private func configureScene(in arView: ARView) {
        arView.scene.addAnchor(contentAnchor)
        arView.scene.addAnchor(cameraAnchor)
        arView.scene.addAnchor(lightAnchor)

        if cameraEntity.parent == nil {
            cameraAnchor.addChild(cameraEntity)
        }
        updateCameraTransform()

        let keyLight = DirectionalLight()
        keyLight.light.intensity = 35_000
        keyLight.light.color = SceneLightPalette.previewKey
        keyLight.position = SIMD3<Float>(1.6, 2.8, 2.0)
        keyLight.look(at: CharacterPreviewRules.cameraLookAt, from: keyLight.position, relativeTo: nil)
        lightAnchor.addChild(keyLight)

        let fillLight = DirectionalLight()
        fillLight.light.intensity = 11_000
        fillLight.light.color = SceneLightPalette.previewFill
        fillLight.position = SIMD3<Float>(-1.9, 1.7, 1.5)
        fillLight.look(at: CharacterPreviewRules.cameraLookAt, from: fillLight.position, relativeTo: nil)
        lightAnchor.addChild(fillLight)
    }

    private func loadPreview() async {
        do {
            let body = try await Entity(contentsOf: assetURL(for: selection.bodyAsset))
            let modelRoot = Entity()
            modelRoot.position = modelPosition
            modelRoot.orientation = modelOrientation
            modelRoot.scale = SIMD3<Float>(repeating: CharacterPreviewRules.modelScale)
            modelRoot.addChild(body)

            contentAnchor.children.removeAll()
            contentAnchor.addChild(modelRoot)

            modelRootEntity = modelRoot
            bodyEntity = body
            weaponEntity = nil
            weaponMountEntity = nil
            weaponAttachmentEntity = nil
            weaponAttachmentPin = nil
            let rawAttackDuration = (try? await loadAnimationDuration(from: selection.attackAnimationAsset)) ?? 0
            attackAnimationDuration = selection.effectiveAttackAnimationDuration(from: rawAttackDuration)

            errorMessage = nil
            isModelLoaded = true
            currentAnimationDescription = "Nothing selected"
            statusMessage = "Loaded \(selection.body.displayName) with \(selection.weapon.displayName)"
        } catch {
            modelRootEntity = nil
            bodyEntity = nil
            weaponEntity = nil
            weaponMountEntity = nil
            weaponAttachmentEntity = nil
            weaponAttachmentPin = nil
            attackAnimationDuration = 0
            errorMessage = error.localizedDescription
            isModelLoaded = false
            currentAnimationDescription = "Nothing selected"
            statusMessage = "Failed to load preview: \(error.localizedDescription)"
        }
    }

    private func attachWeapon(_ weapon: Entity, to body: Entity, in modelRoot: Entity) -> String? {
        let attachment = attachPreviewWeaponToBody(weapon, body: body, modelRoot: modelRoot)
        weaponEntity = attachment.weaponEntity
        weaponMountEntity = attachment.mountEntity
        weaponAttachmentEntity = attachment.sourceEntity
        weaponAttachmentPin = attachment.pin
        return attachment.statusMessage
    }

    private func updateWeaponAttachment() {
        guard let weaponMountEntity, let modelRootEntity else {
            return
        }

        if let weaponAttachmentEntity {
            updatePreviewWeaponAttachmentTransform(
                for: weaponMountEntity,
                using: weaponAttachmentEntity,
                relativeTo: modelRootEntity
            )
            return
        }

        guard let weaponAttachmentPin else { return }

        updatePreviewWeaponAttachmentTransform(
            for: weaponMountEntity,
            using: weaponAttachmentPin,
            relativeTo: modelRootEntity
        )
    }

    private func playAnimationAsync(
        title: String,
        asset: CharacterAsset,
        repeats: Bool,
        playbackSpeed: Float
    ) async {
        guard let bodyEntity else {
            statusMessage = "Load a model before trying to play an animation."
            return
        }

        bodyEntity.stopAllAnimations(recursive: true)
        playbackController = nil

        do {
            let animationResource = try await loadAnimationResource(from: asset)
            let configuredAnimation = repeats ? animationResource.repeat() : animationResource
            playbackController = bodyEntity.playAnimation(
                configuredAnimation,
                transitionDuration: 0.15,
                startsPaused: false
            )
            playbackController?.speed = playbackSpeed
            errorMessage = nil
            currentAnimationDescription = asset.displayName
            statusMessage = "Playing \(title)"
        } catch {
            errorMessage = error.localizedDescription
            currentAnimationDescription = asset.displayName
            statusMessage = "Failed to play animation: \(error.localizedDescription)"
        }
    }

    private func loadAnimationResource(from asset: CharacterAsset) async throws -> AnimationResource {
        let animationURL = try assetURL(for: asset)
        let animationEntity = try await Entity(contentsOf: animationURL)

        guard let animation = firstAvailableAnimation(in: animationEntity) else {
            throw ViewerError.noAnimationsFound
        }

        return animation
    }

    private func loadAnimationDuration(from asset: CharacterAsset) async throws -> TimeInterval {
        let animation = try await loadAnimationResource(from: asset)
        return animation.definition.duration
    }

    private func firstAvailableAnimation(in entity: Entity) -> AnimationResource? {
        if let animation = entity.availableAnimations.first {
            return animation
        }

        for child in entity.children {
            if let animation = firstAvailableAnimation(in: child) {
                return animation
            }
        }

        return nil
    }

    private func updateCameraTransform() {
        let rotation = simd_quatf(angle: orbitAngle, axis: SIMD3<Float>(0, 1, 0))
        let baseOffset = CharacterPreviewRules.cameraPosition - CharacterPreviewRules.cameraLookAt
        let rotatedOffset = rotation.act(baseOffset) * zoomFactor
        let cameraPosition = CharacterPreviewRules.cameraLookAt + rotatedOffset

        cameraEntity.position = cameraPosition
        cameraEntity.look(
            at: CharacterPreviewRules.cameraLookAt,
            from: cameraPosition,
            relativeTo: nil
        )
    }

    private func assetURL(for asset: CharacterAsset) throws -> URL {
        guard let url = Bundle.main.url(
            forResource: asset.assetName,
            withExtension: asset.assetExtension,
            subdirectory: asset.subdirectory
        ) else {
            throw ViewerError.missingAsset(asset.displayName)
        }

        return url
    }
}

@MainActor
private struct PreviewWeaponAttachment {
    let weaponEntity: Entity
    let mountEntity: Entity
    let sourceEntity: Entity?
    let pin: GeometricPin?
    let statusMessage: String?
}

@MainActor
private func attachPreviewWeaponToBody(_ weapon: Entity, body: Entity, modelRoot: Entity) -> PreviewWeaponAttachment {
    let weaponMount = makeCharacterPreviewWeaponMount(with: weapon)

    if let socket = findAttachmentEntity(in: body, candidates: WeaponAttachmentContract.socketEntityCandidates) {
        modelRoot.addChild(weaponMount)
        updatePreviewWeaponAttachmentTransform(for: weaponMount, using: socket, relativeTo: modelRoot)
        return PreviewWeaponAttachment(
            weaponEntity: weapon,
            mountEntity: weaponMount,
            sourceEntity: socket,
            pin: nil,
            statusMessage: "Preview weapon attached to \(CharacterPreviewRules.weaponSocketBoneName)."
        )
    }

    if let attachment = makeResolvedPreviewWeaponAttachmentPin(on: body) {
        modelRoot.addChild(weaponMount)
        updatePreviewWeaponAttachmentTransform(for: weaponMount, using: attachment.pin, relativeTo: modelRoot)
        return PreviewWeaponAttachment(
            weaponEntity: weapon,
            mountEntity: weaponMount,
            sourceEntity: nil,
            pin: attachment.pin,
            statusMessage: attachment.isFallback
                ? "Preview weapon socket entity missing, attached with right-hand pin."
                : "Preview weapon attached to \(CharacterPreviewRules.weaponSocketBoneName)."
        )
    }

    if let fallback = findAttachmentEntity(in: body, candidates: WeaponAttachmentContract.fallbackEntityCandidates) {
        modelRoot.addChild(weaponMount)
        updatePreviewWeaponAttachmentTransform(for: weaponMount, using: fallback, relativeTo: modelRoot)
        return PreviewWeaponAttachment(
            weaponEntity: weapon,
            mountEntity: weaponMount,
            sourceEntity: fallback,
            pin: nil,
            statusMessage: "Preview socket pin missing, attached to \(CharacterPreviewRules.weaponFallbackBoneName)."
        )
    }

    modelRoot.addChild(weaponMount)
    return PreviewWeaponAttachment(
        weaponEntity: weapon,
        mountEntity: weaponMount,
        sourceEntity: nil,
        pin: nil,
        statusMessage: "Preview weapon socket could not be resolved."
    )
}

@MainActor
private func makeResolvedPreviewWeaponAttachmentPin(on body: Entity) -> (pin: GeometricPin, host: Entity, isFallback: Bool)? {
    if let attachment = makeWeaponAttachmentPin(
        on: body,
        pinName: "previewWeaponSocketPin",
        jointNameCandidates: WeaponAttachmentContract.socketPinCandidates
    ) {
        return (attachment.pin, attachment.host, false)
    }

    if let attachment = makeWeaponAttachmentPin(
        on: body,
        pinName: "previewWeaponRightHandPin",
        jointNameCandidates: WeaponAttachmentContract.fallbackPinCandidates
    ) {
        return (attachment.pin, attachment.host, true)
    }

    return nil
}

@MainActor
private func updatePreviewWeaponAttachmentTransform(for weaponMount: Entity, using pin: GeometricPin, relativeTo body: Entity) {
    guard
        let position = pin.position(relativeTo: body),
        let orientation = pin.orientation(relativeTo: body)
    else {
        return
    }

    weaponMount.position = position
    weaponMount.orientation = orientation
}

@MainActor
private func updatePreviewWeaponAttachmentTransform(for weaponMount: Entity, using entity: Entity, relativeTo root: Entity) {
    weaponMount.position = entity.position(relativeTo: root)
    weaponMount.orientation = entity.orientation(relativeTo: root)
}

@MainActor
final class FightFighterSceneController: ObservableObject {
    @Published private(set) var isModelLoaded = false
    @Published private(set) var attackAnimationDuration: TimeInterval = 0

    private weak var arView: ARView?
    private let contentAnchor = AnchorEntity()
    private let cameraAnchor = AnchorEntity()
    private let lightAnchor = AnchorEntity()
    private let cameraEntity = PerspectiveCamera()
    private let selection: CharacterSelection
    private let modelOrientation: simd_quatf
    private var modelRootEntity: Entity?
    private var bodyEntity: Entity?
    private var weaponMountEntity: Entity?
    private var weaponAttachmentEntity: Entity?
    private var weaponAttachmentPin: GeometricPin?
    private var playbackController: AnimationPlaybackController?
    private var sceneUpdateSubscription: (any Cancellable)?
    private var transientAnimationTask: Task<Void, Never>?
    private var hasLoadedScene = false
    private var orbitAngle: Float = 0
    private var zoomFactor: Float = 1

    init(selection: CharacterSelection, modelOrientation: simd_quatf) {
        self.selection = selection
        self.modelOrientation = modelOrientation
    }

    func attach(to arView: ARView) {
        guard self.arView !== arView else { return }

        self.arView = arView
        configureScene(in: arView)

        guard !hasLoadedScene else { return }
        hasLoadedScene = true

        Task {
            await loadFighter()
        }
    }

    func playIdle() {
        transientAnimationTask?.cancel()

        Task {
            await playAnimationAsync(
                asset: selection.idleAnimationAsset,
                repeats: true,
                playbackSpeed: 1
            )
        }
    }

    func playAttackOnceThenIdle() {
        transientAnimationTask?.cancel()

        transientAnimationTask = Task {
            await playAnimationAsync(
                asset: selection.attackAnimationAsset,
                repeats: false,
                playbackSpeed: selection.attackAnimationPlaybackSpeed
            )

            guard !Task.isCancelled else { return }

            let recoveryDuration = max(
                attackAnimationDuration,
                FightFighterSceneRules.minimumAttackRecoveryDuration
            )
            try? await Task.sleep(nanoseconds: UInt64(recoveryDuration * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await playAnimationAsync(
                asset: selection.idleAnimationAsset,
                repeats: true,
                playbackSpeed: 1
            )
        }
    }

    func rotateView(by angleDelta: Float) {
        orbitAngle += angleDelta
        updateCameraTransform()
    }

    func zoomView(by scaleDelta: Float) {
        let adjustedZoom = zoomFactor / scaleDelta
        zoomFactor = min(max(adjustedZoom, FightFighterSceneRules.minZoomFactor), FightFighterSceneRules.maxZoomFactor)
        updateCameraTransform()
    }

    private func configureScene(in arView: ARView) {
        arView.scene.addAnchor(contentAnchor)
        arView.scene.addAnchor(cameraAnchor)
        arView.scene.addAnchor(lightAnchor)

        if cameraEntity.parent == nil {
            cameraAnchor.addChild(cameraEntity)
        }
        updateCameraTransform()

        let keyLight = DirectionalLight()
        keyLight.light.intensity = FightFighterSceneRules.keyLightIntensity
        keyLight.light.color = SceneLightPalette.previewKey
        keyLight.position = FightFighterSceneRules.keyLightPosition
        keyLight.look(at: FightFighterSceneRules.cameraLookAt, from: keyLight.position, relativeTo: nil)
        lightAnchor.addChild(keyLight)

        let fillLight = DirectionalLight()
        fillLight.light.intensity = FightFighterSceneRules.fillLightIntensity
        fillLight.light.color = SceneLightPalette.previewFill
        fillLight.position = FightFighterSceneRules.fillLightPosition
        fillLight.look(at: FightFighterSceneRules.cameraLookAt, from: fillLight.position, relativeTo: nil)
        lightAnchor.addChild(fillLight)
    }

    private func loadFighter() async {
        do {
            let body = try await Entity(contentsOf: assetURL(for: selection.bodyAsset))
            let modelRoot = Entity()
            modelRoot.position = FightFighterSceneRules.modelPosition
            modelRoot.orientation = modelOrientation
            modelRoot.scale = SIMD3<Float>(repeating: FightFighterSceneRules.modelScale)
            modelRoot.addChild(body)

            contentAnchor.children.removeAll()
            contentAnchor.addChild(modelRoot)

            modelRootEntity = modelRoot
            bodyEntity = body
            weaponMountEntity = nil
            weaponAttachmentEntity = nil
            weaponAttachmentPin = nil
            let rawAttackDuration = (try? await loadAnimationDuration(from: selection.attackAnimationAsset)) ?? 0
            attackAnimationDuration = selection.effectiveAttackAnimationDuration(from: rawAttackDuration)
            isModelLoaded = true
        } catch {
            modelRootEntity = nil
            bodyEntity = nil
            weaponMountEntity = nil
            weaponAttachmentEntity = nil
            weaponAttachmentPin = nil
            attackAnimationDuration = 0
            isModelLoaded = false
        }
    }

    private func updateWeaponAttachment() {
        guard let weaponMountEntity, let modelRootEntity else { return }

        if let weaponAttachmentEntity {
            updateFightFighterWeaponAttachmentTransform(
                for: weaponMountEntity,
                using: weaponAttachmentEntity,
                relativeTo: modelRootEntity
            )
            return
        }

        guard let weaponAttachmentPin else { return }

        updateFightFighterWeaponAttachmentTransform(
            for: weaponMountEntity,
            using: weaponAttachmentPin,
            relativeTo: modelRootEntity
        )
    }

    private func playAnimationAsync(asset: CharacterAsset, repeats: Bool, playbackSpeed: Float) async {
        guard let bodyEntity else { return }

        bodyEntity.stopAllAnimations(recursive: true)
        playbackController = nil

        do {
            let animation = try await loadAnimationResource(from: asset)
            let configured = repeats ? animation.repeat() : animation
            playbackController = bodyEntity.playAnimation(
                configured,
                transitionDuration: 0.15,
                startsPaused: false
            )
            playbackController?.speed = playbackSpeed
        } catch {
        }
    }

    private func loadAnimationResource(from asset: CharacterAsset) async throws -> AnimationResource {
        let animationURL = try assetURL(for: asset)
        let animationEntity = try await Entity(contentsOf: animationURL)

        guard let animation = firstAvailableAnimation(in: animationEntity) else {
            throw ViewerError.noAnimationsFound
        }

        return animation
    }

    private func loadAnimationDuration(from asset: CharacterAsset) async throws -> TimeInterval {
        let animation = try await loadAnimationResource(from: asset)
        return animation.definition.duration
    }

    private func firstAvailableAnimation(in entity: Entity) -> AnimationResource? {
        if let animation = entity.availableAnimations.first {
            return animation
        }

        for child in entity.children {
            if let animation = firstAvailableAnimation(in: child) {
                return animation
            }
        }

        return nil
    }

    private func updateCameraTransform() {
        let rotation = simd_quatf(angle: orbitAngle, axis: SIMD3<Float>(0, 1, 0))
        let baseOffset = FightFighterSceneRules.cameraPosition - FightFighterSceneRules.cameraLookAt
        let rotatedOffset = rotation.act(baseOffset) * zoomFactor
        let cameraPosition = FightFighterSceneRules.cameraLookAt + rotatedOffset

        cameraEntity.position = cameraPosition
        cameraEntity.look(at: FightFighterSceneRules.cameraLookAt, from: cameraPosition, relativeTo: nil)
    }

    private func assetURL(for asset: CharacterAsset) throws -> URL {
        guard let url = Bundle.main.url(
            forResource: asset.assetName,
            withExtension: asset.assetExtension,
            subdirectory: asset.subdirectory
        ) else {
            throw ViewerError.missingAsset(asset.displayName)
        }

        return url
    }
}

private enum FightFighterSceneRules {
    static let modelScale: Float = 0.50
    static let minimumAttackRecoveryDuration: TimeInterval = 0.45
    static let modelPosition = SIMD3<Float>(0.0, -0.8, 0.0)
    static let cameraPosition = SIMD3<Float>(0.0, 1.2, 2.8)
    static let cameraLookAt = SIMD3<Float>(0.0, 0.9, 0.0)
    static let keyLightIntensity: Float = 31_000
    static let keyLightPosition = SIMD3<Float>(1.6, 2.8, 2.0)
    static let fillLightIntensity: Float = 10_500
    static let fillLightPosition = SIMD3<Float>(-1.9, 1.7, 1.5)
    static let minZoomFactor: Float = 0.65
    static let maxZoomFactor: Float = 1.75
}

@MainActor
private struct FightFighterWeaponAttachment {
    let mountEntity: Entity
    let sourceEntity: Entity?
    let pin: GeometricPin?
}

@MainActor
private func attachFightFighterWeaponToBody(_ weapon: Entity, body: Entity, modelRoot: Entity) -> FightFighterWeaponAttachment {
    let weaponMount = makeFightFighterWeaponMount(with: weapon)

    if let socket = findFightFighterAttachmentEntity(in: body, candidates: FightFighterWeaponAttachmentContract.socketEntityCandidates) {
        modelRoot.addChild(weaponMount)
        updateFightFighterWeaponAttachmentTransform(for: weaponMount, using: socket, relativeTo: modelRoot)
        return FightFighterWeaponAttachment(mountEntity: weaponMount, sourceEntity: socket, pin: nil)
    }

    if let attachment = makeResolvedFightFighterWeaponAttachmentPin(on: body) {
        modelRoot.addChild(weaponMount)
        updateFightFighterWeaponAttachmentTransform(for: weaponMount, using: attachment.pin, relativeTo: modelRoot)
        return FightFighterWeaponAttachment(mountEntity: weaponMount, sourceEntity: nil, pin: attachment.pin)
    }

    if let fallback = findFightFighterAttachmentEntity(in: body, candidates: FightFighterWeaponAttachmentContract.fallbackEntityCandidates) {
        modelRoot.addChild(weaponMount)
        updateFightFighterWeaponAttachmentTransform(for: weaponMount, using: fallback, relativeTo: modelRoot)
        return FightFighterWeaponAttachment(mountEntity: weaponMount, sourceEntity: fallback, pin: nil)
    }

    modelRoot.addChild(weaponMount)
    return FightFighterWeaponAttachment(mountEntity: weaponMount, sourceEntity: nil, pin: nil)
}

private enum FightFighterWeaponAttachmentContract {
    static let socketEntityCandidates = WeaponAttachmentContract.socketEntityCandidates
    static let fallbackEntityCandidates = WeaponAttachmentContract.fallbackEntityCandidates
    static let socketPinCandidates = WeaponAttachmentContract.socketPinCandidates
    static let fallbackPinCandidates = WeaponAttachmentContract.fallbackPinCandidates
}

@MainActor
private func findFightFighterAttachmentEntity(in body: Entity, candidates: [String]) -> Entity? {
    findAttachmentEntity(in: body, candidates: candidates)
}

@MainActor
private func makeResolvedFightFighterWeaponAttachmentPin(on body: Entity) -> (pin: GeometricPin, host: Entity, isFallback: Bool)? {
    if let attachment = makeWeaponAttachmentPin(
        on: body,
        pinName: "fightFighterWeaponSocketPin",
        jointNameCandidates: FightFighterWeaponAttachmentContract.socketPinCandidates
    ) {
        return (attachment.pin, attachment.host, false)
    }

    if let attachment = makeWeaponAttachmentPin(
        on: body,
        pinName: "fightFighterWeaponRightHandPin",
        jointNameCandidates: FightFighterWeaponAttachmentContract.fallbackPinCandidates
    ) {
        return (attachment.pin, attachment.host, true)
    }

    return nil
}

@MainActor
private func updateFightFighterWeaponAttachmentTransform(for weaponMount: Entity, using pin: GeometricPin, relativeTo root: Entity) {
    guard
        let position = pin.position(relativeTo: root),
        let orientation = pin.orientation(relativeTo: root)
    else {
        return
    }

    weaponMount.position = position
    weaponMount.orientation = orientation
}

@MainActor
private func updateFightFighterWeaponAttachmentTransform(for weaponMount: Entity, using entity: Entity, relativeTo root: Entity) {
    weaponMount.position = entity.position(relativeTo: root)
    weaponMount.orientation = entity.orientation(relativeTo: root)
}

@MainActor
private func makeFightFighterWeaponMount(with weapon: Entity) -> Entity {
    let weaponMount = Entity()
    weapon.orientation = CharacterPreviewRules.weaponOrientationOffset
    weaponMount.addChild(weapon)
    return weaponMount
}

@MainActor
final class ModelSceneController: ObservableObject {
    @Published private(set) var statusMessage = "Loading model..."
    @Published private(set) var isModelLoaded = false
    @Published private(set) var currentAnimationDescription = "Nothing selected"

    var hasError: Bool {
        errorMessage != nil
    }

    private weak var arView: ARView?
    private let contentAnchor = AnchorEntity()
    private let cameraAnchor = AnchorEntity()
    private let lightAnchor = AnchorEntity()
    private let cameraEntity = PerspectiveCamera()
    private let selection: CharacterSelection
    private var modelRootEntity: Entity?
    private var bodyEntity: Entity?
    private var weaponEntity: Entity?
    private var weaponMountEntity: Entity?
    private var weaponAttachmentPin: GeometricPin?
    private var weaponAttachmentHostEntity: Entity?
    private var attackAnimationDuration: TimeInterval = 0
    private var playbackController: AnimationPlaybackController?
    private var sceneUpdateSubscription: (any Cancellable)?
    private var transientAnimationTask: Task<Void, Never>?
    private var errorMessage: String?
    private var hasLoadedScene = false
    private var orbitAngle: Float = 0
    private var zoomFactor: Float = 1

    init(selection: CharacterSelection) {
        self.selection = selection
    }

    func attach(to arView: ARView) {
        guard self.arView !== arView else { return }

        self.arView = arView
        configureScene(in: arView)

        guard !hasLoadedScene else { return }
        hasLoadedScene = true

        Task {
            await loadConfiguredCharacter()
        }
    }

    func playIdle() {
        transientAnimationTask?.cancel()

        Task {
            await playAnimationAsync(
                title: "Idle",
                asset: selection.idleAnimationAsset,
                repeats: true,
                playbackSpeed: 1
            )
        }
    }

    func playAttack() {
        transientAnimationTask?.cancel()

        Task {
            await playAnimationAsync(
                title: "\(selection.weapon.displayName) Attack",
                asset: selection.attackAnimationAsset,
                repeats: true,
                playbackSpeed: selection.attackAnimationPlaybackSpeed
            )
        }
    }

    func playAttackOnceThenIdle() {
        transientAnimationTask?.cancel()

        transientAnimationTask = Task {
            await playAnimationAsync(
                title: "\(selection.weapon.displayName) Attack",
                asset: selection.attackAnimationAsset,
                repeats: false,
                playbackSpeed: selection.attackAnimationPlaybackSpeed,
                shouldReportMissingModel: false
            )

            guard !Task.isCancelled else { return }

            let delaySeconds = max(
                attackAnimationDuration,
                CharacterPreviewRules.minimumAttackRecoveryDuration
            )
            let delayNanoseconds = UInt64(delaySeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delayNanoseconds)

            guard !Task.isCancelled else { return }

            await playAnimationAsync(
                title: "Idle",
                asset: selection.idleAnimationAsset,
                repeats: true,
                playbackSpeed: 1,
                shouldReportMissingModel: false
            )
        }
    }

    func rotateView(by angleDelta: Float) {
        orbitAngle += angleDelta
        updateCameraTransform()
    }

    func zoomView(by scaleDelta: Float) {
        let adjustedZoom = zoomFactor / scaleDelta
        zoomFactor = min(max(adjustedZoom, CharacterPreviewRules.minZoomFactor), CharacterPreviewRules.maxZoomFactor)
        updateCameraTransform()
    }

    private func configureScene(in arView: ARView) {
        arView.scene.addAnchor(contentAnchor)
        arView.scene.addAnchor(cameraAnchor)
        arView.scene.addAnchor(lightAnchor)

        if cameraEntity.parent == nil {
            cameraAnchor.addChild(cameraEntity)
        }
        updateCameraTransform()

        let keyLight = DirectionalLight()
        keyLight.light.intensity = 35_000
        keyLight.position = SIMD3<Float>(1.6, 2.8, 2.0)
        keyLight.look(at: CharacterPreviewRules.cameraLookAt, from: keyLight.position, relativeTo: nil)
        lightAnchor.addChild(keyLight)
    }

    private func loadConfiguredCharacter() async {
        do {
            let bodyAsset = selection.bodyAsset

            let body = try await Entity(contentsOf: assetURL(for: bodyAsset))
            let modelRoot = Entity()
            modelRoot.position = CharacterPreviewRules.modelPosition
            modelRoot.scale = SIMD3<Float>(repeating: CharacterPreviewRules.modelScale)
            modelRoot.addChild(body)

            contentAnchor.children.removeAll()
            contentAnchor.addChild(modelRoot)

            modelRootEntity = modelRoot
            bodyEntity = body
            weaponEntity = nil
            weaponMountEntity = nil
            weaponAttachmentPin = nil
            weaponAttachmentHostEntity = nil
            let rawAttackDuration = (try? await loadAnimationDuration(from: selection.attackAnimationAsset)) ?? 0
            attackAnimationDuration = selection.effectiveAttackAnimationDuration(from: rawAttackDuration)

            errorMessage = nil
            isModelLoaded = true
            currentAnimationDescription = "Nothing selected"
            statusMessage = "Loaded \(selection.body.displayName) with \(selection.weapon.displayName)"
        } catch {
            modelRootEntity = nil
            bodyEntity = nil
            weaponEntity = nil
            weaponMountEntity = nil
            weaponAttachmentPin = nil
            weaponAttachmentHostEntity = nil
            attackAnimationDuration = 0
            errorMessage = error.localizedDescription
            isModelLoaded = false
            currentAnimationDescription = "Nothing selected"
            statusMessage = "Failed to load character: \(error.localizedDescription)"
        }
    }

    private func playAnimationAsync(
        title: String,
        asset: CharacterAsset,
        repeats: Bool,
        playbackSpeed: Float,
        shouldReportMissingModel: Bool = true
    ) async {
        guard let bodyEntity else {
            if shouldReportMissingModel {
                statusMessage = "Load a model before trying to play an animation."
            }
            return
        }

        bodyEntity.stopAllAnimations(recursive: true)
        playbackController = nil

        do {
            let animationResource = try await loadAnimationResource(from: asset)
            let configuredAnimation = repeats ? animationResource.repeat() : animationResource
            playbackController = bodyEntity.playAnimation(
                configuredAnimation,
                transitionDuration: 0.15,
                startsPaused: false
            )
            playbackController?.speed = playbackSpeed
            errorMessage = nil
            currentAnimationDescription = asset.displayName
            statusMessage = "Playing \(title)"
        } catch {
            errorMessage = error.localizedDescription
            currentAnimationDescription = asset.displayName
            statusMessage = "Failed to play animation: \(error.localizedDescription)"
        }
    }

    private func loadAnimationResource(from asset: CharacterAsset) async throws -> AnimationResource {
        let animationURL = try assetURL(for: asset)
        let animationEntity = try await Entity(contentsOf: animationURL)

        guard let animation = firstAvailableAnimation(in: animationEntity) else {
            throw ViewerError.noAnimationsFound
        }

        return animation
    }

    private func loadAnimationDuration(from asset: CharacterAsset) async throws -> TimeInterval {
        let animation = try await loadAnimationResource(from: asset)
        return animation.definition.duration
    }

    private func firstAvailableAnimation(in entity: Entity) -> AnimationResource? {
        if let animation = entity.availableAnimations.first {
            return animation
        }

        for child in entity.children {
            if let animation = firstAvailableAnimation(in: child) {
                return animation
            }
        }

        return nil
    }

    private func attachWeapon(_ weapon: Entity, to body: Entity) -> String? {
        let attachment = attachWeaponToBody(weapon, body: body)
        weaponEntity = attachment.weaponEntity
        weaponMountEntity = attachment.mountEntity
        weaponAttachmentPin = attachment.pin
        weaponAttachmentHostEntity = attachment.hostEntity
        return attachment.statusMessage
    }

    private func updateWeaponAttachment() {
        guard
            let weaponAttachmentHostEntity,
            let weaponMountEntity,
            let weaponAttachmentPin
        else {
            return
        }

        updateWeaponAttachmentTransform(
            for: weaponMountEntity,
            using: weaponAttachmentPin,
            relativeTo: weaponAttachmentHostEntity
        )
    }

    private func updateCameraTransform() {
        let rotation = simd_quatf(angle: orbitAngle, axis: SIMD3<Float>(0, 1, 0))
        let baseOffset = CharacterPreviewRules.cameraPosition - CharacterPreviewRules.cameraLookAt
        let rotatedOffset = rotation.act(baseOffset) * zoomFactor
        let cameraPosition = CharacterPreviewRules.cameraLookAt + rotatedOffset

        cameraEntity.position = cameraPosition
        cameraEntity.look(
            at: CharacterPreviewRules.cameraLookAt,
            from: cameraPosition,
            relativeTo: nil
        )
    }

    private func assetURL(for asset: CharacterAsset) throws -> URL {
        guard let url = Bundle.main.url(
            forResource: asset.assetName,
            withExtension: asset.assetExtension,
            subdirectory: asset.subdirectory
        ) else {
            throw ViewerError.missingAsset(asset.displayName)
        }

        return url
    }
}

enum ArenaFighterSide {
    case left
    case right
}

@MainActor
final class FightShowdownSceneController: ObservableObject {
    @Published private(set) var statusMessage = "Loading showdown..."
    @Published private(set) var isSceneLoaded = false
    @Published private(set) var leftAttackAnimationDuration: TimeInterval = 0
    @Published private(set) var rightAttackAnimationDuration: TimeInterval = 0

    var onAttackImpact: ((ArenaFighterSide, Int) -> Void)?
    var onAttackCompleted: ((ArenaFighterSide, Int) -> Void)?

    private weak var arView: ARView?
    private let contentAnchor = AnchorEntity()
    private let cameraAnchor = AnchorEntity()
    private let lightAnchor = AnchorEntity()
    private let cameraEntity = PerspectiveCamera()
    private let fighters: [ArenaFighterSide: FighterConfiguration]
    private var runtimes: [ArenaFighterSide: ShowdownRuntime] = [:]
    private var hasLoadedScene = false
    private var orbitAngle: Float = 0
    private var zoomFactor: Float = 1

    init(
        leftCharacter: LibraryCharacter,
        rightCharacter: LibraryCharacter,
        leftModelPosition: SIMD3<Float>,
        rightModelPosition: SIMD3<Float>,
        leftModelOrientation: simd_quatf,
        rightModelOrientation: simd_quatf
    ) {
        fighters = [
            .left: FighterConfiguration(
                character: leftCharacter,
                modelPosition: leftModelPosition,
                modelOrientation: leftModelOrientation
            ),
            .right: FighterConfiguration(
                character: rightCharacter,
                modelPosition: rightModelPosition,
                modelOrientation: rightModelOrientation
            )
        ]
    }

    func attach(to arView: ARView) {
        guard self.arView !== arView else { return }

        self.arView = arView
        configureScene(in: arView)

        guard !hasLoadedScene else { return }
        hasLoadedScene = true

        Task {
            await loadShowdown()
        }
    }

    func playIdle() {
        for side in [ArenaFighterSide.left, .right] {
            playIdle(for: side)
        }
    }

    func playAttackOnceThenIdle(for side: ArenaFighterSide, attackID: Int) {
        guard
            let runtime = runtimes[side],
            let opponentRuntime = runtimes[side.opponent]
        else {
            return
        }

        runtime.transientAnimationTask?.cancel()
        runtime.activeAttackID = attackID
        runtime.isAttackActive = true
        runtime.hasRegisteredHitForCurrentAttack = false
        runtime.transientAnimationTask = Task {
            defer {
                completeAttack(for: side, attackID: attackID)
            }

            animateApproach(for: runtime, toward: opponentRuntime, side: side)

            await playAnimationAsync(
                on: runtime,
                title: "\(runtime.character.selection.weapon.displayName) Attack",
                asset: runtime.character.selection.attackAnimationAsset,
                repeats: false,
                playbackSpeed: runtime.character.selection.attackAnimationPlaybackSpeed
            )

            guard !Task.isCancelled else { return }

            let attackDuration = runtime.attackAnimationDuration
            let recoveryDuration = max(
                attackDuration,
                ShowdownSceneRules.minimumAttackRecoveryDuration
            )
            let impactDelay = attackDuration > 0
                ? attackDuration * ShowdownAttackImpactRules.impactProgress
                : ShowdownAttackImpactRules.fallbackImpactDelay
            let clampedImpactDelay = min(impactDelay, recoveryDuration)

            if clampedImpactDelay > 0 {
                let impactNanoseconds = UInt64(clampedImpactDelay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: impactNanoseconds)
            }

            guard !Task.isCancelled else { return }

            if runtime.isAttackActive,
               runtime.activeAttackID == attackID,
               !runtime.hasRegisteredHitForCurrentAttack {
                runtime.hasRegisteredHitForCurrentAttack = true
                onAttackImpact?(side, attackID)
            }

            let remainingRecoveryDuration = max(recoveryDuration - clampedImpactDelay, 0)
            if remainingRecoveryDuration > 0 {
                let delayNanoseconds = UInt64(remainingRecoveryDuration * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }

            guard !Task.isCancelled else { return }

            move(runtime, to: runtime.basePosition, duration: ShowdownSceneRules.returnMoveDuration)

            await playAnimationAsync(
                on: runtime,
                title: "Idle",
                asset: runtime.character.selection.idleAnimationAsset,
                repeats: true,
                playbackSpeed: 1
            )
        }
    }

    func rotateView(by angleDelta: Float) {
        orbitAngle += angleDelta
        updateCameraTransform()
    }

    func zoomView(by scaleDelta: Float) {
        let adjustedZoom = zoomFactor / scaleDelta
        zoomFactor = min(max(adjustedZoom, CharacterPreviewRules.minZoomFactor), CharacterPreviewRules.maxZoomFactor)
        updateCameraTransform()
    }

    private func playIdle(for side: ArenaFighterSide) {
        guard let runtime = runtimes[side] else { return }

        runtime.transientAnimationTask?.cancel()
        runtime.activeAttackID = nil
        runtime.isAttackActive = false
        runtime.hasRegisteredHitForCurrentAttack = false
        move(runtime, to: runtime.basePosition, duration: ShowdownSceneRules.returnMoveDuration)
        runtime.transientAnimationTask = Task {
            await playAnimationAsync(
                on: runtime,
                title: "Idle",
                asset: runtime.character.selection.idleAnimationAsset,
                repeats: true,
                playbackSpeed: 1
            )
        }
    }

    private func configureScene(in arView: ARView) {
        arView.scene.addAnchor(contentAnchor)
        arView.scene.addAnchor(cameraAnchor)
        arView.scene.addAnchor(lightAnchor)

        if cameraEntity.parent == nil {
            cameraAnchor.addChild(cameraEntity)
        }
        updateCameraTransform()

        let keyLight = DirectionalLight()
        keyLight.light.intensity = ShowdownSceneRules.keyLightIntensity
        keyLight.light.color = SceneLightPalette.fightKey
        keyLight.position = ShowdownSceneRules.keyLightPosition
        keyLight.look(at: ShowdownSceneRules.cameraLookAt, from: keyLight.position, relativeTo: nil)
        lightAnchor.addChild(keyLight)

        let fillLight = DirectionalLight()
        fillLight.light.intensity = ShowdownSceneRules.fillLightIntensity
        fillLight.light.color = SceneLightPalette.fightFill
        fillLight.position = ShowdownSceneRules.fillLightPosition
        fillLight.look(at: ShowdownSceneRules.cameraLookAt, from: fillLight.position, relativeTo: nil)
        lightAnchor.addChild(fillLight)
    }

    private func loadShowdown() async {
        do {
            contentAnchor.children.removeAll()
            runtimes.removeAll()

            let leftRuntime = try await makeRuntime(for: .left)
            let rightRuntime = try await makeRuntime(for: .right)

            contentAnchor.addChild(leftRuntime.rootEntity)
            contentAnchor.addChild(rightRuntime.rootEntity)

            runtimes[.left] = leftRuntime
            runtimes[.right] = rightRuntime

            leftAttackAnimationDuration = leftRuntime.attackAnimationDuration
            rightAttackAnimationDuration = rightRuntime.attackAnimationDuration
            isSceneLoaded = true
            statusMessage = "Showdown ready"
        } catch {
            isSceneLoaded = false
            leftAttackAnimationDuration = 0
            rightAttackAnimationDuration = 0
            statusMessage = "Failed to load showdown: \(error.localizedDescription)"
        }
    }

    private func makeRuntime(for side: ArenaFighterSide) async throws -> ShowdownRuntime {
        guard let fighter = fighters[side] else {
            throw ViewerError.missingAsset("fighter setup")
        }

        let selection = fighter.character.selection
        let body = try await Entity(contentsOf: assetURL(for: selection.bodyAsset))
        let rawAttackDuration = (try? await loadAnimationDuration(from: selection.attackAnimationAsset)) ?? 0
        let attackAnimationDuration = selection.effectiveAttackAnimationDuration(from: rawAttackDuration)

        let root = Entity()
        root.position = fighter.modelPosition
        root.orientation = fighter.modelOrientation
        root.scale = SIMD3<Float>(repeating: ShowdownSceneRules.modelScale)
        root.addChild(body)

        let runtime = ShowdownRuntime(
            character: fighter.character,
            rootEntity: root,
            bodyEntity: body,
            attackAnimationDuration: attackAnimationDuration,
            basePosition: fighter.modelPosition,
            facingOrientation: fighter.modelOrientation
        )

        return runtime
    }

    private func playAnimationAsync(
        on runtime: ShowdownRuntime,
        title: String,
        asset: CharacterAsset,
        repeats: Bool,
        playbackSpeed: Float
    ) async {
        runtime.bodyEntity.stopAllAnimations(recursive: true)
        runtime.playbackController = nil

        do {
            let animationResource = try await loadAnimationResource(from: asset)
            let configuredAnimation = repeats ? animationResource.repeat() : animationResource
            runtime.playbackController = runtime.bodyEntity.playAnimation(
                configuredAnimation,
                transitionDuration: 0.15,
                startsPaused: false
            )
            runtime.playbackController?.speed = playbackSpeed
            statusMessage = "Playing \(title)"
        } catch {
            statusMessage = "Failed to play \(title): \(error.localizedDescription)"
        }
    }

    private func loadAnimationResource(from asset: CharacterAsset) async throws -> AnimationResource {
        let animationURL = try assetURL(for: asset)
        let animationEntity = try await Entity(contentsOf: animationURL)

        guard let animation = firstAvailableAnimation(in: animationEntity) else {
            throw ViewerError.noAnimationsFound
        }

        return animation
    }

    private func loadAnimationDuration(from asset: CharacterAsset) async throws -> TimeInterval {
        let animation = try await loadAnimationResource(from: asset)
        return animation.definition.duration
    }

    private func firstAvailableAnimation(in entity: Entity) -> AnimationResource? {
        if let animation = entity.availableAnimations.first {
            return animation
        }

        for child in entity.children {
            if let animation = firstAvailableAnimation(in: child) {
                return animation
            }
        }

        return nil
    }

    private func completeAttack(for side: ArenaFighterSide, attackID: Int) {
        guard let runtime = runtimes[side], runtime.activeAttackID == attackID else { return }

        let wasActive = runtime.isAttackActive
        runtime.activeAttackID = nil
        runtime.isAttackActive = false
        runtime.hasRegisteredHitForCurrentAttack = false
        runtime.transientAnimationTask = nil

        guard wasActive else { return }
        onAttackCompleted?(side, attackID)
    }

    private func animateApproach(
        for runtime: ShowdownRuntime,
        toward opponentRuntime: ShowdownRuntime,
        side: ArenaFighterSide
    ) {
        let distance = approachDistance(
            attackerWeapon: runtime.character.selection.weapon,
            defenderWeapon: opponentRuntime.character.selection.weapon
        )
        let xOffset: Float = side == .left ? distance : -distance
        move(
            runtime,
            to: runtime.basePosition + SIMD3<Float>(xOffset, 0, 0),
            duration: ShowdownSceneRules.attackAdvanceDuration
        )
    }

    private func move(_ runtime: ShowdownRuntime, to position: SIMD3<Float>, duration: TimeInterval) {
        let transform = Transform(
            scale: SIMD3<Float>(repeating: ShowdownSceneRules.modelScale),
            rotation: runtime.facingOrientation,
            translation: position
        )
        runtime.rootEntity.move(
            to: transform,
            relativeTo: contentAnchor,
            duration: duration,
            timingFunction: .easeInOut
        )
    }

    private func approachDistance(attackerWeapon: WeaponType, defenderWeapon: WeaponType) -> Float {
        max(
            ShowdownSceneRules.baseAdvanceDistance + defenderWeapon.combatReachOffset - attackerWeapon.combatReachOffset,
            ShowdownSceneRules.minimumAdvanceDistance
        )
    }

    private func updateWeaponAttachments() {
        for runtime in runtimes.values {
            guard
                let weaponMount = runtime.weaponMountEntity,
                let armatureEntity = runtime.armatureEntity,
                let weaponJointIndices = runtime.weaponJointIndices
            else {
                continue
            }

            updateShowdownWeaponAttachmentTransform(
                for: weaponMount,
                usingJointIndices: weaponJointIndices,
                on: armatureEntity,
                relativeTo: runtime.rootEntity
            )
        }
    }

    private func updateCameraTransform() {
        let rotation = simd_quatf(angle: orbitAngle, axis: SIMD3<Float>(0, 1, 0))
        let baseOffset = ShowdownSceneRules.cameraPosition - ShowdownSceneRules.cameraLookAt
        let rotatedOffset = rotation.act(baseOffset) * zoomFactor
        let cameraPosition = ShowdownSceneRules.cameraLookAt + rotatedOffset

        cameraEntity.position = cameraPosition
        cameraEntity.look(
            at: ShowdownSceneRules.cameraLookAt,
            from: cameraPosition,
            relativeTo: nil
        )
    }

    private func assetURL(for asset: CharacterAsset) throws -> URL {
        guard let url = Bundle.main.url(
            forResource: asset.assetName,
            withExtension: asset.assetExtension,
            subdirectory: asset.subdirectory
        ) else {
            throw ViewerError.missingAsset(asset.displayName)
        }

        return url
    }
}

private extension FightShowdownSceneController {
    struct FighterConfiguration {
        let character: LibraryCharacter
        let modelPosition: SIMD3<Float>
        let modelOrientation: simd_quatf
    }

    final class ShowdownRuntime {
        let character: LibraryCharacter
        let rootEntity: Entity
        let bodyEntity: Entity
        let attackAnimationDuration: TimeInterval
        let basePosition: SIMD3<Float>
        let facingOrientation: simd_quatf
        var weaponEntity: Entity?
        var weaponMountEntity: Entity?
        var armatureEntity: Entity?
        var weaponJointIndices: [Int]?
        var activeAttackID: Int?
        var isAttackActive = false
        var hasRegisteredHitForCurrentAttack = false
        var playbackController: AnimationPlaybackController?
        var transientAnimationTask: Task<Void, Never>?

        init(
            character: LibraryCharacter,
            rootEntity: Entity,
            bodyEntity: Entity,
            attackAnimationDuration: TimeInterval,
            basePosition: SIMD3<Float>,
            facingOrientation: simd_quatf
        ) {
            self.character = character
            self.rootEntity = rootEntity
            self.bodyEntity = bodyEntity
            self.attackAnimationDuration = attackAnimationDuration
            self.basePosition = basePosition
            self.facingOrientation = facingOrientation
        }
    }
}

private enum ShowdownSceneRules {
    static let modelScale: Float = 0.50
    static let weaponScale: Float = 1.0
    static let weaponGripReferenceOrientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
    static let weaponOrientationOffset = weaponGripReferenceOrientation
    static let minimumAttackRecoveryDuration: TimeInterval = 0.45
    static let baseAdvanceDistance: Float = 0.14
    static let minimumAdvanceDistance: Float = 0.08
    static let attackAdvanceDuration: TimeInterval = 0.16
    static let returnMoveDuration: TimeInterval = 0.18
    static let cameraPosition = SIMD3<Float>(0.0, 1.2, 4.1)
    static let cameraLookAt = SIMD3<Float>(0.0, 0.9, 0.0)
    static let keyLightIntensity: Float = 25_000
    static let keyLightPosition = SIMD3<Float>(2.0, 3.0, 2.4)
    static let fillLightIntensity: Float = 10_500
    static let fillLightPosition = SIMD3<Float>(-2.3, 1.8, 1.6)
    static let minZoomFactor: Float = 0.85
    static let maxZoomFactor: Float = 1.45
}

private enum ShowdownAttackImpactRules {
    static let impactProgress: TimeInterval = 0.5
    static let fallbackImpactDelay: TimeInterval = 0.22
}

private extension ArenaFighterSide {
    var opponent: ArenaFighterSide {
        switch self {
        case .left:
            return .right
        case .right:
            return .left
        }
    }
}

@MainActor
private struct ShowdownWeaponAttachment {
    let weaponEntity: Entity
    let mountEntity: Entity
    let armatureEntity: Entity?
    let jointIndices: [Int]?
}

private enum ShowdownWeaponAttachmentContract {
    static let armatureEntityName = "Armature"
    static let socketJointName = "mixamorig_Hips/mixamorig_Spine/mixamorig_Spine1/mixamorig_Spine2/mixamorig_RightShoulder/mixamorig_RightArm/mixamorig_RightForeArm/mixamorig_RightHand/mixamorig_RightHandThumb1/mixamorig_RightHandThumb2/mixamorig_RightHandThumb3"
    static let fallbackJointName = "mixamorig_Hips/mixamorig_Spine/mixamorig_Spine1/mixamorig_Spine2/mixamorig_RightShoulder/mixamorig_RightArm/mixamorig_RightForeArm/mixamorig_RightHand"
}

@MainActor
private func attachShowdownWeaponToBody(_ weapon: Entity, body: Entity, fighterRoot: Entity) -> ShowdownWeaponAttachment {
    let weaponMount = makeShowdownWeaponMount(with: weapon)
    fighterRoot.addChild(weaponMount)

    if let armatureEntity = findShowdownArmatureEntity(in: body),
       let jointIndices = resolveShowdownWeaponJointIndices(on: armatureEntity) {
        updateShowdownWeaponAttachmentTransform(
            for: weaponMount,
            usingJointIndices: jointIndices,
            on: armatureEntity,
            relativeTo: fighterRoot
        )
        return ShowdownWeaponAttachment(
            weaponEntity: weapon,
            mountEntity: weaponMount,
            armatureEntity: armatureEntity,
            jointIndices: jointIndices
        )
    }

    return ShowdownWeaponAttachment(
        weaponEntity: weapon,
        mountEntity: weaponMount,
        armatureEntity: nil,
        jointIndices: nil
    )
}

@MainActor
private func findShowdownArmatureEntity(in body: Entity) -> Entity? {
    var stack: [Entity] = [body]
    var seen = Set<ObjectIdentifier>()

    while let current = stack.popLast() {
        let id = ObjectIdentifier(current)
        guard seen.insert(id).inserted else { continue }

        if current.name == ShowdownWeaponAttachmentContract.armatureEntityName,
           current.components[SkeletalPosesComponent.self] != nil,
           current.components[ModelComponent.self] != nil {
            return current
        }

        stack.append(contentsOf: current.children)
    }

    return nil
}

@MainActor
private func resolveShowdownWeaponJointIndices(on armatureEntity: Entity) -> [Int]? {
    guard let modelComponent = armatureEntity.components[ModelComponent.self],
          let skeleton = modelComponent.mesh.contents.skeletons.first else {
        return nil
    }

    if let socket = resolveShowdownJointIndices(
        in: skeleton,
        jointName: ShowdownWeaponAttachmentContract.socketJointName
    ) {
        return socket
    }

    return resolveShowdownJointIndices(
        in: skeleton,
        jointName: ShowdownWeaponAttachmentContract.fallbackJointName
    )
}

private func resolveShowdownJointIndices(
    in skeleton: MeshResource.Skeleton,
    jointName: String
) -> [Int]? {
    guard let jointIndex = skeleton.joints.firstIndex(where: { $0.name == jointName }) else {
        return nil
    }

    var indices: [Int] = []
    var currentIndex: Int? = jointIndex

    while let index = currentIndex {
        indices.append(index)
        currentIndex = skeleton.joints[index].parentIndex
    }

    return indices
}

@MainActor
private func updateShowdownWeaponAttachmentTransform(
    for weaponMount: Entity,
    usingJointIndices jointIndices: [Int],
    on armatureEntity: Entity,
    relativeTo rootEntity: Entity
) {
    guard
        let skeletalPoses = armatureEntity.components[SkeletalPosesComponent.self],
        let pose = skeletalPoses.poses.default
    else {
        return
    }

    let jointTransforms = pose.jointTransforms
    guard jointIndices.allSatisfy({ $0 < jointTransforms.count }) else { return }

    let jointMatrix = jointIndices.reduce(matrix_identity_float4x4) { partialResult, index in
        jointTransforms[index].matrix * partialResult
    }

    let armatureMatrix = armatureEntity.transformMatrix(relativeTo: rootEntity)
    weaponMount.setTransformMatrix(armatureMatrix * jointMatrix, relativeTo: rootEntity)
}

@MainActor
private func makeShowdownWeaponMount(with weapon: Entity) -> Entity {
    let weaponMount = Entity()
    weaponMount.scale = SIMD3<Float>(repeating: ShowdownSceneRules.weaponScale)
    weapon.orientation = ShowdownSceneRules.weaponOrientationOffset
    weaponMount.addChild(weapon)
    return weaponMount
}

@MainActor
final class ArenaBattleSceneController: ObservableObject {
    @Published private(set) var statusMessage = "Loading arena..."
    @Published private(set) var isSceneLoaded = false

    private weak var arView: ARView?
    private let contentAnchor = AnchorEntity()
    private let cameraAnchor = AnchorEntity()
    private let lightAnchor = AnchorEntity()
    private let cameraEntity = PerspectiveCamera()
    private let leftCharacter: LibraryCharacter
    private let rightCharacter: LibraryCharacter
    private var runtimes: [ArenaFighterSide: BattleRuntime] = [:]
    private var sceneUpdateSubscription: (any Cancellable)?
    private var hasLoadedScene = false
    private var orbitAngle: Float = 0
    private var zoomFactor: Float = 1

    init(leftCharacter: LibraryCharacter, rightCharacter: LibraryCharacter) {
        self.leftCharacter = leftCharacter
        self.rightCharacter = rightCharacter
    }

    func attach(to arView: ARView) {
        guard self.arView !== arView else { return }

        self.arView = arView
        configureScene(in: arView)

        guard !hasLoadedScene else { return }
        hasLoadedScene = true

        Task {
            await loadArena()
        }
    }

    func rotateView(by angleDelta: Float) {
        orbitAngle += angleDelta
        updateCameraTransform()
    }

    func zoomView(by scaleDelta: Float) {
        let adjustedZoom = zoomFactor / scaleDelta
        zoomFactor = min(max(adjustedZoom, ArenaSceneRules.minZoomFactor), ArenaSceneRules.maxZoomFactor)
        updateCameraTransform()
    }

    func playAttack(for side: ArenaFighterSide) {
        guard
            let runtime = runtimes[side],
            let opponentRuntime = runtimes[side.opponent]
        else {
            return
        }

        runtime.transientAnimationTask?.cancel()
        runtime.transientAnimationTask = Task {
            animateLunge(for: runtime, toward: opponentRuntime, side: side)

            await playAnimationAsync(
                on: runtime,
                title: "\(runtime.character.selection.weapon.displayName) Attack",
                asset: runtime.character.selection.attackAnimationAsset,
                repeats: false,
                playbackSpeed: runtime.character.selection.attackAnimationPlaybackSpeed
            )

            guard !Task.isCancelled else { return }

            let delaySeconds = max(
                runtime.attackAnimationDuration,
                ArenaSceneRules.minimumAttackRecoveryDuration
            )
            let delayNanoseconds = UInt64(delaySeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delayNanoseconds)

            guard !Task.isCancelled else { return }

            move(runtime, to: runtime.basePosition, duration: 0.18)

            await playAnimationAsync(
                on: runtime,
                title: "Idle",
                asset: runtime.character.selection.idleAnimationAsset,
                repeats: true,
                playbackSpeed: 1
            )
        }
    }

    private func configureScene(in arView: ARView) {
        arView.scene.addAnchor(contentAnchor)
        arView.scene.addAnchor(cameraAnchor)
        arView.scene.addAnchor(lightAnchor)

        if cameraEntity.parent == nil {
            cameraAnchor.addChild(cameraEntity)
        }
        updateCameraTransform()

        let keyLight = DirectionalLight()
        keyLight.light.intensity = 29_000
        keyLight.light.color = SceneLightPalette.fightKey
        keyLight.position = SIMD3<Float>(2.2, 3.4, 2.8)
        keyLight.look(at: ArenaSceneRules.cameraLookAt, from: keyLight.position, relativeTo: nil)
        lightAnchor.addChild(keyLight)

        let fillLight = DirectionalLight()
        fillLight.light.intensity = 11_000
        fillLight.light.color = SceneLightPalette.fightFill
        fillLight.position = SIMD3<Float>(-2.4, 1.9, 1.7)
        fillLight.look(at: ArenaSceneRules.cameraLookAt, from: fillLight.position, relativeTo: nil)
        lightAnchor.addChild(fillLight)
    }

    private func loadArena() async {
        do {
            contentAnchor.children.removeAll()
            runtimes.removeAll()

            let leftRuntime = try await makeRuntime(
                for: leftCharacter,
                position: ArenaSceneRules.leftPosition(for: leftCharacter.selection.weapon),
                orientation: ArenaSceneRules.leftOrientation
            )
            let rightRuntime = try await makeRuntime(
                for: rightCharacter,
                position: ArenaSceneRules.rightPosition(for: rightCharacter.selection.weapon),
                orientation: ArenaSceneRules.rightOrientation
            )

            contentAnchor.addChild(leftRuntime.rootEntity)
            contentAnchor.addChild(rightRuntime.rootEntity)

            runtimes[.left] = leftRuntime
            runtimes[.right] = rightRuntime

            isSceneLoaded = true
            statusMessage = "Arena ready"

            await playAnimationAsync(
                on: leftRuntime,
                title: "Idle",
                asset: leftCharacter.selection.idleAnimationAsset,
                repeats: true,
                playbackSpeed: 1
            )
            await playAnimationAsync(
                on: rightRuntime,
                title: "Idle",
                asset: rightCharacter.selection.idleAnimationAsset,
                repeats: true,
                playbackSpeed: 1
            )
        } catch {
            isSceneLoaded = false
            statusMessage = "Failed to load arena: \(error.localizedDescription)"
        }
    }

    private func makeRuntime(
        for character: LibraryCharacter,
        position: SIMD3<Float>,
        orientation: simd_quatf
    ) async throws -> BattleRuntime {
        let selection = character.selection
        let body = try await Entity(contentsOf: assetURL(for: selection.bodyAsset))
        let rawAttackDuration = (try? await loadAnimationDuration(from: selection.attackAnimationAsset)) ?? 0
        let root = Entity()
        root.position = position
        root.orientation = orientation
        root.scale = SIMD3<Float>(repeating: CharacterPreviewRules.modelScale)
        root.addChild(body)

        let runtime = BattleRuntime(
            character: character,
            rootEntity: root,
            bodyEntity: body,
            attackAnimationDuration: selection.effectiveAttackAnimationDuration(from: rawAttackDuration),
            basePosition: position,
            facingOrientation: orientation
        )

        return runtime
    }

    private func playAnimationAsync(
        on runtime: BattleRuntime,
        title: String,
        asset: CharacterAsset,
        repeats: Bool,
        playbackSpeed: Float
    ) async {
        runtime.bodyEntity.stopAllAnimations(recursive: true)
        runtime.playbackController = nil

        do {
            let animationResource = try await loadAnimationResource(from: asset)
            let configuredAnimation = repeats ? animationResource.repeat() : animationResource
            runtime.playbackController = runtime.bodyEntity.playAnimation(
                configuredAnimation,
                transitionDuration: 0.15,
                startsPaused: false
            )
            runtime.playbackController?.speed = playbackSpeed
            statusMessage = "Playing \(title)"
        } catch {
            statusMessage = "Failed to play \(title): \(error.localizedDescription)"
        }
    }

    private func animateLunge(
        for runtime: BattleRuntime,
        toward opponentRuntime: BattleRuntime,
        side: ArenaFighterSide
    ) {
        let distance = max(
            ArenaSceneRules.baseAdvanceDistance
                + opponentRuntime.character.selection.weapon.combatReachOffset
                - runtime.character.selection.weapon.combatReachOffset,
            ArenaSceneRules.minimumAdvanceDistance
        )
        let xOffset: Float = side == .left ? distance : -distance
        move(runtime, to: runtime.basePosition + SIMD3<Float>(xOffset, 0, 0), duration: ArenaSceneRules.attackAdvanceDuration)
    }

    private func move(_ runtime: BattleRuntime, to position: SIMD3<Float>, duration: TimeInterval) {
        let transform = Transform(
            scale: SIMD3<Float>(repeating: CharacterPreviewRules.modelScale),
            rotation: runtime.facingOrientation,
            translation: position
        )
        runtime.rootEntity.move(
            to: transform,
            relativeTo: contentAnchor,
            duration: duration,
            timingFunction: .easeInOut
        )
    }

    private func loadAnimationResource(from asset: CharacterAsset) async throws -> AnimationResource {
        let animationURL = try assetURL(for: asset)
        let animationEntity = try await Entity(contentsOf: animationURL)

        guard let animation = firstAvailableAnimation(in: animationEntity) else {
            throw ViewerError.noAnimationsFound
        }

        return animation
    }

    private func loadAnimationDuration(from asset: CharacterAsset) async throws -> TimeInterval {
        let animation = try await loadAnimationResource(from: asset)
        return animation.definition.duration
    }

    private func firstAvailableAnimation(in entity: Entity) -> AnimationResource? {
        if let animation = entity.availableAnimations.first {
            return animation
        }

        for child in entity.children {
            if let animation = firstAvailableAnimation(in: child) {
                return animation
            }
        }

        return nil
    }

    private func attachWeapon(_ weapon: Entity, to body: Entity, runtime: BattleRuntime) -> String? {
        let attachment = attachBattleWeaponToBody(weapon, body: body, fighterRoot: runtime.rootEntity)
        runtime.weaponEntity = attachment.weaponEntity
        runtime.weaponMountEntity = attachment.mountEntity
        runtime.weaponAttachmentEntity = attachment.sourceEntity
        runtime.weaponAttachmentPin = attachment.pin
        return attachment.statusMessage
    }

    private func updateWeaponAttachments() {
        for runtime in runtimes.values {
            guard let weaponMount = runtime.weaponMountEntity else {
                continue
            }

            if let sourceEntity = runtime.weaponAttachmentEntity {
                updateBattleWeaponAttachmentTransform(
                    for: weaponMount,
                    using: sourceEntity,
                    relativeTo: runtime.rootEntity
                )
                continue
            }

            guard let pin = runtime.weaponAttachmentPin else { continue }

            updateBattleWeaponAttachmentTransform(
                for: weaponMount,
                using: pin,
                relativeTo: runtime.rootEntity
            )
        }
    }

    private func updateCameraTransform() {
        let rotation = simd_quatf(angle: orbitAngle, axis: SIMD3<Float>(0, 1, 0))
        let baseOffset = ArenaSceneRules.cameraPosition - ArenaSceneRules.cameraLookAt
        let rotatedOffset = rotation.act(baseOffset) * zoomFactor
        let cameraPosition = ArenaSceneRules.cameraLookAt + rotatedOffset

        cameraEntity.position = cameraPosition
        cameraEntity.look(
            at: ArenaSceneRules.cameraLookAt,
            from: cameraPosition,
            relativeTo: nil
        )
    }

    private func assetURL(for asset: CharacterAsset) throws -> URL {
        guard let url = Bundle.main.url(
            forResource: asset.assetName,
            withExtension: asset.assetExtension,
            subdirectory: asset.subdirectory
        ) else {
            throw ViewerError.missingAsset(asset.displayName)
        }

        return url
    }
}

private extension ArenaBattleSceneController {
    final class BattleRuntime {
        let character: LibraryCharacter
        let rootEntity: Entity
        let bodyEntity: Entity
        let attackAnimationDuration: TimeInterval
        let basePosition: SIMD3<Float>
        let facingOrientation: simd_quatf
        var weaponEntity: Entity?
        var weaponMountEntity: Entity?
        var weaponAttachmentEntity: Entity?
        var weaponAttachmentPin: GeometricPin?
        var playbackController: AnimationPlaybackController?
        var transientAnimationTask: Task<Void, Never>?

        init(
            character: LibraryCharacter,
            rootEntity: Entity,
            bodyEntity: Entity,
            attackAnimationDuration: TimeInterval,
            basePosition: SIMD3<Float>,
            facingOrientation: simd_quatf
        ) {
            self.character = character
            self.rootEntity = rootEntity
            self.bodyEntity = bodyEntity
            self.attackAnimationDuration = attackAnimationDuration
            self.basePosition = basePosition
            self.facingOrientation = facingOrientation
        }
    }
}

@MainActor
private struct BattleWeaponAttachment {
    let weaponEntity: Entity
    let mountEntity: Entity
    let sourceEntity: Entity?
    let pin: GeometricPin?
    let statusMessage: String?
}

@MainActor
private func attachBattleWeaponToBody(_ weapon: Entity, body: Entity, fighterRoot: Entity) -> BattleWeaponAttachment {
    let weaponMount = makeBattleWeaponMount(with: weapon)

    if let socket = findAttachmentEntity(in: body, candidates: WeaponAttachmentContract.socketEntityCandidates) {
        fighterRoot.addChild(weaponMount)
        updateBattleWeaponAttachmentTransform(for: weaponMount, using: socket, relativeTo: fighterRoot)
        return BattleWeaponAttachment(
            weaponEntity: weapon,
            mountEntity: weaponMount,
            sourceEntity: socket,
            pin: nil,
            statusMessage: nil
        )
    }

    if let attachment = makeResolvedBattleWeaponAttachmentPin(on: body) {
        fighterRoot.addChild(weaponMount)
        updateBattleWeaponAttachmentTransform(for: weaponMount, using: attachment.pin, relativeTo: fighterRoot)
        return BattleWeaponAttachment(
            weaponEntity: weapon,
            mountEntity: weaponMount,
            sourceEntity: nil,
            pin: attachment.pin,
            statusMessage: attachment.isFallback
                ? "Weapon socket entity missing, attached with right-hand pin."
                : nil
        )
    }

    if let fallback = findAttachmentEntity(in: body, candidates: WeaponAttachmentContract.fallbackEntityCandidates) {
        fighterRoot.addChild(weaponMount)
        updateBattleWeaponAttachmentTransform(for: weaponMount, using: fallback, relativeTo: fighterRoot)
        return BattleWeaponAttachment(
            weaponEntity: weapon,
            mountEntity: weaponMount,
            sourceEntity: fallback,
            pin: nil,
            statusMessage: "Weapon socket pin missing, attached to right hand."
        )
    }

    fighterRoot.addChild(weaponMount)
    return BattleWeaponAttachment(
        weaponEntity: weapon,
        mountEntity: weaponMount,
        sourceEntity: nil,
        pin: nil,
        statusMessage: "Weapon socket could not be resolved."
    )
}

@MainActor
private func makeResolvedBattleWeaponAttachmentPin(on body: Entity) -> (pin: GeometricPin, isFallback: Bool)? {
    if let attachment = makeWeaponAttachmentPin(
        on: body,
        pinName: "battleWeaponSocketPin",
        jointNameCandidates: WeaponAttachmentContract.socketPinCandidates
    ) {
        return (attachment.pin, false)
    }

    if let attachment = makeWeaponAttachmentPin(
        on: body,
        pinName: "battleWeaponRightHandPin",
        jointNameCandidates: WeaponAttachmentContract.fallbackPinCandidates
    ) {
        return (attachment.pin, true)
    }

    return nil
}

@MainActor
private func updateBattleWeaponAttachmentTransform(for weaponMount: Entity, using pin: GeometricPin, relativeTo root: Entity) {
    guard
        let position = pin.position(relativeTo: root),
        let orientation = pin.orientation(relativeTo: root)
    else {
        return
    }

    weaponMount.position = position
    weaponMount.orientation = orientation
}

@MainActor
private func updateBattleWeaponAttachmentTransform(for weaponMount: Entity, using entity: Entity, relativeTo root: Entity) {
    weaponMount.position = entity.position(relativeTo: root)
    weaponMount.orientation = entity.orientation(relativeTo: root)
}

@MainActor
private struct WeaponAttachment {
    let weaponEntity: Entity
    let mountEntity: Entity
    let pin: GeometricPin?
    let hostEntity: Entity?
    let statusMessage: String?
}

@MainActor
private func attachWeaponToBody(_ weapon: Entity, body: Entity) -> WeaponAttachment {
    let weaponMount = makeWeaponMount(with: weapon)

    if let socket = findAttachmentEntity(in: body, candidates: WeaponAttachmentContract.socketEntityCandidates) {
        socket.addChild(weaponMount)
        return WeaponAttachment(
            weaponEntity: weapon,
            mountEntity: weaponMount,
            pin: nil,
            hostEntity: nil,
            statusMessage: nil
        )
    }

    if let fallback = findAttachmentEntity(in: body, candidates: WeaponAttachmentContract.fallbackEntityCandidates) {
        fallback.addChild(weaponMount)
        return WeaponAttachment(
            weaponEntity: weapon,
            mountEntity: weaponMount,
            pin: nil,
            hostEntity: nil,
            statusMessage: "Weapon socket not found, attached to right hand instead."
        )
    }

    if let attachment = makeResolvedWeaponAttachmentPin(on: body) {
        attachment.host.addChild(weaponMount)
        updateWeaponAttachmentTransform(for: weaponMount, using: attachment.pin, relativeTo: attachment.host)
        return WeaponAttachment(
            weaponEntity: weapon,
            mountEntity: weaponMount,
            pin: attachment.pin,
            hostEntity: attachment.host,
            statusMessage: attachment.isFallback
                ? "Weapon socket entity not found, attached with right-hand pin instead."
                : nil
        )
    }

    body.addChild(weaponMount)
    return WeaponAttachment(
        weaponEntity: weapon,
        mountEntity: weaponMount,
        pin: nil,
        hostEntity: nil,
        statusMessage: "Weapon socket not found, attached to the body root instead."
    )
}

@MainActor
private func makeResolvedWeaponAttachmentPin(on body: Entity) -> (pin: GeometricPin, host: Entity, isFallback: Bool)? {
    if let attachment = makeWeaponAttachmentPin(
        on: body,
        pinName: WeaponAttachmentContract.socketPinName,
        jointNameCandidates: WeaponAttachmentContract.socketPinCandidates
    ) {
        return (attachment.pin, attachment.host, false)
    }

    if let attachment = makeWeaponAttachmentPin(
        on: body,
        pinName: WeaponAttachmentContract.fallbackPinName,
        jointNameCandidates: WeaponAttachmentContract.fallbackPinCandidates
    ) {
        return (attachment.pin, attachment.host, true)
    }

    return nil
}

@MainActor
private func makeWeaponAttachmentPin(
    on body: Entity,
    pinName: String,
    jointNameCandidates: [String]
) -> (pin: GeometricPin, host: Entity)? {
    for host in attachmentPinHosts(in: body) {
        host.pins.remove(named: pinName)

        for jointName in jointNameCandidates {
            let pin = host.pins.set(named: pinName, skeletalJointName: jointName)

            if pin.position(relativeTo: host) != nil, pin.orientation(relativeTo: host) != nil {
                return (pin, host)
            }

            host.pins.remove(named: pinName)
        }
    }

    return nil
}

@MainActor
private func attachmentPinHosts(in body: Entity) -> [Entity] {
    let descendants = allDescendants(in: body)
    let armatureHosts = descendants.filter { WeaponAttachmentContract.pinHostEntityCandidates.contains($0.name) }

    return armatureHosts.isEmpty ? descendants : armatureHosts
}

@MainActor
private func allDescendants(in body: Entity) -> [Entity] {
    var entities: [Entity] = []
    var stack: [Entity] = [body]
    var seen = Set<ObjectIdentifier>()

    while let current = stack.popLast() {
        let id = ObjectIdentifier(current)
        guard seen.insert(id).inserted else { continue }

        entities.append(current)
        stack.append(contentsOf: current.children)
    }

    return entities
}

@MainActor
private func updateWeaponAttachmentTransform(for weaponMount: Entity, using pin: GeometricPin, relativeTo body: Entity) {
    guard
        let position = pin.position(relativeTo: body),
        let orientation = pin.orientation(relativeTo: body)
    else {
        return
    }

    weaponMount.position = position
    weaponMount.orientation = orientation
    weaponMount.scale = SIMD3<Float>(repeating: CharacterPreviewRules.weaponScale)
}

@MainActor
private func findAttachmentEntity(in body: Entity, candidates: [String]) -> Entity? {
    for candidate in candidates {
        if let entity = body.findEntity(named: candidate) {
            return entity
        }
    }

    return nil
}

private enum ArenaSceneRules {
    static let leftOrientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 1, 0))
    static let rightOrientation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(0, 1, 0))
    static let minimumAttackRecoveryDuration: TimeInterval = 0.45
    static let baseAdvanceDistance: Float = 0.14
    static let minimumAdvanceDistance: Float = 0.08
    static let attackAdvanceDuration: TimeInterval = 0.16
    static let cameraPosition = SIMD3<Float>(0.0, 1.2, 4.1)
    static let cameraLookAt = SIMD3<Float>(0.0, 0.9, 0.0)
    static let minZoomFactor: Float = 0.85
    static let maxZoomFactor: Float = 1.45

    static func leftPosition(for weapon: WeaponType) -> SIMD3<Float> {
        SIMD3<Float>(-(0.78 + weapon.combatReachOffset), -0.8, 0.0)
    }

    static func rightPosition(for weapon: WeaponType) -> SIMD3<Float> {
        SIMD3<Float>(0.78 + weapon.combatReachOffset, -0.8, 0.0)
    }
}

private enum SceneLightPalette {
    static let previewKey = UIColor(red: 1.0, green: 0.94, blue: 0.82, alpha: 1.0)
    static let previewFill = UIColor(red: 1.0, green: 0.98, blue: 0.90, alpha: 1.0)
    static let fightKey = UIColor(red: 1.0, green: 0.92, blue: 0.78, alpha: 1.0)
    static let fightFill = UIColor(red: 1.0, green: 0.97, blue: 0.86, alpha: 1.0)
}

private enum WeaponAttachmentContract {
    static let socketPinName = "weaponSocketPin"
    static let fallbackPinName = "weaponRightHandPin"
    static let pinHostEntityCandidates = ["Armature"]

    static let rightHandPath = [
        "mixamorig:Hips",
        "mixamorig:Spine",
        "mixamorig:Spine1",
        "mixamorig:Spine2",
        "mixamorig:RightShoulder",
        "mixamorig:RightArm",
        "mixamorig:RightForeArm",
        "mixamorig:RightHand"
    ]

    static let rightHandThumb3Path = rightHandPath + [
        "mixamorig:RightHandThumb1",
        "mixamorig:RightHandThumb2",
        "mixamorig:RightHandThumb3"
    ]

    static let socketEntityCandidates = orderedUnique([
        CharacterPreviewRules.weaponSocketBoneName,
        usdSafe(CharacterPreviewRules.weaponSocketBoneName),
        rightHandThumb3Path.last ?? CharacterPreviewRules.weaponSocketBoneName,
        usdSafe(rightHandThumb3Path.last ?? CharacterPreviewRules.weaponSocketBoneName)
    ])

    static let fallbackEntityCandidates = orderedUnique([
        CharacterPreviewRules.weaponFallbackBoneName,
        usdSafe(CharacterPreviewRules.weaponFallbackBoneName),
        rightHandPath.last ?? CharacterPreviewRules.weaponFallbackBoneName,
        usdSafe(rightHandPath.last ?? CharacterPreviewRules.weaponFallbackBoneName)
    ])

    static let socketPinCandidates = jointNameCandidates(
        contractName: CharacterPreviewRules.weaponSocketBoneName,
        contractPath: rightHandThumb3Path
    )

    static let fallbackPinCandidates = jointNameCandidates(
        contractName: CharacterPreviewRules.weaponFallbackBoneName,
        contractPath: rightHandPath
    )

    private static func jointNameCandidates(contractName: String, contractPath: [String]) -> [String] {
        let usdSafeName = usdSafe(contractName)
        let path = contractPath.joined(separator: "/")
        let usdSafePath = contractPath.map(usdSafe).joined(separator: "/")

        return orderedUnique([
            path,
            usdSafePath,
            contractName,
            usdSafeName
        ])
    }

    private static func usdSafe(_ value: String) -> String {
        value.replacingOccurrences(of: ":", with: "_")
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()

        return values.filter { seen.insert($0).inserted }
    }
}

@MainActor
private func makeCharacterPreviewWeaponMount(with weapon: Entity) -> Entity {
    let weaponMount = Entity()
    weapon.orientation = CharacterPreviewRules.weaponOrientationOffset
    weaponMount.addChild(weapon)
    return weaponMount
}

@MainActor
private func makeBattleWeaponMount(with weapon: Entity) -> Entity {
    let weaponMount = Entity()
    weapon.orientation = CharacterPreviewRules.weaponOrientationOffset
    weaponMount.addChild(weapon)
    return weaponMount
}

@MainActor
private func makeWeaponMount(with weapon: Entity) -> Entity {
    let weaponMount = Entity()
    weaponMount.scale = SIMD3<Float>(repeating: CharacterPreviewRules.weaponScale)
    let weaponOffset = Entity()
    let localTransform = makeWeaponLocalTransform(for: weapon)
    weaponOffset.position = localTransform.translation
    weaponOffset.orientation = localTransform.rotation
    weaponOffset.addChild(weapon)
    weaponMount.addChild(weaponOffset)
    return weaponMount
}

@MainActor
private func makeWeaponLocalTransform(for weapon: Entity) -> Transform {
    let bounds = weapon.visualBounds(relativeTo: weapon)
    let gripPoint = bounds.center - SIMD3<Float>(0, 0, bounds.extents.z * 0.5)
    let referenceGrip = CharacterPreviewRules.weaponGripReferenceOrientation.act(gripPoint)
    let targetGrip = CharacterPreviewRules.weaponOrientationOffset.act(gripPoint)
    let translation = referenceGrip - targetGrip

    return Transform(
        scale: .one,
        rotation: CharacterPreviewRules.weaponOrientationOffset,
        translation: translation
    )
}

private enum ViewerError: LocalizedError {
    case missingAsset(String)
    case noAnimationsFound

    var errorDescription: String? {
        switch self {
        case let .missingAsset(fileName):
            return "Could not find \(fileName) inside the Models folder."
        case .noAnimationsFound:
            return "No animations were found in the selected USD asset."
        }
    }
}
