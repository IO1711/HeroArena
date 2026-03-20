import Foundation

typealias CharacterSpecialSkill = (CharacterSpecialSkillContext) -> CharacterSpecialSkillEffect

struct CharacterSpecialSkillContext {
    let currentHealth: Int
    let maxHealth: Int
    let enemyHealth: Int
    let enemyMaxHealth: Int
    let baseDamage: Int
    let damageReceived: Int
    let isAttacked: Bool
    let isAttacking: Bool
    let isDamageFatal: Bool
    let isHpHalf: Bool
    let isEnemyHpHalf: Bool
    let isElf: Bool
    let isKnight: Bool
    let isHuman: Bool
    let isOrc: Bool
    let isUsingSword: Bool
    let isUsingAxe: Bool
    let isUsingSpear: Bool
    let isUsingMace: Bool
    let isEnemyElf: Bool
    let isEnemyKnight: Bool
    let isEnemyHuman: Bool
    let isEnemyOrc: Bool
    let isEnemyUsingSword: Bool
    let isEnemyUsingAxe: Bool
    let isEnemyUsingSpear: Bool
    let isEnemyUsingMace: Bool
    let elapsedTime: Double
    let attackID: Int
    let triggerCount: Int
}

struct CharacterSpecialSkillEffect {
    var outgoingDamageMultiplier: Double = 1
    var outgoingDamageBonus: Int = 0
    var incomingDamageMultiplier: Double = 1
    var incomingDamageOffset: Int = 0
    var healSelf: Int = 0
    var note: String?

    static let none = CharacterSpecialSkillEffect()

    var hasCombatImpact: Bool {
        abs(outgoingDamageMultiplier - 1) > 0.000_1
            || outgoingDamageBonus != 0
            || abs(incomingDamageMultiplier - 1) > 0.000_1
            || incomingDamageOffset != 0
            || healSelf != 0
    }

    var isTriggered: Bool {
        hasCombatImpact || battleLogDescription() != nil
    }

    func battleLogDescription() -> String? {
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedNote, !trimmedNote.isEmpty {
            return trimmedNote
        }

        var fragments: [String] = []

        if abs(outgoingDamageMultiplier - 1) > 0.000_1 || outgoingDamageBonus != 0 {
            fragments.append("modifies outgoing damage")
        }

        if abs(incomingDamageMultiplier - 1) > 0.000_1 || incomingDamageOffset != 0 {
            fragments.append("modifies incoming damage")
        }

        if healSelf > 0 {
            fragments.append("heals \(healSelf) HP")
        }

        guard !fragments.isEmpty else { return nil }
        return fragments.joined(separator: " and ")
    }
}

enum CharacterSpecialSkills {
    static let none: CharacterSpecialSkill = { _ in .none }
}

enum CharacterSpecialSkillRules {
    static let isEnabled = true
}

struct FightSpecialSkillResolution {
    let finalDamage: Int
    let attackerHealth: Int
    let defenderHealth: Int
    let attackerEffect: CharacterSpecialSkillEffect
    let defenderEffect: CharacterSpecialSkillEffect
}

enum FightSpecialSkillResolver {
    static func resolveImpact(
        attacker: LibraryCharacter,
        defender: LibraryCharacter,
        attackerHealth: Int,
        defenderHealth: Int,
        baseDamage: Int,
        elapsedTime: Double,
        attackID: Int,
        attackerTriggerCount: Int,
        defenderTriggerCount: Int
    ) -> FightSpecialSkillResolution {
        guard CharacterSpecialSkillRules.isEnabled else {
            return FightSpecialSkillResolution(
                finalDamage: max(baseDamage, 0),
                attackerHealth: attackerHealth,
                defenderHealth: max(defenderHealth - max(baseDamage, 0), 0),
                attackerEffect: .none,
                defenderEffect: .none
            )
        }

        let attackerContext = CharacterSpecialSkillContext.build(
            fighter: attacker,
            enemy: defender,
            currentHealth: attackerHealth,
            enemyHealth: defenderHealth,
            baseDamage: baseDamage,
            damageReceived: 0,
            isAttacked: false,
            isDamageFatal: baseDamage >= defenderHealth,
            elapsedTime: elapsedTime,
            attackID: attackID,
            triggerCount: attackerTriggerCount
        )
        let attackerEffect = attacker.specialSkill(attackerContext)

        var resolvedDamage = applyOutgoingDamageModifiers(
            to: max(baseDamage, 0),
            using: attackerEffect
        )

        let defenderContext = CharacterSpecialSkillContext.build(
            fighter: defender,
            enemy: attacker,
            currentHealth: defenderHealth,
            enemyHealth: attackerHealth,
            baseDamage: resolvedDamage,
            damageReceived: resolvedDamage,
            isAttacked: true,
            isDamageFatal: resolvedDamage >= defenderHealth,
            elapsedTime: elapsedTime,
            attackID: attackID,
            triggerCount: defenderTriggerCount
        )
        let defenderEffect = defender.specialSkill(defenderContext)

        resolvedDamage = applyIncomingDamageModifiers(
            to: resolvedDamage,
            using: defenderEffect
        )

        let attackerHealedHealth = clampedHealth(
            attackerHealth + max(attackerEffect.healSelf, 0),
            maxHealth: attacker.combatStats.maxHealth
        )
        let defenderHealthAfterDamage = max(defenderHealth - resolvedDamage, 0)
        let defenderResolvedHealth: Int

        if defenderHealthAfterDamage > 0 {
            defenderResolvedHealth = clampedHealth(
                defenderHealthAfterDamage + max(defenderEffect.healSelf, 0),
                maxHealth: defender.combatStats.maxHealth
            )
        } else {
            defenderResolvedHealth = defenderHealthAfterDamage
        }

        return FightSpecialSkillResolution(
            finalDamage: resolvedDamage,
            attackerHealth: attackerHealedHealth,
            defenderHealth: defenderResolvedHealth,
            attackerEffect: attackerEffect,
            defenderEffect: defenderEffect
        )
    }
}

