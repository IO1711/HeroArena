import Foundation
import SwiftUI
import simd

struct ContentView: View {
    var body: some View {
        NavigationStack {
            HomeMenuView()
        }
    }
}

private struct HomeMenuView: View {
    var body: some View {
        let characters = CharacterLibrary.characters

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hero Arena")
                        .font(.largeTitle.weight(.bold))
                    Text("Choose a destination to browse your configured roster, run a duel, or preview a fighter.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    NavigationLink {
                        CharacterCollectionView(characters: characters)
                    } label: {
                        HomeMenuCard(
                            title: "Collection",
                            subtitle: "Browse only the fighters you configured.",
                            systemImage: "square.grid.2x2.fill",
                            tint: .orange
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        FightArenaView(characters: characters)
                    } label: {
                        HomeMenuCard(
                            title: "Fight",
                            subtitle: "Pick two configured heroes and watch their body and weapon stats decide the duel.",
                            systemImage: "figure.2.and.child.holdinghands",
                            tint: .red
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        if let previewCharacter = characters.first {
                            CharacterConfigurerView(
                                selection: previewCharacter.selection,
                                title: previewCharacter.name,
                                subtitle: "Previewing the first fighter from CharacterRosterConfiguration.swift."
                            )
                        } else {
                            ConfiguredRosterEmptyStateView(
                                title: "No Preview Fighter",
                                message: "Add a fighter to CharacterRosterConfiguration.swift to enable character preview.",
                                systemImage: "figure.stand"
                            )
                        }
                    } label: {
                        HomeMenuCard(
                            title: "Char Preview",
                            subtitle: "Open the first configured fighter immediately.",
                            systemImage: "figure.stand",
                            tint: .teal
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(uiColor: .systemGroupedBackground),
                    Color.orange.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Home")
    }
}

private struct CharacterCollectionView: View {
    let characters: [LibraryCharacter]
    private let columns = [
        GridItem(.adaptive(minimum: 210, maximum: 300), spacing: 14)
    ]

    var body: some View {
        Group {
            if characters.isEmpty {
                ConfiguredRosterEmptyStateView(
                    title: "No Configured Fighters",
                    message: "Add entries to CharacterRosterConfiguration.swift to populate the collection.",
                    systemImage: "person.3.sequence.fill"
                )
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(characters) { character in
                            NavigationLink {
                                CharacterConfigurerView(
                                    selection: character.selection,
                                    title: character.name,
                                    subtitle: character.previewSummary
                                )
                            } label: {
                                LibraryCharacterCard(character: character)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(24)
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Collection")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ConfiguredRosterEmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(28)
        .frame(maxWidth: 520)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.orange.opacity(0.14), lineWidth: 1)
        }
    }
}

private struct FightConfiguredRosterEmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.2.and.child.holdinghands")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(28)
        .frame(maxWidth: 560)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct FightArenaView: View {
    let characters: [LibraryCharacter]
    @StateObject private var arenaController = FightArenaController()

    var body: some View {
        ZStack {
            if arenaController.isShowingShowdown, arenaController.selectedCharacters.count == 2 {
                FightShowdownView(
                    leftCharacter: arenaController.selectedCharacters[0],
                    rightCharacter: arenaController.selectedCharacters[1],
                    arenaController: arenaController
                )
                .id(arenaController.matchID)
            } else {
                FightSelectionScreen(
                    characters: characters,
                    arenaController: arenaController
                )
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.09, blue: 0.08),
                    Color(red: 0.28, green: 0.12, blue: 0.08),
                    Color(red: 0.46, green: 0.20, blue: 0.11)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Fight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(arenaController.isShowingShowdown ? .hidden : .visible, for: .navigationBar)
        .arenaLandscape()
        .onDisappear {
            arenaController.cancelFight()
        }
    }
}

private struct FightSelectionScreen: View {
    let characters: [LibraryCharacter]
    @ObservedObject var arenaController: FightArenaController

    var body: some View {
        GeometryReader { geometry in
            if characters.isEmpty {
                ScrollView(.vertical) {
                    FightConfiguredRosterEmptyStateView(
                        title: "No Fighters Configured",
                        message: "Add entries to CharacterRosterConfiguration.swift before opening the arena."
                    )
                    .padding(24)
                    .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .center)
                }
                .scrollBounceBehavior(.basedOnSize)
            } else {
                let rosterWidth = min(max(geometry.size.width * 0.33, 300), 380)
                let stageHeight = max(geometry.size.height * 0.52, 280)
                let usesCompactLayout = geometry.size.width < 1_100

                ScrollView(.vertical) {
                    Group {
                        if usesCompactLayout {
                            VStack(alignment: .leading, spacing: 24) {
                                FightRosterPanel(
                                    characters: characters,
                                    arenaController: arenaController
                                )
                                .frame(maxWidth: .infinity)

                                FightArenaPanel(
                                    arenaController: arenaController,
                                    stageHeight: stageHeight,
                                    isCompactLayout: true
                                )
                                .frame(maxWidth: .infinity, alignment: .top)
                            }
                        } else {
                            HStack(alignment: .top, spacing: 24) {
                                FightRosterPanel(
                                    characters: characters,
                                    arenaController: arenaController
                                )
                                .frame(width: rosterWidth)

                                FightArenaPanel(
                                    arenaController: arenaController,
                                    stageHeight: stageHeight,
                                    isCompactLayout: false
                                )
                                .frame(maxWidth: .infinity, alignment: .top)
                            }
                        }
                    }
                    .padding(24)
                    .frame(minWidth: geometry.size.width, alignment: .topLeading)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }
}

private struct FightShowdownView: View {
    let leftCharacter: LibraryCharacter
    let rightCharacter: LibraryCharacter
    @ObservedObject var arenaController: FightArenaController
    @StateObject private var showdownSceneController: FightShowdownSceneController

    init(
        leftCharacter: LibraryCharacter,
        rightCharacter: LibraryCharacter,
        arenaController: FightArenaController
    ) {
        self.leftCharacter = leftCharacter
        self.rightCharacter = rightCharacter
        self.arenaController = arenaController
        _showdownSceneController = StateObject(
            wrappedValue: FightShowdownSceneController(
                leftCharacter: leftCharacter,
                rightCharacter: rightCharacter,
                leftModelPosition: FightShowdownSceneRules.leftModelPosition(for: leftCharacter.selection.weapon),
                rightModelPosition: FightShowdownSceneRules.rightModelPosition(for: rightCharacter.selection.weapon),
                leftModelOrientation: FightShowdownSceneRules.leftModelOrientation,
                rightModelOrientation: FightShowdownSceneRules.rightModelOrientation
            )
        )
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            FightShowdownViewerView(controller: showdownSceneController)
                .allowsHitTesting(false)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.44),
                    Color.black.opacity(0.10),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            FightShowdownTopHUD(
                leftCharacter: leftCharacter,
                leftCombatant: leftCombatant,
                rightCharacter: rightCharacter,
                rightCombatant: rightCombatant,
                phase: arenaController.phase,
                elapsedTime: arenaController.elapsedTime,
                winnerName: arenaController.winnerName,
                onChooseFighters: arenaController.clearSelection,
                onRematch: arenaController.rematch
            )
            .padding(.horizontal, 12)
            .padding(.top, 10)
        }
        .onAppear {
            showdownSceneController.onAttackImpact = { side, attackID in
                arenaController.registerAttackImpact(for: side, attackID: attackID)

                if arenaController.phase == .finished {
                    showdownSceneController.playIdle()
                }
            }
            showdownSceneController.onAttackCompleted = { side, attackID in
                arenaController.registerAttackCompletion(for: side, attackID: attackID)
            }
        }
        .onDisappear {
            showdownSceneController.onAttackImpact = nil
            showdownSceneController.onAttackCompleted = nil
        }
        .onChange(of: leftCombatant.attackPulse, initial: false) { oldValue, newValue in
            guard newValue > oldValue else { return }
            showdownSceneController.playAttackOnceThenIdle(for: .left, attackID: newValue)
        }
        .onChange(of: rightCombatant.attackPulse, initial: false) { oldValue, newValue in
            guard newValue > oldValue else { return }
            showdownSceneController.playAttackOnceThenIdle(for: .right, attackID: newValue)
        }
        .onChange(of: showdownSceneController.isSceneLoaded, initial: true) { _, _ in
            startFightIfReady()
        }
        .onChange(of: arenaController.phase, initial: false) { _, newValue in
            guard newValue == .finished else { return }
            showdownSceneController.playIdle()
        }
    }

    private var leftCombatant: FightCombatantViewState {
        arenaController.combatants.first
            ?? FightCombatantViewState(
                character: leftCharacter,
                remainingHealth: leftCharacter.combatStats.maxHealth,
                attackPulse: 0
            )
    }

    private var rightCombatant: FightCombatantViewState {
        arenaController.combatants.dropFirst().first
            ?? FightCombatantViewState(
                character: rightCharacter,
                remainingHealth: rightCharacter.combatStats.maxHealth,
                attackPulse: 0
            )
    }

    private func startFightIfReady() {
        guard showdownSceneController.isSceneLoaded else { return }

        showdownSceneController.playIdle()
        arenaController.beginFightIfNeeded(
            leftAttackDuration: showdownSceneController.leftAttackAnimationDuration,
            rightAttackDuration: showdownSceneController.rightAttackAnimationDuration
        )
    }
}

private struct FightShowdownTopHUD: View {
    let leftCharacter: LibraryCharacter
    let leftCombatant: FightCombatantViewState
    let rightCharacter: LibraryCharacter
    let rightCombatant: FightCombatantViewState
    let phase: FightPhase
    let elapsedTime: Double
    let winnerName: String?
    let onChooseFighters: () -> Void
    let onRematch: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            FightShowdownActionButton(
                title: "Back",
                systemImage: "chevron.left",
                action: onChooseFighters
            )

            FightShowdownHealthStrip(
                character: leftCharacter,
                combatant: leftCombatant,
                tint: leftCharacter.accentColor,
                alignment: .leading
            )

            FightShowdownStatusChip(
                phase: phase,
                elapsedTime: elapsedTime,
                winnerName: winnerName
            )

            FightShowdownHealthStrip(
                character: rightCharacter,
                combatant: rightCombatant,
                tint: rightCharacter.accentColor,
                alignment: .trailing
            )

            if phase == .finished {
                FightShowdownActionButton(
                    title: "Again",
                    systemImage: "arrow.clockwise",
                    action: onRematch
                )
            }
        }
    }
}

private struct FightShowdownActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.34))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct FightShowdownHealthStrip: View {
    let character: LibraryCharacter
    let combatant: FightCombatantViewState
    let tint: Color
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 6) {
            HStack(spacing: 8) {
                Text(character.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("\(combatant.remainingHealth)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .frame(maxWidth: .infinity, alignment: frameAlignment)

            ProgressView(
                value: Double(combatant.remainingHealth),
                total: Double(combatant.maximumHealth)
            )
            .tint(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.34))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.34), lineWidth: 1)
        }
    }

    private var frameAlignment: Alignment {
        alignment == .leading ? .leading : .trailing
    }
}

private struct FightShowdownStatusChip: View {
    let phase: FightPhase
    let elapsedTime: Double
    let winnerName: String?

