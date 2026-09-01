--[[
    Humans: Are Weak - Narcoleptic (SHAW:narcoleptic, +12 pts)

    Design: sudden sleep onset, anywhere. A base random timer worsened by a
    heavy meal (Stuffed) or deep fatigue, eased slightly when well rested. The
    screen darkens, the character is asleep and attackable, and damage forces
    them awake.

    This uses REAL SLEEP - setAsleep(true) - deliberately. Not being able to
    choose when you sleep is the penalty, and being asleep on the ground near
    zombies is the danger. An earlier version used the knockdown primitive to
    avoid the fatigue the sleep system restores; that was the wrong trade.

    What makes it stay a penalty rather than a free nap:

      - Time is NOT accelerated. The fast-forward during normal sleep is
        Lua-driven: ISSleepDialog calls SetCurrentGameSpeed(3), and only when
        IsoPlayer.allPlayersAsleep(). This file never calls it, so the world
        keeps running at normal speed while the character lies there.
      - getSleepingEvent():setPlayerFallAsleep() is NOT called either. That
        registers a full sleep session with its wake-up accounting; a
        narcoleptic episode is not a session.
      - The episode is short and this file ends it, rather than sleeping until
        morning.

    setForceWakeUpTime is still set as a safety net. If the Lua timer is ever
    lost - a reload mid-episode, an error in the tick - the engine wakes them
    anyway rather than leaving a character asleep forever.

    Some fatigue does come back during an episode. That is accepted: a real
    microsleep does restore a little, and the exposure is the point.
]]

SHAW = SHAW or {}

-- Multipliers on the gap to the next attack. Below 1 means sooner.
local STUFFED_FACTOR = 0.55      -- after a heavy meal
local EXHAUSTED_FACTOR = 0.45    -- deep fatigue
local RESTED_FACTOR = 1.35       -- well rested buys a little grace

local FADE_SECONDS = 1

-- Episodes are transient, so their state stays out of modData - except the
-- schedule, which has to survive a save. playerNum -> endsAtMs.
local episodes = {}

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

--- True while this mod is the reason the character is asleep.
local function inEpisode(player)
    return episodes[player:getPlayerNum()] ~= nil
end

local function wake(player)
    local num = player:getPlayerNum()
    if not episodes[num] then return end
    episodes[num] = nil

    player:setAsleep(false)

    -- FadeIn exists on UIManager but is unused by vanilla Lua, so it is
    -- guarded: a missing fade is cosmetic, a hard error is not.
    pcall(function()
        UIManager.setFadeBeforeUI(num, true)
        UIManager.FadeIn(num, FADE_SECONDS)
    end)

    SHAW.sayBad(player, "IGUI_SHAW_SleepOver")
    SHAW.log("narcolepsy: awake")
end

local function fallAsleep(player, data)
    local seconds = SHAW.Config.get("NarcolepsyDuration") or 60
    local num = player:getPlayerNum()

    episodes[num] = getTimestampMs() + (seconds * 1000)
    data.SHAW_narcoSleepDuration = seconds

    -- Whatever they were doing is over.
    ISTimedActionQueue.clear(player)

    player:setAsleepTime(0.0)
    player:setAsleep(true)

    -- Safety net only. An hour ahead, wrapped into the 24h clock, so a lost
    -- Lua timer cannot strand the character asleep.
    pcall(function()
        local gt = GameTime.getInstance()
        if gt then
            local wakeAt = (gt:getTimeOfDay() + 1) % 24
            player:setForceWakeUpTime(wakeAt)
        end
    end)

    pcall(function()
        UIManager.setFadeBeforeUI(num, true)
        UIManager.FadeOut(num, FADE_SECONDS)
    end)

    SHAW.sayBad(player, "IGUI_SHAW_SleepAttack")
    SHAW.log("narcolepsy: asleep for %ds", seconds)
end

local function apply(player, data)
    local num = player:getPlayerNum()

    -- Mid-episode: end it on time, or early if something else woke them.
    if episodes[num] then
        if getTimestampMs() >= episodes[num] or not player:isAsleep() then
            wake(player)
        end
        return
    end

    -- Some other trait has the floor, or they went to bed normally.
    if SHAW.Incapacitate.isDown(player) then return end
    if player:isAsleep() then return end

    local now = SHAW.hours()

    if data.SHAW_narcoSleepTimer == nil then
        reschedule(player, data)
        return
    end

    -- A clock that jumped means a different save; re-roll rather than firing.
    if data.SHAW_narcoSleepTimer > now + 200 then
        reschedule(player, data)
        return
    end

    if now < data.SHAW_narcoSleepTimer then return end

    reschedule(player, data)
    fallAsleep(player, data)
end

--- Damage forces you awake. Hooked rather than polled so it is immediate.
---
--- OnPlayerGetDamage fires for ANY character that takes damage, zombies
--- included - it is raised from IsoGameCharacter/BodyDamage, not just from
--- IsoPlayer. Shoving a zombie handed this an IsoZombie and getPlayerNum()
--- errored. SHAW.asLocalPlayer filters that out.
local function onDamage(candidate)
    local player = SHAW.asLocalPlayer(candidate)
    if not player or not inEpisode(player) then return end
    wake(player)
    SHAW.log("narcolepsy: woken by damage")
end

--- Never leave a character asleep because of us across a reload.
local function onCreatePlayer()
    episodes = {}
end

SHAW.Tick.register{
    id = "narcoleptic",
    trait = "NARCOLEPTIC",
    option = "EnableNarcoleptic",
    everyMs = 500,
    fn = apply,
}

Events.OnPlayerGetDamage.Add(onDamage)
Events.OnCreatePlayer.Add(onCreatePlayer)

-- No accessor is exported for "is mid-episode": other traits ask
-- SHAW.isIncapable(), which checks player:isAsleep(). That covers a narcoleptic
-- episode and an ordinary night in a bed with one call, and does not need this
-- file to have loaded first.
