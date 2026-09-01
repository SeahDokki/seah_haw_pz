--[[
    Humans: Are Weak - Narcoleptic (SHAW:narcoleptic, +12 pts)

    Design: sudden sleep onset, anywhere. A base random timer, worsened by a
    heavy meal (the Stuffed moodle) or deep fatigue, slightly reduced when well
    rested. 30 seconds to 2 minutes of game time, attackable while out, and
    damage forces you awake.

    Two ways to model "asleep" were available and they behave very differently:

      setAsleep(true)   the real sleep system. Fast-forwards time, opens the
                        wake-up flow, restores fatigue. Wrong for this: a
                        narcoleptic episode is not a nap, and time-skipping
                        would make the trait a *benefit* - free hours plus free
                        rest, with the danger fast-forwarded past.

      knockdown         the shared incapacitate primitive. Character is on the
                        floor, helpless, in real time, and zombies get to walk
                        over. Preserves the actual threat.

    The second is used. The character is not technically "asleep" as far as the
    engine is concerned, which is the point - see the README for the one
    consequence, which is that the sleep-related moodles do not change.
]]

SHAW = SHAW or {}

local MIN_SECONDS = 30
local MAX_SECONDS = 120

-- Multipliers on the gap to the next attack. Below 1 means sooner.
local STUFFED_FACTOR = 0.55      -- after a heavy meal
local EXHAUSTED_FACTOR = 0.45    -- deep fatigue
local RESTED_FACTOR = 1.35       -- well rested buys a little grace

local function reschedule(player, data)
    local lowHours, highHours = SHAW.Config.range("NarcolepsyMinHours", "NarcolepsyMaxHours")
    local hours = SHAW.randFloat(lowHours, highHours)

    -- FOOD_EATEN is the Stuffed moodle: it rises after a big meal.
    if SHAW.moodle(player, MoodleType.FOOD_EATEN) >= 2 then
        hours = hours * STUFFED_FACTOR
    end

    local tired = SHAW.moodle(player, MoodleType.TIRED)
    if tired >= 3 then
        hours = hours * EXHAUSTED_FACTOR
    elseif tired == 0 then
        hours = hours * RESTED_FACTOR
    end

    data.SHAW_narcoSleepTimer = SHAW.hours() + hours
    SHAW.log("narcolepsy: next attack in %.1f game hours", hours)
end

local function apply(player, data)
    if SHAW.Incapacitate.reason(player) == "sleep" then
        SHAW.Incapacitate.tick(player)
        return
    end

    if SHAW.Incapacitate.isDown(player) then return end

    -- Do not fire while genuinely asleep in a bed; that is not an episode.
    if player:isAsleep() then return end

    local now = SHAW.hours()

    if data.SHAW_narcoSleepTimer == nil then
        reschedule(player, data)
        return
    end

    if data.SHAW_narcoSleepTimer > now + 200 then
        reschedule(player, data)
        return
    end

    if now < data.SHAW_narcoSleepTimer then return end

    reschedule(player, data)

    local seconds = SHAW.randFloat(MIN_SECONDS, MAX_SECONDS)
    data.SHAW_narcoSleepDuration = seconds
    SHAW.Incapacitate.begin(player, seconds, "sleep", "IGUI_SHAW_SleepAttack")
end

--- Damage forces you awake. Hooked rather than polled so it is immediate.
local function onDamage(player)
    if not player then return end
    if SHAW.Incapacitate.reason(player) ~= "sleep" then return end
    SHAW.Incapacitate.cancel(player)
    SHAW.log("narcolepsy: woken by damage")
end

SHAW.Tick.register{
    id = "narcoleptic",
    trait = "NARCOLEPTIC",
    option = "EnableNarcoleptic",
    everyMs = 500,
    fn = apply,
}

Events.OnPlayerGetDamage.Add(onDamage)
