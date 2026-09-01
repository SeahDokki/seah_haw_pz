--[[
    Humans: Are Weak - namespace, context helpers, clock, logging.

    Loaded on both sides. Nothing here reads the world; it answers "where am I
    running", "what time is it" and "what is this stat", so the trait modules
    can stay short.

    Files under server/ are loaded on multiplayer clients too, so anything that
    decides world state must open with
    `if not SHAW.isAuthoritative() then return end`.

    Note on where trait logic lives: every trait in this mod acts on the local
    player's own body - stats, body damage, moodles. Project Zomboid simulates
    that client-side even in multiplayer and syncs the result up, so the trait
    modules live in client/ and there is no server/ counterpart. That is
    deliberate, not an oversight.
]]

SHAW = SHAW or {}

SHAW.MOD_ID = "SHAW"
SHAW.VERSION = "0.2.0"

-- ---------------------------------------------------------------- context --

--- True where world state may be decided: single player, or the server.
function SHAW.isAuthoritative()
    return not isClient()
end

function SHAW.isSinglePlayer()
    return not isClient() and not isServer()
end

function SHAW.isDedicatedServer()
    return isServer() and not isClient()
end

-- ------------------------------------------------------------------ store --

--- Per-character store. Every key this mod writes is prefixed `SHAW_`,
--- because modData is a save-file schema: renaming a key orphans it.
function SHAW.data(player)
    if not player then return nil end
    return player:getModData()
end

-- ------------------------------------------------------------------ clock --

--- In-game hours since the world began. Fractional, monotonic, saved with the
--- world, and it does not advance while the game is paused - which is what
--- every cooldown and countdown in this mod wants. Never use os.time() or
--- getTimestampMs() for game-facing delays: they keep running in the menu.
function SHAW.hours()
    local gt = getGameTime()
    if not gt then return 0 end
    return gt:getWorldAgeHours()
end

--- In-game minutes since the world began.
function SHAW.minutes()
    return SHAW.hours() * 60
end

-- ------------------------------------------------------------------- math --

function SHAW.clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

--- Uniform float in [low, high).
function SHAW.randFloat(low, high)
    if high <= low then return low end
    return low + (ZombRand(10000) / 10000) * (high - low)
end

--- True with probability `chance`, expressed 0..1.
function SHAW.chance(probability)
    if probability <= 0 then return false end
    if probability >= 1 then return true end
    return (ZombRand(10000) / 10000) < probability
end

