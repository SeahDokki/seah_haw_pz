--[[
    Humans: Are Weak - taking control away from the player.

    Epilepsy, narcolepsy and neuralgia all need the same thing: drop the
    character, stop what they were doing, keep them down for a few seconds,
    then hand control back. Built once here.

    On what is actually achievable: Project Zomboid exposes no Lua call that
    disables player input. `setBlockMovement` exists only on animal behaviour,
    not on characters. What IS reachable is the knockdown the engine uses when
    a zombie shoves you:

        chr:setBumpType("stagger")
        chr:setVariable("BumpDone", false)
        chr:setVariable("BumpFall", true)
        chr:setVariable("BumpFallType", "pushedFront")

    That is taken from the game's own debug menu (client/DebugUIs/
    DebugContextMenu.lua, DebugContextMenu.onTick), which also re-applies it on
    a timer to hold a character down - so re-triggering while the episode lasts
    is the engine-sanctioned approach, not a workaround.

    The result is a character who is knocked over, cannot act, and gets shoved
    back down every time they try to rise. It is not a true input lock, and a
    player mashing keys will twitch. Documented rather than papered over.

    State here is deliberately NOT in modData. An episode lasts seconds, so
    persisting it would put a throwaway timestamp into the save schema for no
    benefit - and a stale one would strand a character on the floor after a
    reload. It lives in a module-local table instead and dies with the session.
]]

SHAW = SHAW or {}
SHAW.Incapacitate = SHAW.Incapacitate or {}

-- playerNum -> { untilMs, nextShoveMs, reason }
local episodes = {}

-- The engine's own hold-down cadence, in milliseconds. Vanilla's debug tool
-- re-shoves every 300 ticks; this is the same idea on a wall clock.
local RESHOVE_MS = 1200

local function shove(player)
    player:setBumpType("stagger")
    player:setVariable("BumpDone", false)
    player:setVariable("BumpFall", true)
    player:setVariable("BumpFallType", "pushedFront")
end

--- True while `player` is in the middle of an episode.
function SHAW.Incapacitate.isDown(player)
    if not player then return false end
    local episode = episodes[player:getPlayerNum()]
    if not episode then return false end
    return getTimestampMs() < episode.untilMs
end

--- What put them down: "seizure", "sleep", "pain". nil when up.
function SHAW.Incapacitate.reason(player)
    if not player then return nil end
    local episode = episodes[player:getPlayerNum()]
    if not episode or getTimestampMs() >= episode.untilMs then return nil end
    return episode.reason
end

--- Drop the character for `seconds` real seconds.
--- Returns false if they were already down, so a second trigger during an
--- episode does not extend it forever.
function SHAW.Incapacitate.begin(player, seconds, reason, announceKey)
    if not player or player:isDead() then return false end
    if SHAW.Incapacitate.isDown(player) then return false end

    local now = getTimestampMs()
    episodes[player:getPlayerNum()] = {
        untilMs = now + (seconds * 1000),
        nextShoveMs = now,
        reason = reason,
    }

    -- Whatever they were doing is over. Without this the character keeps
    -- crafting on the floor.
    ISTimedActionQueue.clear(player)

    if announceKey then
        SHAW.sayBad(player, announceKey)
    end

    SHAW.log("%s: down for %ds", tostring(reason), seconds)
    return true
end

--- Keep the character on the floor. Call every tick from the owning handler.
--- Returns true while the episode is still running, false once it has ended
--- (and only on the tick it ends, so callers can fire a recovery effect).
function SHAW.Incapacitate.tick(player, endedKey)
    if not player then return false end

    local num = player:getPlayerNum()
    local episode = episodes[num]
    if not episode then return false end

    local now = getTimestampMs()

    if now >= episode.untilMs then
        episodes[num] = nil
        if endedKey then
            SHAW.sayBad(player, endedKey)
        end
        SHAW.log("%s: over", tostring(episode.reason))
        return false
    end

    if now >= episode.nextShoveMs then
        episode.nextShoveMs = now + RESHOVE_MS
        shove(player)
    end

    return true
end

--- Cancel an episode early - taking damage should wake a narcoleptic.
function SHAW.Incapacitate.cancel(player)
    if not player then return end
    episodes[player:getPlayerNum()] = nil
end

--- Forget everyone. The debug menu calls this so a stuck test character can be
--- freed without reloading.
function SHAW.Incapacitate.clearAll()
    episodes = {}
end
