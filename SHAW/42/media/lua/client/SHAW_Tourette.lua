--[[
    Humans: Are Weak - Tourette's (SHAW:tourette, +5 pts)

    Design: an involuntary vocal tic at irregular intervals, carrying as far as
    a human shout (~15-20 tiles), pulling in every zombie in that radius. More
    frequent under stress.

    This trait does not incapacitate. It makes noise, and the noise is the
    whole penalty - which means addSound() is the important call here, not the
    audible one. addSound() is what the zombie AI listens to; playing a sound
    through the sound manager is audible to the player and invisible to the AI.

    On audio: the mod ships no .ogg yet, so no sound name is passed and the tic
    is currently silent to the player while still drawing zombies. That is a
    poor experience and is tracked in the README - custom audio has to be
    human-authored under LICENSE section 4. The moment a real sound exists,
    pass its name to SHAW.playSound below and nothing else changes.
]]

SHAW = SHAW or {}

-- Stress shortens the gap between tics by up to this fraction.
local STRESS_SHORTENING = 0.6

local function reschedule(player, data)
    local lowMin, highMin = SHAW.Config.range("TouretteMinMinutes", "TouretteMaxMinutes")

    -- Stress compresses the whole window rather than just the floor, so a
    -- panicking character tics noticeably more often.
    local stress = SHAW.statFraction(player, CharacterStat.STRESS)
    local compression = 1 - (STRESS_SHORTENING * stress)

    local minutes = SHAW.randFloat(lowMin, highMin) * compression
    data.SHAW_touretteNext = SHAW.hours() + (minutes / 60)
    SHAW.log("tourette: next tic in %.0f game minutes (stress %.2f)", minutes, stress)
end

local function apply(player, data)
    -- A tic still happens mid-seizure - the body does not care - but there is
    -- no point announcing it twice, so only the noise goes out.
    local now = SHAW.hours()

    if data.SHAW_touretteNext == nil then
        reschedule(player, data)
        return
    end

    if data.SHAW_touretteNext > now + 48 then
        reschedule(player, data)
        return
    end

    if now < data.SHAW_touretteNext then return end

    reschedule(player, data)

    local radius = SHAW.Config.get("TouretteRadius") or 18

    -- No sound name: see the note at the top of this file. The AI still hears
    -- it, which is the part that matters mechanically.
    SHAW.makeNoise(player, radius)

    SHAW.log("tourette: tic, radius %d tiles", radius)
end

SHAW.Tick.register{
    id = "tourette",
    trait = "TOURETTE",
    option = "EnableTourette",
    everyMs = 700,
    fn = apply,
}
