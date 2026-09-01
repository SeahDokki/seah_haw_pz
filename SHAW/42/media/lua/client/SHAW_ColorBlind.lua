--[[
    Humans: Are Weak - Colour Blind (SHAW:colorblind, +2 pts)

    Design: the world in greyscale. The bible's stated fallback was "desaturated
    UI only".

    ---------------------------------------------------------------------------
    Can this affect only the local player? Investigated properly. Short answer:
    not with true greyscale. There is no per-player render state in 42.20 -
    IsoPlayer exposes nothing colour-related beyond setTagColor and
    setWearingNightVisionGoggles, and Core's setOptionScreenFilter is texture
    filtering (linear/nearest), not colour.

    The only true desaturation is ClimateManager's FLOAT_DESATURATION, and it is
    **networked**, not local. ClimateManager$ClimateFloat carries writeAdmin /
    readAdmin and references zombie.network.GameClient; ClimateManager itself
    has PacketClientChangedAdminVars, serverReceiveClientChangeAdminVars,
    PacketAdminVarsUpdate and a "Denied ClimatePacket" rejection path. So a
    client setting it either gets refused by the server or changes the weather
    for everyone on it. It is a world setting with an admin gate, full stop.

    So the trait ships two paths:

      single player   ClimateManager desaturation. True greyscale, correct
                      luminance, costs nothing per frame.
      multiplayer     a local grey overlay drawn on this client only. Alpha
                      blending toward grey does genuinely reduce saturation -
                      result = (1-a)*colour + a*grey - so colours really do wash
                      out. It also flattens contrast, which true greyscale would
                      not, so it is an approximation. But it is local, it is
                      honest, and it is better than the bible's "UI only".

    Split screen is the one case the single-player path gets wrong: two local
    players share one ClimateManager, so one colour-blind character would grey
    the screen for both. The overlay path is used whenever more than one local
    player exists, for that reason.

    One accepted wart on the overlay path: an ISUIElement draws in the UI pass,
    so it tints the interface as well as the world. setAlwaysOnTop(false) keeps
    it as low as the UI layer allows, but it cannot get underneath. Since the
    bible's own fallback was "desaturated UI only", tinting both is strictly
    more than was asked for, and the alternative - reimplementing the world
    render - is absurd for a 2-point trait.
    ---------------------------------------------------------------------------
]]

SHAW = SHAW or {}

-- Whether this session holds a climate override, so it can be lifted cleanly.
local climateApplied = false

-- The multiplayer overlay, created lazily.
local overlay = nil

-- ------------------------------------------------------ climate (true grey) --

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

local function holdClimate(strength)
    local option = desaturationOption()
    if not option then return false end

    -- Re-asserted every time: the weather system writes this float too, so a
    -- one-shot set is quietly undone by the next climate tick.
    local ok = pcall(function()
        option:setEnableAdmin(true)
        option:setAdminValue(strength)
    end)

    if ok and not climateApplied then
        climateApplied = true
        SHAW.log("colorblind: climate desaturation held at %.2f", strength)
    end
    return ok
end

local function releaseClimate()
    if not climateApplied then return end
    climateApplied = false

    local option = desaturationOption()
    if option then
        pcall(function() option:setEnableAdmin(false) end)
    end
    SHAW.log("colorblind: climate desaturation released")
end

-- --------------------------------------------------- overlay (local, approx) --

local SHAWColorBlindOverlay = ISUIElement:derive("SHAWColorBlindOverlay")

function SHAWColorBlindOverlay:new()
    local o = ISUIElement.new(self, 0, 0, getCore():getScreenWidth(), getCore():getScreenHeight())
    o.strength = 0
    -- Mid grey. Blending toward this is what removes the saturation; a darker
    -- grey would just dim the screen.
    o.grey = 0.5
    return o
end

function SHAWColorBlindOverlay:render()
    -- Track resolution changes rather than caching the size at creation.
    self:setWidth(getCore():getScreenWidth())
    self:setHeight(getCore():getScreenHeight())
    self:drawRect(0, 0, self.width, self.height,
                  self.strength, self.grey, self.grey, self.grey)
end

local function holdOverlay(strength)
    if not overlay then
        overlay = SHAWColorBlindOverlay:new()
        overlay:initialise()
        overlay:instantiate()
        -- Behind the UI, so the interface stays readable.
        overlay:addToUIManager()
        overlay:setAlwaysOnTop(false)
        SHAW.log("colorblind: local overlay created")
    end
    -- Capped: at 1.0 the screen is flat grey and unplayable.
    overlay.strength = SHAW.clamp(strength * 0.75, 0, 0.75)
    overlay:setVisible(true)
end

local function releaseOverlay()
    if not overlay then return end
    overlay:setVisible(false)
    overlay:removeFromUIManager()
    overlay = nil
    SHAW.log("colorblind: local overlay removed")
end

-- ------------------------------------------------------------------- apply --

--- True when the ClimateManager route is safe: exactly one local player, and
--- no server that would reject or broadcast the change.
local function canUseClimate()
    if not SHAW.isSinglePlayer() then return false end
    local ok, count = pcall(function() return getNumActivePlayers() end)
    if ok and count and count > 1 then return false end
    return true
end

local function release()
    releaseClimate()
    releaseOverlay()
end

local function apply(player)
    local strength = SHAW.clamp((SHAW.Config.get("ColorBlindStrength") or 100) / 100, 0, 1)

    if strength <= 0 then
        release()
        return
    end

    if canUseClimate() then
        releaseOverlay()
        if holdClimate(strength) then return end
        -- Climate route unavailable after all; fall through to the overlay.
    else
        releaseClimate()
    end

    holdOverlay(strength)
end

SHAW.Tick.register{
    id = "colorblind",
    trait = "COLORBLIND",
    option = "EnableColorBlind",
    everyMs = 2000,
    fn = apply,
}

-- A character without the trait, or a new one, must not inherit either effect.
Events.OnCreatePlayer.Add(release)
