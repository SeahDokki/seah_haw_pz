--[[
    Humans: Are Weak - sandbox option access.

    Never read SandboxVars.SHAW directly. An option can be missing on an older
    save or a partially-overridden server, and indexing it then yields nil
    rather than the value the design assumes. DEFAULTS below must stay in step
    with the `default =` lines in media/sandbox-options.txt.
]]

SHAW = SHAW or {}
SHAW.Config = SHAW.Config or {}

local DEFAULTS = {
    -- general
    Debug                   = false,

    -- traits: per-trait switches. All default on. Turning one off stops its
    -- effects; it stays selectable at character creation either way.
    EnableEpileptic         = true,
    EnableNarcoleptic       = true,
    EnableDepressive        = true,
    EnableImmunocompromised = true,
    EnableEhlersDanlos      = true,
    EnableNeuralgia         = true,
    EnableTourette          = true,
    EnableArthritis         = true,
    EnableADHD              = true,
    EnableColorBlind        = true,

    -- tuning
    EpilepsyCooldown        = 10,
    EpilepsyDuration        = 18,
    NarcolepsyMinHours      = 5,
    NarcolepsyMaxHours      = 20,
    NarcolepsyDuration      = 60,
    NeuralgiaMinMinutes     = 10,
    NeuralgiaMaxMinutes     = 40,
    TouretteMinMinutes      = 15,
    TouretteMaxMinutes      = 60,
    TouretteRadius          = 18,
    ApathyChance            = 15,
    ADHDReadingPercent      = 300,
    ADHDFocusMultiplier     = 15,
    ADHDFocusHours          = 6,
    ADHDStressThreshold     = 3,
    EDSTripChance           = 15,
    ColorBlindStrength      = 100,
}

--- Read one sandbox option, falling back to its shipped default.
function SHAW.Config.get(name)
    local vars = SandboxVars and SandboxVars.SHAW
    if vars ~= nil then
        local value = vars[name]
        if value ~= nil then
            return value
        end
    end
    return DEFAULTS[name]
end

--- The shipped default, ignoring whatever the save says. Useful when
--- reporting that an option has drifted from the design.
function SHAW.Config.default(name)
    return DEFAULTS[name]
end

--- A percentage option as a plain multiplier: 300 becomes 3.0.
function SHAW.Config.multiplier(name)
    local value = SHAW.Config.get(name)
    if type(value) ~= "number" then return 1 end
    return value / 100
end

--- A percentage option as a probability: 15 becomes 0.15.
function SHAW.Config.probability(name)
    local value = SHAW.Config.get(name)
    if type(value) ~= "number" then return 0 end
    return SHAW.clamp(value / 100, 0, 1)
end

--- A min/max option pair, ordered. A server override can invert them, and a
--- reversed range would otherwise make every roll return the minimum.
function SHAW.Config.range(minName, maxName)
    local low = SHAW.Config.get(minName) or 0
    local high = SHAW.Config.get(maxName) or 0
    if high < low then
        return high, low
    end
    return low, high
end
