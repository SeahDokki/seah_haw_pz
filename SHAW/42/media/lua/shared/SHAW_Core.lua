--[[
    Humans: Are Weak - namespace, context helpers and logging.

    Loaded on both sides. Nothing here reads the world; it only answers
    "where am I running" so the rest of the mod can branch correctly. Files
    under server/ are loaded on multiplayer clients too, so anything that
    decides world state must open with `if not SHAW.isAuthoritative() then return end`.
]]

SHAW = SHAW or {}

SHAW.MOD_ID = "SHAW"
SHAW.VERSION = "0.1.0"

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

--- Per-character store. Every key this mod writes is prefixed `SHAW_`,
--- because modData is a save-file schema: renaming a key orphans it.
function SHAW.data(player)
    if not player then return nil end
    return player:getModData()
end

--- Debug print, gated on the sandbox option so it costs nothing when off.
function SHAW.log(message, ...)
    if not SHAW.Config or not SHAW.Config.get("Debug") then return end
    if select("#", ...) > 0 then
        message = string.format(message, ...)
    end
    print("[SHAW] " .. tostring(message))
end
