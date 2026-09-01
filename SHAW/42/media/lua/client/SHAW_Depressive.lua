--[[
    Humans: Are Weak - Depressive (SHAW:depressive, +6 pts)

    Design, three parts:
      1. Depression rises faster and falls harder.          -> implemented
      2. At maximum depression the Hunger moodle is hidden.  -> NOT POSSIBLE, see below
      3. At high depression, a chance not to swing.          -> implemented

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

SHAW = SHAW or {}

-- Depression is CharacterStat.UNHAPPINESS; the moodle is MoodleType.UNHAPPY.
local RISE_MULTIPLIER = 1.9    -- how much faster it climbs than normal
local FALL_MULTIPLIER = 0.45   -- how much of a normal recovery it keeps

local APATHY_FROM_LEVEL = 3    -- unhappy moodle level at which swings can fail

local function apply(player, data)
    if SHAW.Incapacitate.isDown(player) then return end

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
local function onApathy(player)
    if not player or player:isDead() then return end
    if not SHAW.Config.get("EnableDepressive") then return end

    local handle = SHAW.Trait.DEPRESSIVE
    if not handle or not player:hasTrait(handle) then return end

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
