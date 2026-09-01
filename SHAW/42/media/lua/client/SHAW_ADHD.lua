--[[
    Humans: Are Weak - ADHD (SHAW:adhd, +4 pts)

    Design, four parts:
      1. Reading takes three times as long.                     -> implemented
      2. x15 XP on one random skill, rotating.                   -> implemented
      3. Stress and Boredom climb very fast.                      -> implemented
      4. Past a stress threshold, refuses to read / wait / sleep.  -> reading only

    Note the direction of part 1: three times as LONG, not faster. The design
    bible originally read "Lecture x3", which is ambiguous; it means the time
    tripled. That is also why this trait is mutually exclusive with Fast Reader
    rather than Slow Reader - it compounds with slow reading and contradicts
    fast reading.

    How each part is reached:

    1. ISBaseTimedAction:adjustMaxTime() is the engine's own hook for stretching
       an action, already used for unhappiness, drunkenness and hand pain. This
       file wraps ISReadABook's copy rather than touching the base class, so
       nothing but reading is affected.

    2. addXpMultiplier() - the same call a read skill book makes. See the note on
       applyFocusMultiplier below for why this replaced an earlier approach.

    3. Plain stat pushes on STRESS and BOREDOM.

    4. Only reading is refused. ISReadABook:isValid() is a clean, documented
       refusal point that the engine already uses for "too dark to read".
       Waiting and sleeping have no equivalent single chokepoint in 42.20 -
       sleep goes through several context-menu entry points and a dialog - so
       they are left alone rather than hooked in four fragile places. Recorded
       as an open point in the README.
]]

require "TimedActions/ISReadABook"

SHAW = SHAW or {}

-- Skills the hyperfocus can land on. A curated list rather than iterating
-- PerkFactory.PerkList, because that list also carries the container entries
-- (Perks.None, Perks.Combat, Perks.MAX) which are not trainable skills.
--
-- These are Perks enum values, which is what addXpMultiplier() and
-- getXp():getMultiplier() take - the same thing SkillBook entries hold.
--
-- APPEND ONLY. modData stores the *index* into this list, not a name: perk
-- identity has no round-trippable string (getId() is not what
-- Perks.FromString() accepts, and getName() is translated). Reordering this
-- list would silently repoint every saved character's hyperfocus.
local FOCUSABLE = {
    Perks.Aiming, Perks.Axe, Perks.Blacksmith, Perks.Blunt, Perks.Butchering,
    Perks.Carving, Perks.Cooking, Perks.Doctor, Perks.Electricity,
    Perks.Farming, Perks.Fishing, Perks.Fitness, Perks.FlintKnapping,
    Perks.Glassmaking, Perks.Husbandry, Perks.Lightfoot, Perks.Maintenance,
    Perks.Masonry, Perks.Mechanics, Perks.MetalWelding, Perks.Nimble,
    Perks.PlantScavenging, Perks.Pottery, Perks.Reloading, Perks.SmallBlade,
    Perks.SmallBlunt, Perks.Sneak, Perks.Sprinting, Perks.Strength,
    Perks.Tailoring, Perks.Tracking, Perks.Trapping, Perks.Woodwork,
}

local STRESS_PER_TICK = 0.0022
local BOREDOM_PER_TICK = 0.11      -- BOREDOM runs 0..100

local function hasADHD(player)
    return SHAW.eventPlayer(player, "ADHD", "EnableADHD") ~= nil
end

--- Display name of a focus entry, for halo text and the log.
local function perkName(perkEnum)
    if not perkEnum then return "?" end
    local ok, name = pcall(function()
        return PerkFactory.getPerk(perkEnum):getName()
    end)
    return ok and name or "?"
end

-- ------------------------------------------------------------- hyperfocus --

