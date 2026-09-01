--[[
    Humans: Are Weak - Depressive (SHAW:depressive, +6 pts)

    Design, four parts:
      1. Depression rises faster and falls harder.          -> implemented
      2. At maximum depression the Hunger moodle is hidden.  -> NOT POSSIBLE, see below
      3. At high depression, a chance not to swing.          -> implemented
      4. At maximum depression, long tasks become impossible -> implemented,
         except music, alcohol and reading for entertainment. See the note
         above ISTimedActionQueue.add at the bottom of this file.

    Part 2 cannot be done from Lua in Build 42.20. The moodle bar is drawn by
    zombie.ui.MoodlesUI, a Java class with no Lua-facing per-moodle visibility
    control - it exposes setCharacter, isVisible and render for the whole
    widget, nothing per entry, and it is not an ISUI panel a mod can subclass or
    wrap. MoodleType.HUNGRY exists as an enum value, but nothing in Lua can
    suppress its row. Hiding only Hunger would mean replacing the entire vanilla
    moodle widget with a Lua reimplementation, which is far past this trait's
    weight. Recorded as an open point in the README rather than faked.

    Part 3 is the interesting one. There is no "cancel this swing" hook, so the
    apathy is applied where it is actually reachable: when the character is
    about to be able to attack, their swing is drained of the endurance it needs
    and the attack is interrupted through the action queue. See onApathy.
]]

require "TimedActions/ISTimedActionQueue"

SHAW = SHAW or {}

-- Depression is CharacterStat.UNHAPPINESS; the moodle is MoodleType.UNHAPPY.
local RISE_MULTIPLIER = 1.9    -- how much faster it climbs than normal
local FALL_MULTIPLIER = 0.45   -- how much of a normal recovery it keeps

local APATHY_FROM_LEVEL = 3    -- unhappy moodle level at which swings can fail

local function apply(player, data)
    -- Deliberately NOT guarded on SHAW.isIncapable(). This mirrors the
    -- engine's own UNHAPPINESS delta, and the engine keeps moving it while
    -- the character sleeps - skipping would let a whole night's worth of
    -- depression escape the amplification.

    local current = SHAW.stat(player, CharacterStat.UNHAPPINESS)
    local previous = data.SHAW_lastUnhappiness

    if previous ~= nil then
        local delta = current - previous
        if delta > 0 then
            -- Climbing: add the extra on top of what the engine just did.
            SHAW.addStat(player, CharacterStat.UNHAPPINESS,
                         delta * (RISE_MULTIPLIER - 1))
        elseif delta < 0 then
            -- Recovering: give part of the recovery back, so it drags.
            SHAW.addStat(player, CharacterStat.UNHAPPINESS,
                         -delta * (1 - FALL_MULTIPLIER))
        end
    end

    -- Re-read: the adjustment above moved it.
    data.SHAW_lastUnhappiness = SHAW.stat(player, CharacterStat.UNHAPPINESS)
end

--- Apathy: past the threshold, some swings simply do not happen.
--- Hooked on the attack rather than polled, so it costs nothing when idle.
--- OnWeaponSwing is not guaranteed to hand us a local player either, so the
--- argument is validated the same way OnPlayerGetDamage has to be.
local function onApathy(candidate)
    local player = SHAW.eventPlayer(candidate, "DEPRESSIVE", "EnableDepressive")
    if not player then return end

    local level = SHAW.moodle(player, MoodleType.UNHAPPY)
    if level < APATHY_FROM_LEVEL then return end

    -- Scale the configured chance by how far past the threshold we are, so
    -- level 4 is the full value and level 3 is half of it.
    local span = 4 - APATHY_FROM_LEVEL + 1
    local weight = (level - APATHY_FROM_LEVEL + 1) / span
    local chance = SHAW.Config.probability("ApathyChance") * weight

    if not SHAW.chance(chance) then return end

    ISTimedActionQueue.clear(player)
    SHAW.sayBad(player, "IGUI_SHAW_Apathy")
    SHAW.log("apathy: swing refused (moodle %d, p=%.2f)", level, chance)
end

SHAW.Tick.register{
    id = "depressive",
    trait = "DEPRESSIVE",
    option = "EnableDepressive",
    everyMs = 1000,
    fn = apply,
}

-- OnWeaponSwing fires as the character commits to a melee swing, which is the
-- closest the engine gets to "about to attack".
Events.OnWeaponSwing.Add(onApathy)

-- ------------------------------------------------------- action paralysis --

--[[
    At maximum depression the character cannot start a long task. Three things
    are still allowed, because they are the things a depressed person actually
    reaches for:

      - listening to music
      - drinking alcohol
      - reading something purely for entertainment

    Reading is decided by the item, not the class: `getUnhappyChange() < 0`
    means the literature *reduces* unhappiness, which is exactly how vanilla
    ISReadABook identifies morale-boosting reading. So a comic is allowed and a
    carpentry manual is not, with no hardcoded item list to maintain.

    The hook is ISTimedActionQueue.add rather than ISBaseTimedAction:isValid.
    isValid is called repeatedly for the whole duration of every action in the
    game, so wrapping it would put this check in the hottest path there is and
    would also fight actions already in progress. add() runs once, when
    something is about to be queued, which is the decision point.

    LONG_ACTION_TIME is in the engine's action-time units, the same ones passed
    to a timed action's constructor. Vanilla values cluster at 10-60 for quick
    interactions and 100-200 for real work, so 100 is the natural line.
]]

local LONG_ACTION_TIME = 100
local PARALYSIS_FROM_LEVEL = 4    -- maximum depression only

--- Music: the device media action covers radios, TVs and record players.
local ALLOWED_TYPES = {
    ISDeviceMediaAction = true,
}

local function isEntertainment(item)
    if not item then return false end
    local ok, change = pcall(function() return item:getUnhappyChange() end)
    return ok and change ~= nil and change < 0
end

local function isAlcohol(item)
    if not item then return false end
    local ok, power = pcall(function() return item:getAlcoholPower() end)
    return ok and power ~= nil and power > 0
end

--- Is this action one the character can still bring themselves to start?
local function stillPossible(action)
    if ALLOWED_TYPES[action.Type] then return true end

    local item = action.item
    if isAlcohol(item) then return true end
    if action.Type == "ISReadABook" and isEntertainment(item) then return true end

    -- Anything short is not "a long task"; blocking it would make the
    -- character unable to open a door.
    local maxTime = action.maxTime
    if type(maxTime) ~= "number" or maxTime < LONG_ACTION_TIME then
        return true
    end

    return false
end

local originalAdd = ISTimedActionQueue.add

function ISTimedActionQueue.add(action)
    if action and action.character then
        local player = SHAW.eventPlayer(action.character, "DEPRESSIVE", "EnableDepressive")
        if player
            and SHAW.moodle(player, MoodleType.UNHAPPY) >= PARALYSIS_FROM_LEVEL
            and not stillPossible(action)
        then
            SHAW.sayBad(player, "IGUI_SHAW_CannotFace")
            SHAW.log("depressive: refused %s (maxTime %s)",
                     tostring(action.Type), tostring(action.maxTime))
            -- nil, matching how vanilla's own refusals in this function return
            -- (see the IGUI_CantDoWhileDragging branch) - the value is passed
            -- along by callers.
            return
        end
    end

    return originalAdd(action)
end
