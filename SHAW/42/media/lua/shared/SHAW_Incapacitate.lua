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

    The character is shoved ONCE per episode, not held down.

    An earlier version re-applied the shove on a timer to keep them on the floor
    for the full duration, copying vanilla's debug tool. In play that reads as
    the character falling over and over in a loop, which looks broken rather
    than afflicted - reported on both epilepsy and the Ehlers-Danlos cramp. One
    fall is the effect; the episode duration now only governs how long the mod
    considers the character occupied (SHAW.isIncapable) and when the recovery
    effect fires.

    Consequence worth knowing: the player regains control after the knockdown
    animation, well before a long episode ends. If a trait needs more bite than
    one fall, add a real penalty for the duration - maxing PAIN is the pattern
    used by neuralgia - rather than re-shoving.

    State here is deliberately NOT in modData. An episode lasts seconds, so
    persisting it would put a throwaway timestamp into the save schema for no
    benefit - and a stale one would strand a character on the floor after a
    reload. It lives in a module-local table instead and dies with the session.
]]

SHAW = SHAW or {}
SHAW.Incapacitate = SHAW.Incapacitate or {}

-- playerNum -> { untilMs, reason }
local episodes = {}

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

    episodes[player:getPlayerNum()] = {
        untilMs = getTimestampMs() + (seconds * 1000),
        reason = reason,
    }

    -- Whatever they were doing is over. Without this the character keeps
    -- crafting on the floor.
    ISTimedActionQueue.clear(player)

    -- The one and only shove.
    shove(player)

    if announceKey then
        SHAW.sayBad(player, announceKey)
    end

    SHAW.log("%s: knocked down, episode %ds", tostring(reason), seconds)
    return true
end

--- Run the episode clock. Call every tick from the owning handler.
--- Returns true while the episode is still running, false once it has ended
--- (and only on the tick it ends, so callers can fire a recovery effect).
--- Does NOT re-shove - see the note in the header.
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
