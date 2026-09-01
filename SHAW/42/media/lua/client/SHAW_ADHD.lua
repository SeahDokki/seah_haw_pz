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

    2. Events.AddXP fires AFTER the XP has landed, so it cannot filter - it can
       only top up. The handler adds the difference with AddXPNoMultiplier and
       guards against re-entry, because the top-up would otherwise re-fire the
       same event forever.

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

-- Set while topping XP up, so the AddXP the top-up itself raises is ignored.
local reentering = false

local function hasADHD(player)
    if not player or player:isDead() then return false end
    if not SHAW.Config.get("EnableADHD") then return false end
    local handle = SHAW.Trait.ADHD
    return handle ~= nil and player:hasTrait(handle)
end

-- ------------------------------------------------------------- hyperfocus --

--- Roll a new focus skill and remember when it should rotate again.
local function rollFocus(player, data)
    local perk = SHAW.pick(FOCUSABLE)
    if not perk then return end

    data.SHAW_tdahFocusSkill = perk:getId()
    data.SHAW_tdahFocusTimer = SHAW.hours() + (SHAW.Config.get("ADHDFocusHours") or 6)

    SHAW.sayGood(player, "IGUI_SHAW_FocusShift")
    SHAW.log("adhd: hyperfocus now on %s", tostring(data.SHAW_tdahFocusSkill))
end

--- Rotate the focus when its time is up. Runs on the slow loop.
local function rotate(player, data)
    local now = SHAW.hours()
    local due = data.SHAW_tdahFocusTimer

    if due == nil or due > now + 200 or now >= due then
        rollFocus(player, data)
    end
end

--- Top up XP for the focused skill. Events.AddXP is a notification, so this
--- adds the remainder rather than replacing the original amount.
local function onAddXP(player, perk, amount)
    if reentering then return end
    if not perk or not amount or amount <= 0 then return end
    if not hasADHD(player) then return end

    local data = player:getModData()
    local focus = data.SHAW_tdahFocusSkill
    if not focus or perk:getId() ~= focus then return end

    local multiplier = SHAW.Config.get("ADHDFocusMultiplier") or 15
    if multiplier <= 1 then return end

    local extra = amount * (multiplier - 1)

    reentering = true
    local ok, err = pcall(function()
        player:getXp():AddXPNoMultiplier(perk, extra)
    end)
    reentering = false

    if ok then
        SHAW.log("adhd: %s +%.1f bonus xp (x%d)", focus, extra, multiplier)
    else
        SHAW.log("adhd: xp top-up failed: %s", tostring(err))
    end
end

-- ------------------------------------------------------- stress & boredom --

local function apply(player, data)
    if SHAW.isIncapable(player) then return end

    SHAW.addStat(player, CharacterStat.STRESS, STRESS_PER_TICK)
    SHAW.addStat(player, CharacterStat.BOREDOM, BOREDOM_PER_TICK)

    if data.SHAW_tdahFocusSkill == nil then
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

Events.AddXP.Add(onAddXP)