    var body: some View {
        VStack(spacing: 3) {
            Text(phase == .finished ? "KO" : "FIGHT")
                .font(.caption.weight(.black))
                .foregroundStyle(.white)

            Text(elapsedTime == 0 ? "Ready" : formattedSeconds(elapsedTime))
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)

            if let winnerName {
                Text(winnerName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.34))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
    }
}

private enum FightShowdownSceneRules {
    static let leftModelOrientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 1, 0))
    static let rightModelOrientation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(0, 1, 0))

    static func leftModelPosition(for weapon: WeaponType) -> SIMD3<Float> {
        CharacterPreviewRules.modelPosition + SIMD3<Float>(-(0.82 + weapon.combatReachOffset), 0, 0)
    }

    static func rightModelPosition(for weapon: WeaponType) -> SIMD3<Float> {
        CharacterPreviewRules.modelPosition + SIMD3<Float>(0.82 + weapon.combatReachOffset, 0, 0)
    }
}

private struct HomeMenuCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct LibraryCharacterCard: View {
    let character: LibraryCharacter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Circle()
                    .fill(character.accentColor.gradient)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(character.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(character.role)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right.circle.fill")
                    .font(.headline)
                    .foregroundStyle(character.accentColor)
            }

            HStack(spacing: 8) {
                StatPill(label: "Body", value: character.selection.body.displayName)
                StatPill(label: "Weapon", value: character.selection.weapon.displayName)
            }

