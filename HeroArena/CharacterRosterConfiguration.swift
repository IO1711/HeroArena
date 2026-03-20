let configuredCharacters: [ConfiguredCharacterDefinition] = [
    // Example character:
    // ConfiguredCharacterDefinition(
    //     name: "Thorin",
    //     body: .knight,
    //     weapon: .sword,
    //     specialSkill: { context in
    //         guard !context.isAttacked, context.isHpHalf else { return .none }
    //         return CharacterSpecialSkillEffect(
    //             outgoingDamageBonus: 4,
    //             note: "Battle Fury adds 4 damage below half HP."
    //         )
    //     }
    // ),
]


// Available special-skill context values:
// A skill can run in attack mode or defense mode.
// Attack mode: `isAttacked == false`, `isAttacking == true`.
// Defense mode: `isAttacked == true`, `isAttacking == false`.
// The attacker skill runs first, then the defender skill runs for the same hit.
//
// Health and damage values:
// `currentHealth: Int`
// HP of the fighter whose skill is running, before this hit fully resolves.
// `maxHealth: Int`
// Max HP of the fighter whose skill is running.
// `enemyHealth: Int`
// Opponent HP at the same moment.
// `enemyMaxHealth: Int`
// Opponent max HP.
// `baseDamage: Int`
// In attack mode: your outgoing damage before your own skill changes it.
// In defense mode: incoming damage after the attacker skill, before your defender skill changes it.
// `damageReceived: Int`
// Incoming damage about to hit this fighter. This is `0` in attack mode.
//
// Fight state booleans:
// `isAttacked: Bool`
// `true` only when this fighter is the one being hit right now.
// `isAttacking: Bool`
// `true` only when this fighter is the one landing the current hit.
// `isDamageFatal: Bool`
// In attack mode: `true` if `baseDamage >= enemyHealth` before your own skill changes it.
// In defense mode: `true` if the incoming damage would KO you before your defender skill changes it.
// `isHpHalf: Bool`
// `true` when `currentHealth` is half HP or lower.
// `isEnemyHpHalf: Bool`
// `true` when the enemy is half HP or lower.
//
// Body-type booleans for your fighter:
// `isElf: Bool`
// `true` when this fighter uses the elf body.
// `isKnight: Bool`
// `true` when this fighter uses the knight body.
// `isHuman: Bool`
// `true` when this fighter counts as human. Right now knight maps to human.
// `isOrc: Bool`
// `true` when this fighter uses the orc body.
//
// Weapon-type booleans for your fighter:
// `isUsingSword: Bool`
// `true` when this fighter uses a sword.
// `isUsingAxe: Bool`
// `true` when this fighter uses an axe.
// `isUsingSpear: Bool`
// `true` when this fighter uses a spear.
// `isUsingMace: Bool`
// `true` when this fighter uses a mace.
//
// Enemy body-type booleans:
// `isEnemyElf: Bool`
// `true` when the opponent uses the elf body.
// `isEnemyKnight: Bool`
// `true` when the opponent uses the knight body.
// `isEnemyHuman: Bool`
// `true` when the opponent counts as human. Right now knight maps to human.
// `isEnemyOrc: Bool`
// `true` when the opponent uses the orc body.
//
// Enemy weapon-type booleans:
// `isEnemyUsingSword: Bool`
// `true` when the opponent uses a sword.
// `isEnemyUsingAxe: Bool`
// `true` when the opponent uses an axe.
// `isEnemyUsingSpear: Bool`
// `true` when the opponent uses a spear.
// `isEnemyUsingMace: Bool`
// `true` when the opponent uses a mace.
//
// Timing and counters:
// `elapsedTime: Double`
// Seconds since the current duel started when this hit is resolving.
// `attackID: Int`
// Sequential id for the current swing on this side. Useful for debugging or matching logs.
// `triggerCount: Int`
// Number of times this fighter's special skill already triggered earlier in this fight.

// Premade skills to copy-paste:
//
// Battle Fury
// specialSkill: { context in
//     guard !context.isAttacked, context.isHpHalf else { return .none }
//     return CharacterSpecialSkillEffect(
//         outgoingDamageBonus: 4,
//         note: "Battle Fury adds 4 damage below half HP."
//     )
// }
//
// Last Stand (once per fight)
// specialSkill: { context in
//     guard context.isAttacked, context.isDamageFatal, context.triggerCount == 0 else { return .none }
//     let damageToLeaveOneHP = max(context.damageReceived - max(context.currentHealth - 1, 0), 0)
//     return CharacterSpecialSkillEffect(
//         incomingDamageOffset: -damageToLeaveOneHP,
//         note: "Last Stand refuses to fall."
//     )
// }
//
// Orc Hunter
// specialSkill: { context in
//     guard !context.isAttacked, context.isEnemyOrc else { return .none }
//     return CharacterSpecialSkillEffect(
//         outgoingDamageMultiplier: 1.35,
//         note: "Orc Hunter surges against orc enemies."
//     )
// }
//
// Spear Ward
// specialSkill: { context in
//     guard context.isAttacked, context.isEnemyUsingSpear else { return .none }
//     return CharacterSpecialSkillEffect(
//         incomingDamageOffset: -3,
//         note: "Spear Ward trims 3 damage from spear strikes."
//     )
// }
//
// Vampire Strike
// specialSkill: { context in
//     guard !context.isAttacked else { return .none }
//     return CharacterSpecialSkillEffect(
//         healSelf: 2,
//         note: "Vampire Strike restores 2 HP on every attack."
//     )
// }
