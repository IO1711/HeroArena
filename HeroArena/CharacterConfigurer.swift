import Foundation
import SwiftUI
import simd

enum BodyType: String, CaseIterable {
    case orc
    case knight
    case elf

    var displayName: String {
        switch self {
        case .orc:
            return "Orc"
        case .knight:
            return "Knight"
        case .elf:
            return "Elf"
        }
    }

    var maxHealth: Int {
        switch self {
        case .orc:
            return 70
        case .knight:
            return 45
        case .elf:
            return 40
        }
    }

    var attackSpeed: Double {
        switch self {
        case .orc:
            return 0.9
        case .knight:
            return 1.0
        case .elf:
            return 1.3
        }
    }

    var accentColor: Color {
        switch self {
        case .orc:
            return .orange
        case .knight:
            return .blue
        case .elf:
            return .green
        }
    }

    fileprivate func baseModelAsset(for weapon: WeaponType) -> CharacterAsset {
        CharacterAsset(
            subdirectory: CharacterPreviewRules.modelsSubdirectory,
            assetName: "\(rawValue)_idle_\(weapon.rawValue)",
            assetExtension: "usdc"
        )
    }

    fileprivate func idleAnimationAsset(for weapon: WeaponType) -> CharacterAsset {
        baseModelAsset(for: weapon)
    }

    fileprivate func attackAnimationAsset(for weapon: WeaponType) -> CharacterAsset {
        CharacterAsset(
            subdirectory: CharacterPreviewRules.modelsSubdirectory,
            assetName: "\(rawValue)_\(weapon.rawValue)_attack",
            assetExtension: "usdc"
        )
    }
}

enum WeaponType: String, CaseIterable {
    case sword
    case axe
    case spear
    case mace

    var displayName: String {
        rawValue.capitalized
    }

    var damage: Int {
        switch self {
        case .sword:
            return 10
        case .axe:
            return 14
        case .spear:
            return 9
        case .mace:
            return 11
        }
    }

    var attackRate: Double {
        switch self {
        case .sword:
            return 1.0
        case .axe:
            return 0.7
        case .spear:
            return 1.2
        case .mace:
            return 0.9
        }
    }

    var attackInterval: Double {
        1.0 / attackRate
    }

    var combatReachOffset: Float {
        switch self {
        case .spear:
            return 0.12
        case .sword, .axe, .mace:
            return 0
        }
    }
}

struct CharacterAsset {
    let subdirectory: String
    let assetName: String
    let assetExtension: String

    var displayName: String {
        "\(assetName).\(assetExtension)"
    }
}

struct ConfiguredCharacterDefinition {
    let name: String
    let body: BodyType
    let weapon: WeaponType
    let specialSkill: CharacterSpecialSkill

    init(
        name: String,
        body: BodyType,
        weapon: WeaponType,
        specialSkill: @escaping CharacterSpecialSkill = CharacterSpecialSkills.none
    ) {
        self.name = name
        self.body = body
        self.weapon = weapon
        self.specialSkill = specialSkill
    }
}

struct CharacterSelection {
    let body: BodyType
    let weapon: WeaponType

    var loadoutDescription: String {
        "\(body.displayName) with \(weapon.displayName)"
    }

    var bodyAsset: CharacterAsset {
        body.baseModelAsset(for: weapon)
    }

    var idleAnimationAsset: CharacterAsset {
        body.idleAnimationAsset(for: weapon)
    }

    var attackAnimationAsset: CharacterAsset {
        body.attackAnimationAsset(for: weapon)
    }

    var attackAnimationPlaybackSpeed: Float {
        Float(body.attackSpeed)
    }

    func effectiveAttackAnimationDuration(from sourceDuration: TimeInterval) -> TimeInterval {
        guard attackAnimationPlaybackSpeed > 0 else {
            return sourceDuration
        }

        return sourceDuration / Double(attackAnimationPlaybackSpeed)
    }

