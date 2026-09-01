--[[
    Humans: Are Weak - Colour Blind (SHAW:colorblind, +2 pts)

    Design: the world rendered in greyscale, with "desaturated UI only" as the
    stated fallback if a shader proves impossible.

    The bible flagged shader feasibility as unconfirmed. It turns out no shader
    is needed: the engine already has a global desaturation float driven by the
    weather system, and it is reachable from Lua.

        local option = getClimateManager():getClimateFloat(ClimateManager.FLOAT_DESATURATION)
        option:setEnableAdmin(true)
        option:setAdminValue(1.0)

    That is the same path the game's own climate debug panel uses
    (client/DebugUIs/DebugMenu/Climate/PopupColorEdit.lua), so it is a supported
    override rather than a trick.

    THE CATCH, and it is a real one: this is a *world* setting, not a per-player
    one. There is no per-character desaturation in 42.20. Consequences:

      - Single player: works exactly as designed.
      - Multiplayer: the value belongs to the world. Setting it client-side may
        be overwritten by the server's climate sync, and if it is not, it is
        still the wrong shape - one colour-blind player would grey the world for
        anyone sharing that client. So the trait is DISABLED outside single
        player rather than applied and hoped for.

    The weather system also writes this float, so the admin override has to be
    re-asserted rather than set once - hence the periodic handler instead of a
    one-shot on character creation.
]]

SHAW = SHAW or {}

-- Whether this session has an override in place, so it can be lifted cleanly.
local applied = false

local function desaturationOption()
    local climate = getClimateManager()
    if not climate or not ClimateManager or not ClimateManager.FLOAT_DESATURATION then
        return nil
    end
    local ok, option = pcall(function()
        return climate:getClimateFloat(ClimateManager.FLOAT_DESATURATION)
    end)
    if not ok then return nil end
    return option
end

local function setDesaturation(value)
    local option = desaturationOption()
    if not option then return false end

    local ok = pcall(function()
        option:setEnableAdmin(true)
        option:setAdminValue(value)
    end)
    return ok
end

--- Hand the world's colour back.
local function release()
    if not applied then return end
    applied = false

    local option = desaturationOption()
    if not option then return end

    pcall(function()
        option:setEnableAdmin(false)
    end)

    SHAW.log("colorblind: desaturation override released")
end

local function apply(player)
    -- World-level setting: refuse to touch it outside single player. See header.
    if not SHAW.isSinglePlayer() then
        if applied then release() end
        return
    end

    local strength = SHAW.clamp((SHAW.Config.get("ColorBlindStrength") or 100) / 100, 0, 1)

    if strength <= 0 then
        release()
        return
    end

    -- Re-asserted every time: the weather system writes this float too, so a
    -- one-shot set is quietly undone by the next climate tick.
    if setDesaturation(strength) then
        if not applied then
            applied = true
            SHAW.log("colorblind: desaturation held at %.2f", strength)
        end
    end
end

SHAW.Tick.register{
    id = "colorblind",
    trait = "COLORBLIND",
    option = "EnableColorBlind",
    everyMs = 2000,
    fn = apply,
}

-- A character without the trait, or a new one, must not inherit the override.
Events.OnCreatePlayer.Add(release)
