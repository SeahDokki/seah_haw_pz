--[[
    Humans: Are Weak - Osteoarthritis (SHAW:arthritis, +4 pts)

    Design: slower attack speed, hands that tire faster in a long fight, worse
    in the cold.

    On attack speed. The bible asks for a longer cooldown between swings, and
    Build 42 does not expose that: BodyDamage has getMeleeCombatMod() with no
    setter, and there is no setAttackSpeed anywhere on the character. What IS
    reachable is the pair of systems the engine already uses to make a damaged
    character fight worse:

      - stiffness   BodyPart:setStiffness(). B42's muscle-strain value. The
                    engine reads it to slow the limb down, which is exactly the
                    mechanism arthritis should be borrowing.
      - hand pain   ISBaseTimedAction:adjustMaxTime() multiplies every action's
                    duration by (1 + handPain/300), summed over Hand_L through
                    ForeArm_R. Pain in the hands therefore already slows
                    reloading, first aid and crafting for free.

    So the trait applies stiffness and a slow ache to the arms rather than
    faking a swing timer. The felt result matches the design; the mechanism is
    the engine's own. If a future build exposes a real attack-speed modifier,
    this is the place to switch over.
]]

SHAW = SHAW or {}

-- The limbs arthritis is modelled in. Hands and forearms are also the exact
-- set adjustMaxTime() reads for its pain multiplier.
local ARMS = {
    BodyPartType.Hand_L, BodyPartType.Hand_R,
    BodyPartType.ForeArm_L, BodyPartType.ForeArm_R,
}

-- Ceilings, so the trait is a permanent nuisance and never a death sentence.
local MAX_STIFFNESS = 40      -- out of 100
local MAX_ACHE = 12           -- additional pain per limb, out of 100
local COLD_MULTIPLIER = 1.8   -- how much worse below the cold threshold
local COLD_TEMPERATURE = 18   -- degrees C at which the joints start complaining

--- How hard the trait is biting right now, 0..1. Rises with recent combat and
--- with cold.
local function severity(player)
    local base = 0.35

    -- A long fight is what actually hurts. Endurance spent is the cheapest
    -- honest proxy for "you have been swinging for a while": it drains as you
    -- fight and recovers when you stop.
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

local function apply(player)
    if SHAW.Incapacitate.isDown(player) then return end

    local damage = player:getBodyDamage()
    if not damage then return end

    local level = severity(player)
    local stiffness = MAX_STIFFNESS * level
    local ache = MAX_ACHE * level

    for _, partType in ipairs(ARMS) do
        local part = damage:getBodyPart(partType)
        if part then
            -- Raise toward the target and leave it alone otherwise: writing a
            -- lower value every tick would fight the engine's own recovery and
            -- also cancel stiffness the player earned legitimately.
            if part:getStiffness() < stiffness then
                part:setStiffness(stiffness)
            end
            if part:getAdditionalPain() < ache then
                part:setAdditionalPain(ache)
            end
        end
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
