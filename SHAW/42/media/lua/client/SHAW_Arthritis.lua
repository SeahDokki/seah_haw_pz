--[[
    Humans: Are Weak - Osteoarthritis (SHAW:arthritis, +4 pts)

    Design: the joints grind. Slower swings, hands that tire faster in a long
    fight, worse in the cold.

    Same mechanic as Ehlers-Danlos, different place and different schedule: a
    **chronic ache in the hands** rather than one severe cramp in a leg. Both go
    through SHAW_Soreness.lua.

    On attack speed. The bible wants a longer cooldown between swings, and Build
    42 does not expose that - BodyDamage has getMeleeCombatMod() with no setter,
    and there is no setAttackSpeed on the character. Sore hands get most of the
    way there for free:

      - stiffness is the engine's muscle-strain value, which slows the limb
      - ISBaseTimedAction:adjustMaxTime() multiplies every action's duration by
        (1 + handPain/300) across Hand_L..ForeArm_R, so reloading, first aid and
        crafting all slow down as the ache builds

    The ache tracks spent endurance, so it builds through a long fight and eases
    off when the character stops - which is the behaviour the design describes,
    and it means the trait is a nuisance in a drawn-out fight rather than a flat
    permanent tax.
]]

SHAW = SHAW or {}

-- Ceilings, so the trait is a permanent nuisance and never a death sentence.
local MAX_STIFFNESS = 45
local MAX_ACHE = 14
local COLD_MULTIPLIER = 1.8
local COLD_TEMPERATURE = 18    -- degrees C at which the joints start complaining

-- Announce once when the ache first bites hard, then stay quiet.
local ANNOUNCE_AT = 0.85

--- How hard the trait is biting right now, 0..1.
local function severity(player)
    local base = 0.35

    -- Endurance spent is the cheapest honest proxy for "you have been swinging
    -- for a while": it drains as you fight and recovers when you stop.
    local endurance = SHAW.statFraction(player, CharacterStat.ENDURANCE)
    base = base + (1 - endurance) * 0.65

    local climate = getClimateManager()
    if climate then
        local temperature = climate:getTemperature()
        if temperature and temperature < COLD_TEMPERATURE then
            local coldness = SHAW.clamp((COLD_TEMPERATURE - temperature) / 25, 0, 1)
            base = base * (1 + (COLD_MULTIPLIER - 1) * coldness)
        end
    end

    return SHAW.clamp(base, 0, 1)
end

local function apply(player, data)
    if SHAW.isIncapable(player) then return end

    local level = severity(player)

    SHAW.Soreness.raise(player, SHAW.Soreness.ARMS,
                        MAX_STIFFNESS * level, MAX_ACHE * level)

    -- Tell the player once per bad spell, so the slowdown is legible rather
    -- than mysterious. Resets when the ache eases.
    if level >= ANNOUNCE_AT then
        if not data.SHAW_arthritisAnnounced then
            data.SHAW_arthritisAnnounced = true
            SHAW.sayBad(player, "IGUI_SHAW_HandCramp")
        end
    elseif level < ANNOUNCE_AT - 0.2 then
        data.SHAW_arthritisAnnounced = false
    end

    -- Combat costs this character more breath than it should.
    if player:isRunning() or player:isSprinting() then
        SHAW.addStat(player, CharacterStat.ENDURANCE, -0.00035 * level)
    end
end

SHAW.Tick.register{
    id = "arthritis",
    trait = "ARTHRITIS",
    option = "EnableArthritis",
    everyMs = 1000,
    fn = apply,
}
