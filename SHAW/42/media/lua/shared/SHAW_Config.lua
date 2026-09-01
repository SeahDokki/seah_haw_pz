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
    Debug = false,
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