--[[
    Push the hyperfocus into the engine's own XP-multiplier system.

    The first version topped XP up after the fact, on Events.AddXP, with
    AddXPNoMultiplier. It produced the right numbers and was completely
    invisible: the skill panel showed no multiplier and no arrows, so there was
    no way to tell which skill was in hyperfocus or that the trait did anything
    at all.

    addXpMultiplier() is what a read skill book calls (ISReadABook.
    checkMultiplier). It is what fills the "Multiplier" column and draws the
    arrows in the skills panel, it is a Lua global from LuaManager$GlobalObject,
    and it replicates in multiplayer via AddXPMultiplierPacket - so the server
    agrees rather than a client inventing XP.

    Signature: addXpMultiplier(character, perk, multiplier, minLevel, maxLevel)
]]
local function applyFocusMultiplier(player, data)
    local index = data.SHAW_tdahFocusIndex
    local perkEnum = index and FOCUSABLE[index]
    if not perkEnum then return end

    local multiplier = SHAW.Config.get("ADHDFocusMultiplier") or 15
    if multiplier <= 1 then return end

    -- Only ever raise it, so a bigger boost the player earned from a book is
    -- never trampled by this trait.
    local current = 0
    pcall(function() current = player:getXp():getMultiplier(perkEnum) or 0 end)
    if current >= multiplier then return end

    -- 0..10 covers the whole skill, unlike a book's narrow level band.
    local ok, err = pcall(function()
        addXpMultiplier(player, perkEnum, multiplier, 0, 10)
    end)

    if ok then
        SHAW.log("adhd: hyperfocus x%d on %s (was x%.1f)",
                 multiplier, perkName(perkEnum), current)
    else
        SHAW.log("adhd: addXpMultiplier failed: %s", tostring(err))
    end
end

--- Drop the multiplier off the skill that is no longer the focus, so the arrows
--- follow the focus instead of accumulating on every skill it ever landed on.
local function clearFocusMultiplier(player, index)
    local perkEnum = index and FOCUSABLE[index]
    if not perkEnum then return end
    pcall(function()
        addXpMultiplier(player, perkEnum, 0, 0, 10)
    end)
end

--- Roll a new focus skill and remember when it should rotate again.
local function rollFocus(player, data)
    local previous = data.SHAW_tdahFocusIndex

    local index = ZombRand(#FOCUSABLE) + 1
    -- Do not sit on the same skill twice in a row; the rotation is the trait.
    if #FOCUSABLE > 1 and index == previous then
        index = (index % #FOCUSABLE) + 1
    end

    if previous and previous ~= index then
        clearFocusMultiplier(player, previous)
    end

    data.SHAW_tdahFocusIndex = index
    data.SHAW_tdahFocusTimer = SHAW.hours() + (SHAW.Config.get("ADHDFocusHours") or 6)

    applyFocusMultiplier(player, data)

    HaloTextHelper.addGoodText(player,
        getText("IGUI_SHAW_FocusShift") .. ": " .. perkName(FOCUSABLE[index]))
end

--- Rotate the focus when its time is up, and keep the multiplier topped up in
--- between - the engine consumes multipliers as the skill levels.
local function rotate(player, data)
    local now = SHAW.hours()
    local due = data.SHAW_tdahFocusTimer

    if due == nil or due > now + 200 or now >= due then
        rollFocus(player, data)
    else
        applyFocusMultiplier(player, data)
    end
end

-- ------------------------------------------------------- stress & boredom --

local function apply(player, data)
    if SHAW.isIncapable(player) then return end

    SHAW.addStat(player, CharacterStat.STRESS, STRESS_PER_TICK)
    SHAW.addStat(player, CharacterStat.BOREDOM, BOREDOM_PER_TICK)

    if data.SHAW_tdahFocusIndex == nil then
        rollFocus(player, data)
    end
end

-- --------------------------------------------------------------- reading --

local originalAdjust = ISReadABook.adjustMaxTime
local originalIsValid = ISReadABook.isValid

--- Reading takes ADHDReadingPercent of its normal time.
function ISReadABook:adjustMaxTime(maxTime)
    local adjusted = originalAdjust(self, maxTime)
    if hasADHD(self.character) then
        adjusted = adjusted * SHAW.Config.multiplier("ADHDReadingPercent")
    end
    return adjusted
end

--- Too stressed to sit down with a book.
function ISReadABook:isValid()
    if hasADHD(self.character) then
        local threshold = SHAW.Config.get("ADHDStressThreshold") or 3
        if threshold <= 3 and SHAW.moodle(self.character, MoodleType.STRESS) >= threshold then
            SHAW.sayBad(self.character, "IGUI_SHAW_TooStressed")
            return false
        end
    end
    return originalIsValid(self)
end

-- -------------------------------------------------------------- register --

SHAW.Tick.register{
    id = "adhd",
    trait = "ADHD",
    option = "EnableADHD",
    everyMs = 1000,
    fn = apply,
}

SHAW.Tick.registerSlow{
    id = "adhd-focus",
    trait = "ADHD",
    option = "EnableADHD",
    fn = rotate,
}

--- Re-assert the multiplier on load: it lives on the character, not in our
--- modData, so a reload can come back without it.
Events.OnCreatePlayer.Add(function(playerNum)
    local player = getSpecificPlayer(playerNum)
    if hasADHD(player) then
        applyFocusMultiplier(player, player:getModData())
    end
end)