            HStack(spacing: 8) {
                StatPill(label: "HP", value: "\(character.combatStats.maxHealth)")
                StatPill(label: "DMG", value: "\(character.combatStats.damage)")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(character.accentColor.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
    }
}

private struct FightRosterPanel: View {
    let characters: [LibraryCharacter]
    @ObservedObject var arenaController: FightArenaController
    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Choose Fighters")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text("Pick exactly two heroes from the grid below.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(characters) { character in
                    Button {
                        arenaController.toggleSelection(character)
                    } label: {
                        FightRosterCard(
                            character: character,
                            selectionIndex: arenaController.selectionIndex(for: character),
                            isLocked: arenaController.isSelectionLocked(for: character)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(arenaController.isSelectionLocked(for: character))
                }
            }
            .padding(.vertical, 2)

            HStack(spacing: 12) {
                Button("Clear Selection") {
                    arenaController.clearSelection()
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .disabled(arenaController.selectedCharacters.isEmpty)

                Button("Fight Again") {
                    arenaController.rematch()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(!arenaController.canRematch)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct FightRosterCard: View {
    let character: LibraryCharacter
    let selectionIndex: Int?
    let isLocked: Bool

    var body: some View {
        let borderColor = selectionIndex == nil ? character.accentColor.opacity(0.22) : character.accentColor

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(character.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                Spacer()

                if let selectionIndex {
                    Text("\(selectionIndex + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(character.accentColor)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.12))
                        )
                }
            }

            FightRosterDetail(label: "Body", value: character.selection.body.displayName)
            FightRosterDetail(label: "Weapon", value: character.selection.weapon.displayName)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(selectionIndex == nil ? 0.08 : 0.15))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor, lineWidth: selectionIndex == nil ? 1 : 2)
        }
        .opacity(isLocked ? 0.58 : 1)
    }
}

private struct FightRosterDetail: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.56))
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct FightMiniStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.58))
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.14))
        )
    }
}

private struct FightArenaPanel: View {
    @ObservedObject var arenaController: FightArenaController
    let stageHeight: CGFloat
    let isCompactLayout: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FightStatusBanner(
                title: arenaController.headline,
                subtitle: arenaController.subheadline
            )

            if arenaController.combatants.count == 2 {
                HStack(spacing: 18) {
                    FightCombatantStageCard(
                        state: arenaController.combatants[0],
                        outcome: arenaController.outcome(for: arenaController.combatants[0])
                    )
                    .id(arenaController.combatants[0].id)

                    FightCenterSummaryCard(arenaController: arenaController)
                        .frame(width: isCompactLayout ? 180 : 220)

                    FightCombatantStageCard(
                        state: arenaController.combatants[1],
                        outcome: arenaController.outcome(for: arenaController.combatants[1])
                    )
                    .id(arenaController.combatants[1].id)
                }
                .frame(maxWidth: .infinity)
                .frame(height: stageHeight)
            } else {
                FightArenaPlaceholder(selectedCount: arenaController.selectedCharacters.count)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: stageHeight)
            }

            FightBattleLogCard(entries: arenaController.battleLog)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.93))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        }
    }
}