--- Pick one entry of a list at random. Returns nil for an empty list.
function SHAW.pick(list)
    if not list or #list == 0 then return nil end
    return list[ZombRand(#list) + 1]
end

-- ------------------------------------------------------------------ stats --

--- Read one CharacterStat. Build 42 replaced the per-stat getters
--- (getStress, getFatigue, ...) with this keyed API.
function SHAW.stat(player, stat)
    if not player then return 0 end
    local stats = player:getStats()
    if not stats then return 0 end
    return stats:get(stat) or 0
end

--- The declared range of a CharacterStat. Do not assume 0..1: STRESS and PANIC
--- run 0..1 while PAIN, BOREDOM and UNHAPPINESS run 0..100, and hardcoding
--- either makes half the traits no-ops and the other half instant maximums.
--- CharacterStat carries its own bounds, so ask it.
function SHAW.statRange(stat)
    local low, high = 0, 1
    pcall(function()
        low = stat:getMinimumValue()
        high = stat:getMaximumValue()
    end)
    return low, high
end

--- Set one CharacterStat, clamped to that stat's own declared range.
function SHAW.setStat(player, stat, value)
    if not player then return end
    local stats = player:getStats()
    if not stats then return end
    local low, high = SHAW.statRange(stat)
    stats:set(stat, SHAW.clamp(value, low, high))
end

--- Add to one CharacterStat. Negative deltas subtract. Routed through the
--- engine's own add/remove, which clamp internally, so no range maths here.
function SHAW.addStat(player, stat, delta)
    if not player or delta == 0 then return end
    local stats = player:getStats()
    if not stats then return end
    if delta > 0 then
        stats:add(stat, delta)
    else
        stats:remove(stat, -delta)
    end
end

--- A stat as a 0..1 fraction of its own range, so callers can reason about
--- "how stressed" without knowing whether the stat is 0..1 or 0..100.
function SHAW.statFraction(player, stat)
    local low, high = SHAW.statRange(stat)
    if high <= low then return 0 end
    return SHAW.clamp((SHAW.stat(player, stat) - low) / (high - low), 0, 1)
end

--- Moodle level, 0..4. Read-only: moodles are computed from stats, so to move
--- a moodle you move the stat behind it.
function SHAW.moodle(player, moodleType)
    if not player then return 0 end
    local moodles = player:getMoodles()
    if not moodles then return 0 end
    return moodles:getMoodleLevel(moodleType) or 0
end

-- ------------------------------------------------------------ event args --

--[[
    Never trust an event's first argument to be the local player.

    Events.OnPlayerGetDamage is fired from IsoGameCharacter, BodyDamage and
    BodyPart - so it fires for **any** character that takes damage, zombies
    included, despite the name. Shoving a zombie hands the handler an IsoZombie,
    and calling getPlayerNum() on that is a hard error. That crashed the
    narcolepsy wake-up handler on the first playtest.

    Every event handler outside the tick dispatcher goes through these.
]]

--- Return `candidate` only if it is genuinely a local player, else nil.
function SHAW.asLocalPlayer(candidate)
    if not candidate then return nil end
    if not instanceof(candidate, "IsoPlayer") then return nil end
    if candidate.isLocalPlayer and not candidate:isLocalPlayer() then return nil end
    if candidate:isDead() then return nil end
    return candidate
end

--- Resolve an event argument to a local player who carries `traitName` with
--- `option` enabled. Returns nil unless all of that holds, so a handler can
--- open with a single guarded line.
function SHAW.eventPlayer(candidate, traitName, option)
    local player = SHAW.asLocalPlayer(candidate)
    if not player then return nil end

    if option and SHAW.Config and not SHAW.Config.get(option) then
        return nil
    end

    if traitName then
        local handle = SHAW.Trait and SHAW.Trait[traitName]
        if not handle or not player:hasTrait(handle) then
            return nil
        end
    end

    return player
end

-- ------------------------------------------------------------- incapacity --

--- True when the character is in no state to be acted on: knocked down by a
--- seizure, cramp or pain spike, or asleep - whether from narcolepsy or an
--- ordinary night in a bed.
---
--- Trait handlers should open with this rather than checking either condition
--- alone. Pushing stats onto a sleeping character is invisible to the player
--- and quietly breaks the trait's pacing.
function SHAW.isIncapable(player)
    if not player then return true end
    if player:isAsleep() then return true end
    if SHAW.Incapacitate and SHAW.Incapacitate.isDown(player) then return true end
    return false
end

-- ------------------------------------------------------------------ noise --

--- Emit a noise the zombie AI can hear, centred on the player.
--- `radius` is in tiles. This is what actually draws a horde; playing a sound
--- through the sound manager is audible to the player but silent to the AI.
function SHAW.makeNoise(player, radius, volume)
    if not player then return end
    addSound(player, player:getX(), player:getY(), player:getZ(),
             radius, volume or radius)
end

--- Play a world sound at the player, and make the AI hear it too.
--- `soundName` must exist in the game's sound banks; this mod ships no audio
--- yet, so callers pass a vanilla name. Returns false if nothing played.
function SHAW.playSound(player, soundName, radius, volume)
    if not player then return false end

    if radius and radius > 0 then
        SHAW.makeNoise(player, radius, volume)
    end

    local mgr = getSoundManager()
    if not mgr or not soundName then return false end

    -- Guarded: a missing sound name is a config error, not a reason to break
    -- the tick loop for every other trait.
    local ok = pcall(function()
        player:playSound(soundName)
    end)
    return ok
end

-- ----------------------------------------------------------------- output --

--- Floating text over the character. The only player-facing channel these
--- traits have until there are custom moodles, so keys go through getText().
function SHAW.sayBad(player, translationKey)
    if not player then return end
    HaloTextHelper.addBadText(player, getText(translationKey))
end

function SHAW.sayGood(player, translationKey)
    if not player then return end
    HaloTextHelper.addGoodText(player, getText(translationKey))
end

-- ------------------------------------------------------------------- logs --

--- Is debug output and tooling on?
---
--- Two ways in, and the second matters: sandbox options cannot be changed on an
--- existing save, so gating on the option alone means "make a new character to
--- get any diagnostics". isDebugEnabled() is the game's own -debug launch flag.
--- The debug context menu uses this same predicate, so the menu and the log are
--- never on without each other.
function SHAW.isDebug()
    if isDebugEnabled() then return true end
    return SHAW.Config ~= nil and SHAW.Config.get("Debug") == true
end

--- Debug print, gated so it costs nothing when off.
function SHAW.log(message, ...)
    if not SHAW.isDebug() then return end
    if select("#", ...) > 0 then
        message = string.format(message, ...)
    end
    print("[SHAW] " .. tostring(message))
end
