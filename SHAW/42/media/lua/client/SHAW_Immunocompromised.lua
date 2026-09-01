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

    3. Knox instant turn - now solid, after one wrong turn. The first attempt
       pushed setInfectionTime / MortalityDuration / GrowthRate toward "finish
       now" and did nothing: a bite still ran its full multi-day course, because
       those three shape the infection *curve*, not the position on it. The
       position is `CharacterStat.ZOMBIE_INFECTION`, compared against
       `BodyDamage.InfectionLevelToZombify`. See forceKnox().

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

--- Complete the Knox infection now.
---
--- The first attempt pushed setInfectionMortalityDuration / GrowthRate /
--- InfectionTime toward "finish now" and did nothing observable - a bite still
--- ran its normal multi-day course. Those three shape the *curve*, not the
--- position on it.
---
--- The position is a stat: `CharacterStat.ZOMBIE_INFECTION`, which the engine
--- compares against `BodyDamage.InfectionLevelToZombify`. Vanilla's own debug
--- panel exposes exactly this as a slider (client/DebugUIs/DebugMenu/General/
--- ISStatsAndBody.lua), which is the confirmation that it is the real lever.
--- Maxing it puts the character at the zombify threshold immediately.
local function forceKnox(player, damage, data)
    if data.SHAW_knoxForced then return end
    data.SHAW_knoxForced = true

    local _, high = SHAW.statRange(CharacterStat.ZOMBIE_INFECTION)
    SHAW.setStat(player, CharacterStat.ZOMBIE_INFECTION, high)

    -- Collapse the curve as well, so anything still reading the timers agrees
    -- with the stat rather than fighting it.
    pcall(function() damage:setInfectionMortalityDuration(0.01) end)
    pcall(function() damage:setInfectionGrowthRate(100) end)

    SHAW.log("immuno: Knox forced - ZOMBIE_INFECTION set to %.1f", high)
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
        forceKnox(player, damage, data)
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
