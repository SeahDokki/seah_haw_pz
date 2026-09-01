--[[
    Humans: Are Weak - taking control away from the player.

    Epilepsy, the Ehlers-Danlos cramp and neuralgia all need the same shape:
    interrupt what the character was doing, hurt them badly for a few seconds,
    then let go. Built once here.

    TWO LEVERS, MIXED PER TRAIT.

    `shove` - the knockdown. Project Zomboid exposes no Lua call that disables
    player input (`setBlockMovement` exists only on animal behaviour), but the
    shove a zombie gives you is reachable:

        chr:setBumpType("stagger")
        chr:setVariable("BumpDone", false)
        chr:setVariable("BumpFall", true)
        chr:setVariable("BumpFallType", "pushedFront")

    Taken from the game's own debug menu (client/DebugUIs/DebugContextMenu.lua).
    It fires ONCE per episode. An earlier version re-applied it on a timer to
    hold the character on the floor, and in play that reads as falling over and
    over, which looks broken rather than afflicted.

    `pinPain` - CharacterStat.PAIN held at its ceiling for the whole episode,
    re-applied every tick because the engine bleeds pain away continuously.
    This is what actually incapacitates, and it is not cosmetic: the engine
    reads pain to stretch every timed action (ISBaseTimedAction:adjustMaxTime),
    to block sprinting, and to degrade melee. The character is genuinely
    crippled without any input lock, and can still crawl somewhere safe - which
    is the interesting decision these traits should create.

    One fall alone was not enough: it ends after the animation, well before a
    long episode does. Pain is what makes the remaining seconds mean something.

    State here is deliberately NOT in modData. An episode lasts seconds, so
    persisting it would put a throwaway timestamp into the save schema for no
    benefit - and a stale one would strand a character on the floor after a
    reload. It lives in a module-local table instead and dies with the session.
]]

SHAW = SHAW or {}
SHAW.Incapacitate = SHAW.Incapacitate or {}

-- playerNum -> { untilMs, reason, pinPain }
local episodes = {}

local function shove(player)
    player:setBumpType("stagger")
    player:setVariable("BumpDone", false)
    player:setVariable("BumpFall", true)
    player:setVariable("BumpFallType", "pushedFront")
end

local function pinPain(player)
    local _, ceiling = SHAW.statRange(CharacterStat.PAIN)
    SHAW.setStat(player, CharacterStat.PAIN, ceiling)
    return ceiling
end

--- True while `player` is in the middle of an episode.
function SHAW.Incapacitate.isDown(player)
    if not player then return false end
    local episode = episodes[player:getPlayerNum()]
    if not episode then return false end
    return getTimestampMs() < episode.untilMs
end

--- What put them down: "seizure", "cramp", "pain". nil when up.
function SHAW.Incapacitate.reason(player)
    if not player then return nil end
    local episode = episodes[player:getPlayerNum()]
    if not episode or getTimestampMs() >= episode.untilMs then return nil end
    return episode.reason
end

--- Start an episode.
---
---     SHAW.Incapacitate.begin{
---         player   = player,
---         seconds  = 18,
---         reason   = "seizure",
---         announce = "IGUI_SHAW_Seizure",  -- optional halo text
---         shove    = true,                 -- knock them down once (default true)
---         pinPain  = true,                 -- hold PAIN at max (default false)
---     }
---
--- Returns false if they were already down, so a second trigger during an
--- episode does not extend it forever.
function SHAW.Incapacitate.begin(spec)
    local player = spec and spec.player
    if not player or player:isDead() then return false end
    if SHAW.Incapacitate.isDown(player) then return false end

    local seconds = spec.seconds or 5

    episodes[player:getPlayerNum()] = {
        untilMs = getTimestampMs() + (seconds * 1000),
        reason = spec.reason,
        pinPain = spec.pinPain == true,
    }

    -- Whatever they were doing is over. Without this the character keeps
    -- crafting on the floor.
    ISTimedActionQueue.clear(player)

    if spec.shove ~= false then
        shove(player)
    end

    if spec.pinPain then
        pinPain(player)
    end

    if spec.announce then
        SHAW.sayBad(player, spec.announce)
    end

    SHAW.log("%s: episode %ds (shove=%s pain=%s)", tostring(spec.reason), seconds,
             tostring(spec.shove ~= false), tostring(spec.pinPain == true))
    return true
end

--- Run the episode clock. Call every tick from the owning handler.
--- Returns true while the episode is still running, false once it has ended
--- (and only on the tick it ends, so callers can fire a recovery effect).
function SHAW.Incapacitate.tick(player, endedKey)
    if not player then return false end

    local num = player:getPlayerNum()
    local episode = episodes[num]
    if not episode then return false end

    if getTimestampMs() >= episode.untilMs then
        episodes[num] = nil
        if endedKey then
            SHAW.sayBad(player, endedKey)
        end
        SHAW.log("%s: over", tostring(episode.reason))
        return false
    end

    -- Re-applied every tick: the engine bleeds pain away continuously, so a
    -- one-shot set fades within a second or two.
    if episode.pinPain then
        pinPain(player)
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
