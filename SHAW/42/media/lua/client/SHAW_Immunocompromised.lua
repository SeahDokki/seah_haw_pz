--[[
    Humans: Are Weak - Immunocompromised (SHAW:immunocompromised, +6 pts)

    Design: every wound infects without antibiotics and never heals naturally,
    raised random illness risk, and the Knox Virus turns you on the spot with no
    survival window.

    Three separate mechanisms, and they are not equally certain:

    1. Wound infection - solid. BodyPart exposes isInfectedWound(),
       setInfectedWound() and set/getWoundInfectionLevel(). Any open wound on
       any part gets flagged and its infection level floored, every tick.
       Note this is ordinary wound sepsis, NOT the Knox virus - PZ keeps them
       separate, and so does this.

    2. Illness - solid. setColdProgressionRate() makes anything the character
       catches progress faster, and SICKNESS is a plain stat to nudge.

    3. Knox instant turn - LESS CERTAIN, and marked as such. The engine's
       infection clock is driven by setInfectionTime(),
       setInfectionMortalityDuration() and setInfectionGrowthRate(), but their
       exact units are not documented anywhere reachable from Lua and are not
       used by any vanilla Lua file. All three are pushed toward "finish now"
       and each call is guarded, so a signature change costs the trait its
       instant turn rather than crashing the mod. This is the one part of the
       trait that has to be confirmed by actually getting bitten in-game -
       see the test plan in the README.

    Design note: this trait directly contradicts Humans: Are Resilient's
    Superimmunity, which blocks Knox entirely. Cross-module exclusion cannot go
    in the script file (it would break loading when the other mod is absent),
    so if both are ever installed the resolution belongs here.
]]

SHAW = SHAW or {}

local WOUND_INFECTION_FLOOR = 15   -- out of 100; enough to be visibly septic
local SICKNESS_PER_TICK = 0.0004
local COLD_PROGRESSION = 2.5

--- Every part carrying an open wound becomes an infected wound.
local function infectWounds(player, damage)
    local parts = damage:getBodyParts()
    if not parts then return end

    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        local open = part:isCut() or part:isScratched()
                     or part:isDeepWounded() or part:getBiteTime() > 0

        if open then
            if not part:isInfectedWound() then
                part:setInfectedWound(true)
                SHAW.sayBad(player, "IGUI_SHAW_WoundTurned")
                SHAW.log("immuno: wound turned septic")
            end
            if part:getWoundInfectionLevel() < WOUND_INFECTION_FLOOR then
                part:setWoundInfectionLevel(WOUND_INFECTION_FLOOR)
            end
        end
    end
end

--- Collapse the Knox timer. Guarded per call: see the header note.
local function forceKnox(damage, data)
    if data.SHAW_knoxForced then return end
    data.SHAW_knoxForced = true

    pcall(function() damage:setInfectionMortalityDuration(0.01) end)
    pcall(function() damage:setInfectionGrowthRate(100) end)
    pcall(function() damage:setInfectionTime(0) end)

    SHAW.log("immuno: Knox forced to complete immediately")
end

local function apply(player, data)
    local damage = player:getBodyDamage()
    if not damage then return end

    infectWounds(player, damage)

    -- Anything they catch runs hot.
    pcall(function() damage:setColdProgressionRate(COLD_PROGRESSION) end)

    -- A body that is always fighting something.
    SHAW.addStat(player, CharacterStat.SICKNESS, SICKNESS_PER_TICK)

    if damage:isInfected() then
        forceKnox(damage, data)
    else
        -- Cured or a fresh character: allow the force to fire again later.
        data.SHAW_knoxForced = nil
    end
end

SHAW.Tick.register{
    id = "immunocompromised",
    trait = "IMMUNOCOMPROMISED",
    option = "EnableImmunocompromised",
    everyMs = 1500,
    fn = apply,
}