    var combatStats: CombatStats {
        CombatStats(
            maxHealth: body.maxHealth,
            damage: weapon.damage,
            attackRate: weapon.attackRate * body.attackSpeed
        )
    }
}

struct CombatStats {
    let maxHealth: Int
    let damage: Int
    let attackRate: Double

    var attackInterval: Double {
        1.0 / attackRate
    }

    var damagePerSecond: Double {
        Double(damage) * attackRate
    }
}

struct LibraryCharacter: Identifiable {
    let id: String
    let name: String
    let role: String
    let summary: String
    let accentColor: Color
    let selection: CharacterSelection
    let specialSkill: CharacterSpecialSkill

    var previewSummary: String {
        "\(role). \(summary)"
    }

    var combatStats: CombatStats {
        selection.combatStats
    }
}

enum CharacterLibrary {
    static let characters: [LibraryCharacter] = configuredCharacters.enumerated().map { index, definition in
        LibraryCharacter(configuration: definition, index: index)
    }
}

enum CharacterPreviewRules {
    static let modelsSubdirectory = "Models"
    static let weaponSubdirectory = "Models/weapon"
    static let weaponSocketBoneName = "mixamorig:RightHandThumb3"
    static let weaponFallbackBoneName = "mixamorig:RightHand"

    static let modelScale: Float = 0.50
    static let weaponScale: Float = 1.0
    static let weaponGripReferenceOrientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
    static let weaponOrientationOffset = weaponGripReferenceOrientation
    static let minimumAttackRecoveryDuration: TimeInterval = 0.45
    static let modelPosition = SIMD3<Float>(0.0, -0.8, 0.0)
    static let cameraPosition = SIMD3<Float>(0.0, 1.2, 2.8)
    static let cameraLookAt = SIMD3<Float>(0.0, 0.9, 0.0)
    static let minZoomFactor: Float = 0.65
    static let maxZoomFactor: Float = 1.75
}

struct CharacterConfigurerView: View {
    private let selection: CharacterSelection
    private let title: String
    private let subtitle: String
    @StateObject private var sceneController: CharacterPreviewSceneController

    init(
        selection: CharacterSelection,
        title: String = "Character Preview",
        subtitle: String = "Preview the active body and weapon configuration."
    ) {
        self.selection = selection
        self.title = title
        self.subtitle = subtitle
        _sceneController = StateObject(wrappedValue: CharacterPreviewSceneController(selection: selection))
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.largeTitle.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            CharacterPreviewViewerView(controller: sceneController)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Loadout", value: selection.loadoutDescription)
                LabeledContent("Body", value: selection.body.displayName)
                LabeledContent("Weapon", value: selection.weapon.displayName)
                LabeledContent("Base Model", value: selection.bodyAsset.displayName)
                LabeledContent("Attack Animation", value: selection.attackAnimationAsset.displayName)
                LabeledContent("Animation", value: sceneController.currentAnimationDescription)
                Text(sceneController.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(sceneController.hasError ? .red : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button("Play Idle") {
                    sceneController.playIdle()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!sceneController.isModelLoaded)

                Button("Play Attack") {
                    sceneController.playAttack()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!sceneController.isModelLoaded)
            }
        }
        .padding(24)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

struct CharacterConfigurerView_Previews: PreviewProvider {
    static var previews: some View {
        CharacterConfigurerView(
            selection: CharacterSelection(body: .orc, weapon: .mace)
        )
    }
}

private extension LibraryCharacter {
    init(configuration: ConfiguredCharacterDefinition, index: Int) {
        let trimmedName = configuration.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? "Configured Hero \(index + 1)" : trimmedName

        self.init(
            id: "configured-\(index)",
            name: resolvedName,
            role: "Configured Fighter",
            summary: "\(configuration.body.displayName) body with \(configuration.weapon.displayName) weapon.",
            accentColor: configuration.body.accentColor,
            selection: CharacterSelection(body: configuration.body, weapon: configuration.weapon),
            specialSkill: configuration.specialSkill
        )
    }
}