private extension FightSpecialSkillResolver {
    static func applyOutgoingDamageModifiers(
        to damage: Int,
        using effect: CharacterSpecialSkillEffect
    ) -> Int {
        let scaledDamage = scaledDamageValue(damage, multiplier: effect.outgoingDamageMultiplier)
        return max(scaledDamage + effect.outgoingDamageBonus, 0)
    }

    static func applyIncomingDamageModifiers(
        to damage: Int,
        using effect: CharacterSpecialSkillEffect
    ) -> Int {
        let scaledDamage = scaledDamageValue(damage, multiplier: effect.incomingDamageMultiplier)
        return max(scaledDamage + effect.incomingDamageOffset, 0)
    }

    static func scaledDamageValue(_ value: Int, multiplier: Double) -> Int {
        Int((Double(value) * multiplier).rounded(.toNearestOrAwayFromZero))
    }

    static func clampedHealth(_ value: Int, maxHealth: Int) -> Int {
        min(max(value, 0), maxHealth)
    }
}

private extension CharacterSpecialSkillContext {
    static func build(
        fighter: LibraryCharacter,
        enemy: LibraryCharacter,
        currentHealth: Int,
        enemyHealth: Int,
        baseDamage: Int,
        damageReceived: Int,
        isAttacked: Bool,
        isDamageFatal: Bool,
        elapsedTime: Double,
        attackID: Int,
        triggerCount: Int
    ) -> CharacterSpecialSkillContext {
        CharacterSpecialSkillContext(
            currentHealth: currentHealth,
            maxHealth: fighter.combatStats.maxHealth,
            enemyHealth: enemyHealth,
            enemyMaxHealth: enemy.combatStats.maxHealth,
            baseDamage: baseDamage,
            damageReceived: damageReceived,
            isAttacked: isAttacked,
            isAttacking: !isAttacked,
            isDamageFatal: isDamageFatal,
            isHpHalf: currentHealth * 2 <= fighter.combatStats.maxHealth,
            isEnemyHpHalf: enemyHealth * 2 <= enemy.combatStats.maxHealth,
            isElf: fighter.selection.body == .elf,
            isKnight: fighter.selection.body == .knight,
            isHuman: fighter.selection.body.countsAsHuman,
            isOrc: fighter.selection.body == .orc,
            isUsingSword: fighter.selection.weapon == .sword,
            isUsingAxe: fighter.selection.weapon == .axe,
            isUsingSpear: fighter.selection.weapon == .spear,
            isUsingMace: fighter.selection.weapon == .mace,
            isEnemyElf: enemy.selection.body == .elf,
            isEnemyKnight: enemy.selection.body == .knight,
            isEnemyHuman: enemy.selection.body.countsAsHuman,
            isEnemyOrc: enemy.selection.body == .orc,
            isEnemyUsingSword: enemy.selection.weapon == .sword,
            isEnemyUsingAxe: enemy.selection.weapon == .axe,
            isEnemyUsingSpear: enemy.selection.weapon == .spear,
            isEnemyUsingMace: enemy.selection.weapon == .mace,
            elapsedTime: elapsedTime,
            attackID: attackID,
            triggerCount: triggerCount
        )
    }
}

private extension BodyType {
    var countsAsHuman: Bool {
        self == .knight
    }
}
