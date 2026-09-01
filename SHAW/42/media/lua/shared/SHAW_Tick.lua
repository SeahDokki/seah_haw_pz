--[[
    Humans: Are Weak - the one update loop.

    Ten traits all want "check something periodically". Registering ten
    OnPlayerUpdate callbacks would mean ten hasTrait() calls and ten sandbox
    lookups every frame, for a character that usually has one or two of these
    traits. So there is one dispatcher, and it does the filtering once.

    Handlers register with a trait, an interval and a function:

        SHAW.Tick.register{
            id      = "neuralgia",
            trait   = "NEURALGIA",          -- key in SHAW.Trait
            option  = "EnableNeuralgia",    -- sandbox switch
            everyMs = 500,
            fn      = function(player, data) ... end,
        }

    WHY THIS FILE IS IN shared/ AND NOT client/
    Project Zomboid loads the files inside a folder in ALPHABETICAL order, and
    loads media/lua/shared/ before media/lua/client/. Every trait module calls
    SHAW.Tick.register at file scope, so the registry has to exist before any of
    them load. When this lived in client/ it was 13th of 14 alphabetically, so
    SHAW_ADHD.lua - first in the alphabet - hit a nil SHAW.Tick and every trait
    after it would have failed the same way. Moving it to shared/ makes the
    order guaranteed rather than lucky.

    Do not move it back, and do not rename the trait files to work around load
    order; the dependency is real and belongs in the earlier-loading folder.

    The active handler list is resolved per character the first time the
    dispatcher sees them, and re-resolved if the player object changes (death,
    respawn, a second local player in split screen).

    Intervals are real milliseconds, deliberately: they throttle CPU, not game
    logic. Anything that has to survive a save or respect the game clock uses
    SHAW.hours() inside the handler instead.
]]

SHAW = SHAW or {}
SHAW.Tick = SHAW.Tick or {}

-- Created defensively so a registration can never land before the registry,
-- whatever the load order turns out to be.
SHAW.Tick.fast = SHAW.Tick.fast or {}
SHAW.Tick.slow = SHAW.Tick.slow or {}

local sessions = {}   -- per-player: resolved handler list + last-run stamps

--- Register a per-frame handler. Cheap to add; only runs if the character
--- actually has the trait and the option is on.
function SHAW.Tick.register(spec)
    assert(spec and spec.id and spec.fn, "SHAW.Tick.register needs id and fn")
    spec.everyMs = spec.everyMs or 0
    table.insert(SHAW.Tick.fast, spec)
end

--- Register a handler for Events.EveryTenMinutes - slow, game-clock driven
--- work such as rotating the ADHD focus skill.
function SHAW.Tick.registerSlow(spec)
    assert(spec and spec.id and spec.fn, "SHAW.Tick.registerSlow needs id and fn")
    table.insert(SHAW.Tick.slow, spec)
end

--- Drop the cached handler lists so the next tick rebuilds them. Call after
--- anything that can change which traits apply - the debug menu does.
function SHAW.Tick.invalidate()
    sessions = {}
    if SHAW.log then SHAW.log("handler cache cleared") end
end

-- A dedicated server loads shared/ too, but every trait module lives in
-- client/, so the handler lists stay empty there. Skip wiring a per-frame
-- callback that could never do anything.
if isServer() and not isClient() then
    return
end

--- Does this character carry the trait, and is the option on?
local function wants(player, spec)
    if spec.option and not SHAW.Config.get(spec.option) then
        return false
    end
    if not spec.trait then
        return true
    end
    local handle = SHAW.Trait[spec.trait]
    if not handle then
        return false
    end
    return player:hasTrait(handle)
end

--- Build (or rebuild) the list of handlers that apply to this character.
local function resolve(player, list)
    local active = {}
    for _, spec in ipairs(list) do
        if wants(player, spec) then
            table.insert(active, spec)
        end
    end
    return active
end

local function sessionFor(player)
    local id = player:getPlayerNum()
    local session = sessions[id]

    if not session or session.player ~= player then
        session = {
            player = player,
            fast = resolve(player, SHAW.Tick.fast),
            slow = resolve(player, SHAW.Tick.slow),
            lastRun = {},
        }
        sessions[id] = session

        local names = {}
        for _, spec in ipairs(session.fast) do table.insert(names, spec.id) end
        for _, spec in ipairs(session.slow) do table.insert(names, spec.id .. "(slow)") end
        SHAW.log("player %d: %d active handler(s): %s",
                 id, #names, #names > 0 and table.concat(names, ", ") or "none")
    end

    return session
end

local function onPlayerUpdate(player)
    if not player or player:isDead() then return end

    local session = sessionFor(player)
    if #session.fast == 0 then return end

    local data = player:getModData()
    local now = getTimestampMs()

    for _, spec in ipairs(session.fast) do
        local last = session.lastRun[spec.id] or 0
        if now - last >= spec.everyMs then
            session.lastRun[spec.id] = now
            -- One failing trait must not stop the other nine.
            local ok, err = pcall(spec.fn, player, data)
            if not ok then
                print("[SHAW] handler '" .. spec.id .. "' errored: " .. tostring(err))
            end
        end
    end
end

local function onEveryTenMinutes()
    for _, session in pairs(sessions) do
        local player = session.player
        if player and not player:isDead() then
            local data = player:getModData()
            for _, spec in ipairs(session.slow) do
                local ok, err = pcall(spec.fn, player, data)
                if not ok then
                    print("[SHAW] slow handler '" .. spec.id .. "' errored: " .. tostring(err))
                end
            end
        end
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.EveryTenMinutes.Add(onEveryTenMinutes)

-- A new character, or a reloaded one, gets a fresh handler list.
Events.OnCreatePlayer.Add(SHAW.Tick.invalidate)