private struct FightStatusBanner: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FightArenaPlaceholder: View {
    let selectedCount: Int

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            Image(systemName: selectedCount == 0 ? "shield.slash.fill" : "figure.stand.line.dotted.figure.stand")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.red.opacity(0.75))

            VStack(spacing: 8) {
                Text(selectedCount == 0 ? "Arena Waiting" : "One Fighter Locked")
                    .font(.title3.weight(.semibold))
                Text(selectedCount == 0
                     ? "Choose two heroes on the left to start the duel."
                     : "Pick one more hero to open the arena and begin the fight.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            FightRuleReferenceCard()
                .frame(maxWidth: 520)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.red.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct FightRuleReferenceCard: View {
    private let displayedBodies = BodyType.allCases
    private let displayedWeapons: [WeaponType] = [
        .sword,
        .mace,
        .axe,
        .spear
    ]
    private let healthValues = BodyType.allCases.map(\.maxHealth).sorted()

    private var healthReferenceLabel: String {
        healthValues.first == healthValues.last ? "Base HP" : "HP Range"
    }

    private var healthReferenceValue: String {
        guard let first = healthValues.first else { return "--" }
        guard let last = healthValues.last, last != first else {
            return "\(first)"
        }

        return "\(first)-\(last)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Combat Rules")
                    .font(.headline.weight(.semibold))
                Spacer()
                StatPill(label: healthReferenceLabel, value: healthReferenceValue)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Body Stats")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                ForEach(displayedBodies, id: \.rawValue) { body in
                    FightBodyRuleRow(bodyType: body)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Weapon Stats")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                ForEach(displayedWeapons, id: \.rawValue) { weapon in
                    FightRuleRow(weapon: weapon)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.red.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct FightRuleRow: View {
    let weapon: WeaponType

    var body: some View {
        HStack {
            Text(weapon.displayName)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(weapon.damage) dmg")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("·")
                .foregroundStyle(.secondary)
            Text("\(formattedAttackRate(weapon.attackRate)) base atk/s")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FightBodyRuleRow: View {
    let bodyType: BodyType

    var body: some View {
        HStack {
            Text(bodyType.displayName)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(bodyType.maxHealth) hp")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("·")
                .foregroundStyle(.secondary)
            Text("\(formattedAttackRate(bodyType.attackSpeed))x speed")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FightCenterSummaryCard: View {
    @ObservedObject var arenaController: FightArenaController

    var body: some View {
        VStack(spacing: 18) {
            Text("VS")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.red)

            StatPill(label: "Phase", value: arenaController.phase.displayName)
            StatPill(label: "Time", value: arenaController.elapsedTime == 0 ? "Ready" : formattedSeconds(arenaController.elapsedTime))

            if let winnerName = arenaController.winnerName {
                VStack(spacing: 4) {
                    Text("Winner")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(winnerName)
                        .font(.headline.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
            } else if arenaController.phase == .finished {
                VStack(spacing: 4) {
                    Text("Result")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text("Draw")
                        .font(.headline.weight(.semibold))
                }
            }

            Button(arenaController.phase == .finished ? "Fight Again" : "Fight Running") {
                arenaController.rematch()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(!arenaController.canRematch)
        }
        .frame(maxHeight: .infinity)
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.red.opacity(0.14), lineWidth: 1)
        }
    }
}

private struct HealthMeter: View {
    let currentHealth: Int
    let maximumHealth: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Health")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(currentHealth) / \(maximumHealth)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(currentHealth), total: Double(maximumHealth))
                .tint(tint)
        }
    }
}

private struct FightCombatantStageCard: View {
    let state: FightCombatantViewState
    let outcome: FightCombatantOutcome
    @StateObject private var sceneController: ModelSceneController

    init(state: FightCombatantViewState, outcome: FightCombatantOutcome) {
        self.state = state
        self.outcome = outcome
        _sceneController = StateObject(wrappedValue: ModelSceneController(selection: state.character.selection))
    }

    var body: some View {
        let combatStats = state.character.combatStats

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.character.name)
                        .font(.headline.weight(.semibold))
                    Text(state.character.selection.loadoutDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let badgeTitle = outcome.badgeTitle {
                    Text(badgeTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(outcome.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(outcome.tint.opacity(0.12))
                        )
                }
            }

            ModelViewerView(controller: sceneController)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(outcome.tint.opacity(0.18), lineWidth: 1)
                }

            HealthMeter(
                currentHealth: state.remainingHealth,
                maximumHealth: state.maximumHealth,
                tint: outcome.tint
            )

            HStack(spacing: 10) {
                StatPill(label: "Weapon", value: state.character.selection.weapon.displayName)
                StatPill(label: "Damage", value: "\(combatStats.damage)")
                StatPill(label: "Rate", value: formattedAttackRate(combatStats.attackRate))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(outcome.tint.opacity(0.16), lineWidth: 1)
        }
        .onChange(of: state.attackPulse, initial: false) { oldValue, newValue in
            guard newValue > oldValue else { return }
            sceneController.playAttackOnceThenIdle()
        }
    }
}

private struct FightBattleLogCard: View {
    let entries: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Battle Log")
                .font(.headline.weight(.semibold))

            LazyVStack(alignment: .leading, spacing: 10) {
                if entries.isEmpty {
                    Text("The battle log will appear once the first strike lands.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1).")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text(entry)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.red.opacity(0.12), lineWidth: 1)
        }
    }
}

private enum FightPhase {
    case awaitingSelection
    case fighting
    case finished

    var displayName: String {
        switch self {
        case .awaitingSelection:
            return "Waiting"
        case .fighting:
            return "Fighting"
        case .finished:
            return "Finished"
        }
    }
}

private enum FightCombatantOutcome {
    case neutral
    case winner
    case loser
    case draw

    var badgeTitle: String? {
        switch self {
        case .neutral:
            return nil
        case .winner:
            return "Winner"
        case .loser:
            return "Defeated"
        case .draw:
            return "Draw"
        }
    }

    var tint: Color {
        switch self {
        case .neutral:
            return .orange
        case .winner:
            return .green
        case .loser:
            return .red
        case .draw:
            return .orange
        }
    }
}

private struct FightCombatantViewState: Identifiable {
    let character: LibraryCharacter
    let remainingHealth: Int
    let attackPulse: Int

    var id: String {
        character.id
    }

    var maximumHealth: Int {
        character.combatStats.maxHealth
    }
}

@MainActor
private final class FightArenaController: ObservableObject {
    @Published private(set) var selectedCharacters: [LibraryCharacter] = []
    @Published private(set) var combatants: [FightCombatantViewState] = []
    @Published private(set) var battleLog: [String] = []
    @Published private(set) var headline = "Choose two heroes"
    @Published private(set) var subheadline = "The duel starts automatically after you select the second fighter."
    @Published private(set) var phase: FightPhase = .awaitingSelection
    @Published private(set) var winnerID: String?
    @Published private(set) var elapsedTime: Double = 0
    @Published private(set) var matchID = UUID()

    private var fightTask: Task<Void, Never>?
    private var activeFightState: ActiveFightState?
    private var pendingStrikes: [ArenaFighterSide: [Int: PendingStrike]] = [:]
    private var specialSkillTriggerCounts: [String: Int] = [:]

    var isShowingShowdown: Bool {
        selectedCharacters.count == 2
    }

    var canRematch: Bool {
        selectedCharacters.count == 2 && phase == .finished
    }

    var winnerName: String? {
        guard let winnerID else { return nil }
        return selectedCharacters.first(where: { $0.id == winnerID })?.name
    }

    func toggleSelection(_ character: LibraryCharacter) {
        if let index = selectedCharacters.firstIndex(where: { $0.id == character.id }) {
            var updated = selectedCharacters
            updated.remove(at: index)
            selectedCharacters = updated
            resetArenaForCurrentSelection()
            return
        }

        guard selectedCharacters.count < 2 else {
            headline = "Two fighters already selected"
            subheadline = "Tap a selected hero to swap them out, or clear the arena."
            return
        }

        var updated = selectedCharacters
        updated.append(character)
        selectedCharacters = updated
        
        if selectedCharacters.count == 2 {
            prepareShowdown()
        } else {
            resetArenaForCurrentSelection()
        }
    }

    func clearSelection() {
        selectedCharacters = []
        resetArenaForCurrentSelection()
    }

    func rematch() {
        guard selectedCharacters.count == 2 else { return }
        prepareShowdown()
    }

    func cancelFight() {
        fightTask?.cancel()
        fightTask = nil
        activeFightState = nil
        pendingStrikes.removeAll()
        specialSkillTriggerCounts.removeAll()
    }

    func selectionIndex(for character: LibraryCharacter) -> Int? {
        selectedCharacters.firstIndex(where: { $0.id == character.id })
    }

    func isSelectionLocked(for character: LibraryCharacter) -> Bool {
        selectionIndex(for: character) == nil && selectedCharacters.count == 2
    }

    func outcome(for combatant: FightCombatantViewState) -> FightCombatantOutcome {
        guard phase == .finished else { return .neutral }

        if let winnerID {
            return winnerID == combatant.id ? .winner : .loser
        }

        return .draw
    }

    func beginFightIfNeeded(leftAttackDuration: TimeInterval = 0, rightAttackDuration: TimeInterval = 0) {
        guard selectedCharacters.count == 2, phase == .awaitingSelection, fightTask == nil else { return }
        beginFight(
            leftAttackDuration: leftAttackDuration,
            rightAttackDuration: rightAttackDuration
        )
    }

    func registerAttackImpact(for side: ArenaFighterSide, attackID: Int) {
        guard
            phase == .fighting,
            var state = activeFightState,
            let strike = removePendingStrike(for: side, attackID: attackID)
        else {
            return
        }

        let attackerIndex = side == .left ? 0 : 1
        let defenderIndex = side == .left ? 1 : 0
        let time = max(currentFightElapsedTime(), strike.scheduledTime)
        let attackerCharacter = side == .left ? state.leftCharacter : state.rightCharacter
        let defenderCharacter = side == .left ? state.rightCharacter : state.leftCharacter
        let attackerHealth = side == .left ? state.leftHealth : state.rightHealth
        let defenderHealth = side == .left ? state.rightHealth : state.leftHealth
        let resolution = FightSpecialSkillResolver.resolveImpact(
            attacker: attackerCharacter,
            defender: defenderCharacter,
            attackerHealth: attackerHealth,
            defenderHealth: defenderHealth,
            baseDamage: strike.damage,
            elapsedTime: time,
            attackID: attackID,
            attackerTriggerCount: specialSkillTriggerCount(for: attackerCharacter),
            defenderTriggerCount: specialSkillTriggerCount(for: defenderCharacter)
        )

        switch side {
        case .left:
            state.leftHealth = resolution.attackerHealth
            state.rightHealth = resolution.defenderHealth
        case .right:
            state.rightHealth = resolution.attackerHealth
            state.leftHealth = resolution.defenderHealth
        }

        if resolution.attackerEffect.isTriggered {
            registerSkillTrigger(for: attackerCharacter)
        }

        if resolution.defenderEffect.isTriggered {
            registerSkillTrigger(for: defenderCharacter)
        }

        activeFightState = state
        applyResolvedHit(
            attackerIndex: attackerIndex,
            defenderIndex: defenderIndex,
            damage: resolution.finalDamage,
            attackerHealth: resolution.attackerHealth,
            defenderHealth: resolution.defenderHealth,
            time: time,
            attackerEffect: resolution.attackerEffect,
            defenderEffect: resolution.defenderEffect
        )

        if resolution.defenderHealth == 0 {
            let defeatedSide: ArenaFighterSide = side == .left ? .right : .left
            let canceledStrikeCount = removePendingStrikes(for: defeatedSide).count

            if canceledStrikeCount > 0 {
                let defeatedName = defenderIndex < combatants.count
                    ? combatants[defenderIndex].character.name
                    : (defeatedSide == .left ? state.leftCharacter.name : state.rightCharacter.name)

                battleLog = battleLog + [
                    "\(formattedSeconds(time)): \(defeatedName)'s attack is interrupted before it can land."
                ]
            }

            finishFight(
                leftCharacter: state.leftCharacter,
                rightCharacter: state.rightCharacter,
                leftHealth: state.leftHealth,
                rightHealth: state.rightHealth,
                elapsed: max(elapsedTime, time)
            )
            return
        }

        tryFinishFightIfResolved()
    }

    func registerAttackCompletion(for side: ArenaFighterSide, attackID: Int) {
        guard phase == .fighting else { return }
        _ = removePendingStrike(for: side, attackID: attackID)
        tryFinishFightIfResolved()
    }

    private func resetArenaForCurrentSelection() {
        cancelFight()
        winnerID = nil
        elapsedTime = 0
        battleLog = []
        combatants = selectedCharacters.map {
            FightCombatantViewState(
                character: $0,
                remainingHealth: $0.combatStats.maxHealth,
                attackPulse: 0
            )
        }

        switch selectedCharacters.count {
        case 0:
            phase = .awaitingSelection
            headline = "Choose two heroes"
            subheadline = "The duel starts automatically after you select the second fighter."
        case 1:
            phase = .awaitingSelection
            headline = "Choose one more hero"
            subheadline = "\(selectedCharacters[0].name) is waiting in the arena."
        default:
            phase = .awaitingSelection
            headline = "Fighters locked in"
            subheadline = "Opening the arena."
        }
    }

    private func prepareShowdown() {
        guard selectedCharacters.count == 2 else { return }

        cancelFight()
        matchID = UUID()

        let leftCharacter = selectedCharacters[0]
        let rightCharacter = selectedCharacters[1]

        combatants = [
            FightCombatantViewState(
                character: leftCharacter,
                remainingHealth: leftCharacter.combatStats.maxHealth,
                attackPulse: 0
            ),
            FightCombatantViewState(
                character: rightCharacter,
                remainingHealth: rightCharacter.combatStats.maxHealth,
                attackPulse: 0
            )
        ]

        battleLog = []
        winnerID = nil
        elapsedTime = 0
        phase = .awaitingSelection
        headline = "Arena ready"
        subheadline = "Fight starts when both fighters finish loading."
    }

    private func beginFight(leftAttackDuration: TimeInterval, rightAttackDuration: TimeInterval) {
        guard selectedCharacters.count == 2 else { return }

        let leftCharacter = selectedCharacters[0]
        let rightCharacter = selectedCharacters[1]
        let leftStats = leftCharacter.combatStats
        let rightStats = rightCharacter.combatStats
        let leftCadence = max(leftStats.attackInterval, max(leftAttackDuration, CharacterPreviewRules.minimumAttackRecoveryDuration))
        let rightCadence = max(rightStats.attackInterval, max(rightAttackDuration, CharacterPreviewRules.minimumAttackRecoveryDuration))

        combatants = [
            FightCombatantViewState(
                character: leftCharacter,
                remainingHealth: leftStats.maxHealth,
                attackPulse: 0
            ),
            FightCombatantViewState(
                character: rightCharacter,
                remainingHealth: rightStats.maxHealth,
                attackPulse: 0
            )
        ]

        battleLog = [
            "\(leftCharacter.name) enters with \(leftCharacter.selection.weapon.displayName): \(leftStats.damage) damage at \(formattedAttackRate(leftStats.attackRate)) attacks per second.",
            "\(rightCharacter.name) enters with \(rightCharacter.selection.weapon.displayName): \(rightStats.damage) damage at \(formattedAttackRate(rightStats.attackRate)) attacks per second.",
            "The duel begins."
        ]

        winnerID = nil
        elapsedTime = 0
        phase = .fighting
        headline = "Fight in progress"
        subheadline = "Each fighter waits for a full attack animation before the next strike."
        specialSkillTriggerCounts.removeAll()
        activeFightState = ActiveFightState(
            leftCharacter: leftCharacter,
            rightCharacter: rightCharacter,
            leftHealth: leftStats.maxHealth,
            rightHealth: rightStats.maxHealth,
            startedAt: Date()
        )
        pendingStrikes.removeAll()

        fightTask = Task {
            await runFight(
                leftCharacter: leftCharacter,
                rightCharacter: rightCharacter,
                leftCadence: leftCadence,
                rightCadence: rightCadence
            )
        }
    }

    private func runFight(
        leftCharacter: LibraryCharacter,
        rightCharacter: LibraryCharacter,
        leftCadence: TimeInterval,
        rightCadence: TimeInterval
    ) async {
        let leftStats = leftCharacter.combatStats
        let rightStats = rightCharacter.combatStats
        var leftNextAttack = leftCadence
        var rightNextAttack = rightCadence
        var elapsed = 0.0

        while !Task.isCancelled {
            guard !Task.isCancelled else { return }
            guard phase == .fighting, let state = activeFightState else { return }

            if state.leftHealth == 0 || state.rightHealth == 0 {
                if !hasPendingStrikes {
                    finishFight(
                        leftCharacter: state.leftCharacter,
                        rightCharacter: state.rightCharacter,
                        leftHealth: state.leftHealth,
                        rightHealth: state.rightHealth,
                        elapsed: max(elapsedTime, currentFightElapsedTime())
                    )
                    return
                }

                elapsedTime = max(elapsedTime, currentFightElapsedTime())
                try? await Task.sleep(nanoseconds: 10_000_000)
                continue
            }

            let nextAttackTime = min(leftNextAttack, rightNextAttack)
            let waitDuration = max(nextAttackTime - elapsed, 0)

            if waitDuration > 0 {
                let waitNanoseconds = UInt64(waitDuration * 1_000_000_000)
                try? await Task.sleep(nanoseconds: waitNanoseconds)
            }

            guard !Task.isCancelled else { return }
            guard phase == .fighting, let refreshedState = activeFightState else { return }

            elapsed = nextAttackTime
            elapsedTime = max(elapsedTime, elapsed)

            if refreshedState.leftHealth == 0 || refreshedState.rightHealth == 0 {
                if !hasPendingStrikes {
                    finishFight(
                        leftCharacter: refreshedState.leftCharacter,
                        rightCharacter: refreshedState.rightCharacter,
                        leftHealth: refreshedState.leftHealth,
                        rightHealth: refreshedState.rightHealth,
                        elapsed: max(elapsedTime, currentFightElapsedTime())
                    )
                    return
                }

                continue
            }

            let leftActsNow = abs(leftNextAttack - nextAttackTime) < 0.000_1
            let rightActsNow = abs(rightNextAttack - nextAttackTime) < 0.000_1

            if leftActsNow && refreshedState.leftHealth > 0 {
                queueAttack(for: .left, damage: leftStats.damage, time: elapsed)
                leftNextAttack += leftCadence
            }

            if rightActsNow && refreshedState.rightHealth > 0 {
                queueAttack(for: .right, damage: rightStats.damage, time: elapsed)
                rightNextAttack += rightCadence
            }
        }
    }

    private func queueAttack(for side: ArenaFighterSide, damage: Int, time: Double) {
        let attackerIndex = side == .left ? 0 : 1
        guard attackerIndex < combatants.count else { return }

        var updatedCombatants = combatants
        let attackID = updatedCombatants[attackerIndex].attackPulse + 1
        registerPendingStrike(
            PendingStrike(damage: damage, scheduledTime: time),
            for: side,
            attackID: attackID
        )
        updatedCombatants[attackerIndex] = FightCombatantViewState(
            character: updatedCombatants[attackerIndex].character,
            remainingHealth: updatedCombatants[attackerIndex].remainingHealth,
            attackPulse: attackID
        )
        combatants = updatedCombatants
    }

    private func applyResolvedHit(
        attackerIndex: Int,
        defenderIndex: Int,
        damage: Int,
        attackerHealth: Int,
        defenderHealth: Int,
        time: Double,
        attackerEffect: CharacterSpecialSkillEffect,
        defenderEffect: CharacterSpecialSkillEffect
    ) {
        guard attackerIndex < combatants.count, defenderIndex < combatants.count else { return }

        var updatedCombatants = combatants
        let attackerName = updatedCombatants[attackerIndex].character.name
        let defenderName = updatedCombatants[defenderIndex].character.name

        updatedCombatants[attackerIndex] = FightCombatantViewState(
            character: updatedCombatants[attackerIndex].character,
            remainingHealth: attackerHealth,
            attackPulse: updatedCombatants[attackerIndex].attackPulse
        )
        updatedCombatants[defenderIndex] = FightCombatantViewState(
            character: updatedCombatants[defenderIndex].character,
            remainingHealth: defenderHealth,
            attackPulse: updatedCombatants[defenderIndex].attackPulse
        )
        combatants = updatedCombatants

        var logEntries: [String] = []

        if let line = skillLogLine(for: attackerName, effect: attackerEffect, time: time) {
            logEntries.append(line)
        }

        if let line = skillLogLine(for: defenderName, effect: defenderEffect, time: time) {
            logEntries.append(line)
        }

        logEntries.append(
            "\(formattedSeconds(time)): \(attackerName) hits \(defenderName) for \(damage). \(defenderName) drops to \(defenderHealth) HP."
        )
        battleLog = battleLog + logEntries
    }

    private func tryFinishFightIfResolved() {
        guard phase == .fighting, let state = activeFightState else { return }
        guard state.leftHealth == 0 || state.rightHealth == 0 else { return }
        guard !hasPendingStrikes else { return }

        finishFight(
            leftCharacter: state.leftCharacter,
            rightCharacter: state.rightCharacter,
            leftHealth: state.leftHealth,
            rightHealth: state.rightHealth,
            elapsed: max(elapsedTime, currentFightElapsedTime())
        )
    }

    private func currentFightElapsedTime() -> Double {
        guard let activeFightState else { return elapsedTime }
        return max(elapsedTime, Date().timeIntervalSince(activeFightState.startedAt))
    }

    private func finishFight(
        leftCharacter: LibraryCharacter,
        rightCharacter: LibraryCharacter,
        leftHealth: Int,
        rightHealth: Int,
        elapsed: Double
    ) {
        fightTask?.cancel()
        fightTask = nil
        activeFightState = nil
        pendingStrikes.removeAll()
        specialSkillTriggerCounts.removeAll()
        phase = .finished
        elapsedTime = elapsed

        if leftHealth == 0 && rightHealth == 0 {
            winnerID = nil
            headline = "Double knockout"
            subheadline = "Both heroes fell after \(formattedSeconds(elapsed))."
            battleLog = battleLog + [
                "Both fighters land the final blow at the same time."
            ]
            return
        }

        let winner: LibraryCharacter
        let remainingHealth: Int

        if leftHealth > 0 {
            winner = leftCharacter
            remainingHealth = leftHealth
        } else {
            winner = rightCharacter
            remainingHealth = rightHealth
        }

        winnerID = winner.id
        headline = "\(winner.name) wins"
        subheadline = "Victory after \(formattedSeconds(elapsed)) with \(remainingHealth) HP remaining."
        battleLog = battleLog + [
            "\(winner.name) wins the arena."
        ]
    }
}

private extension FightArenaController {
    struct PendingStrike {
        let damage: Int
        let scheduledTime: Double
    }

    struct ActiveFightState {
        let leftCharacter: LibraryCharacter
        let rightCharacter: LibraryCharacter
        var leftHealth: Int
        var rightHealth: Int
        let startedAt: Date
    }

    var hasPendingStrikes: Bool {
        pendingStrikes.values.contains(where: { !$0.isEmpty })
    }

    func registerPendingStrike(_ strike: PendingStrike, for side: ArenaFighterSide, attackID: Int) {
        var strikesByAttackID = pendingStrikes[side] ?? [:]
        strikesByAttackID[attackID] = strike
        pendingStrikes[side] = strikesByAttackID
    }

    func removePendingStrike(for side: ArenaFighterSide, attackID: Int) -> PendingStrike? {
        guard var strikesByAttackID = pendingStrikes[side] else { return nil }

        let strike = strikesByAttackID.removeValue(forKey: attackID)
        if strikesByAttackID.isEmpty {
            pendingStrikes.removeValue(forKey: side)
        } else {
            pendingStrikes[side] = strikesByAttackID
        }

        return strike
    }

    func removePendingStrikes(for side: ArenaFighterSide) -> [Int: PendingStrike] {
        pendingStrikes.removeValue(forKey: side) ?? [:]
    }

    func specialSkillTriggerCount(for character: LibraryCharacter) -> Int {
        specialSkillTriggerCounts[character.id] ?? 0
    }

    func registerSkillTrigger(for character: LibraryCharacter) {
        specialSkillTriggerCounts[character.id, default: 0] += 1
    }

    func skillLogLine(
        for characterName: String,
        effect: CharacterSpecialSkillEffect,
        time: Double
    ) -> String? {
        guard effect.isTriggered else { return nil }

        if let summary = effect.battleLogDescription() {
            return "\(formattedSeconds(time)): \(characterName)'s special skill activates. \(summary)"
        }

        return "\(formattedSeconds(time)): \(characterName)'s special skill activates."
    }
}

private func formattedAttackRate(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(1)))
}

private func formattedSeconds(_ value: Double) -> String {
    "\(value.formatted(.number.precision(.fractionLength(2))))s"
}
