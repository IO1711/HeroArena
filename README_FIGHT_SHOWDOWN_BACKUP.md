# Fight Showdown Backup

This file is a verbatim snapshot of the fight-showdown flow immediately before the
special-skill system was added on 2026-03-20.

If the new combat layer ever regresses, use the exact snippets below as the restore
source for the pre-skill duel behavior.

## Files That Matter

- `HeroArena/ContentView.swift`
- `HeroArena/ModelSceneController.swift`
- `HeroArena/CharacterConfigurer.swift`

## Exact Code: `FightShowdownView`

Copied from `HeroArena/ContentView.swift`.

```swift
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
```

## Exact Code: `FightShowdownSceneRules`

Copied from `HeroArena/ContentView.swift`.

```swift
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
```

## Exact Code: `FightArenaController` Impact And Timing

Copied from `HeroArena/ContentView.swift`.

```swift
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
    let defenderHealth: Int

    switch side {
    case .left:
        state.rightHealth = max(state.rightHealth - strike.damage, 0)
        defenderHealth = state.rightHealth
    case .right:
        state.leftHealth = max(state.leftHealth - strike.damage, 0)
        defenderHealth = state.leftHealth
    }

    activeFightState = state
    applyResolvedHit(
        attackerIndex: attackerIndex,
        defenderIndex: defenderIndex,
        damage: strike.damage,
        defenderHealth: defenderHealth,
        time: time
    )

    if defenderHealth == 0 {
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
    defenderHealth: Int,
    time: Double
) {
    guard attackerIndex < combatants.count, defenderIndex < combatants.count else { return }

    var updatedCombatants = combatants
    let attackerName = updatedCombatants[attackerIndex].character.name
    let defenderName = updatedCombatants[defenderIndex].character.name

    updatedCombatants[defenderIndex] = FightCombatantViewState(
        character: updatedCombatants[defenderIndex].character,
        remainingHealth: defenderHealth,
        attackPulse: updatedCombatants[defenderIndex].attackPulse
    )
    combatants = updatedCombatants

    battleLog = battleLog + [
        "\(formattedSeconds(time)): \(attackerName) hits \(defenderName) for \(damage). \(defenderName) drops to \(defenderHealth) HP."
    ]
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
```

## Exact Code: Pending Strike Helpers

Copied from `HeroArena/ContentView.swift`.

```swift
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
}
```

## Exact Code: `FightShowdownSceneController` Attack Flow

Copied from `HeroArena/ModelSceneController.swift`.

```swift
final class FightShowdownSceneController: ObservableObject {
    @Published private(set) var statusMessage = "Loading showdown..."
    @Published private(set) var isSceneLoaded = false
    @Published private(set) var leftAttackAnimationDuration: TimeInterval = 0
    @Published private(set) var rightAttackAnimationDuration: TimeInterval = 0

    var onAttackImpact: ((ArenaFighterSide, Int) -> Void)?
    var onAttackCompleted: ((ArenaFighterSide, Int) -> Void)?

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

    private func approachDistance(attackerWeapon: WeaponType, defenderWeapon: WeaponType) -> Float {
        max(
            ShowdownSceneRules.baseAdvanceDistance + defenderWeapon.combatReachOffset - attackerWeapon.combatReachOffset,
            ShowdownSceneRules.minimumAdvanceDistance
        )
    }
}
```

## Exact Code: `ShowdownSceneRules` And `ShowdownAttackImpactRules`

Copied from `HeroArena/ModelSceneController.swift`.

```swift
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
```

## Notes

- This snapshot predates any special-skill hooks.
- Damage is resolved only from queued strike damage at impact time.
- A fighter whose HP reaches `0` immediately cancels the defeated side's pending strikes.
