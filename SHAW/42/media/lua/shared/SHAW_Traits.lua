--[[
    Humans: Are Weak - trait handles.

    media/registries.lua registers each trait and stores the handle on
    the CharacterTrait table under its upper-cased id. Build 42 wants
    that handle, not a string: `player:hasTrait(SHAW.Trait.EPILEPTIC)`.

    Look traits up through this table rather than touching CharacterTrait
    directly. Lookups are lazy: registries.lua runs before the script
    files are parsed, but its order relative to media/lua/shared/ is not
    worth relying on, and resolving on first use makes it irrelevant. A
    missing registration warns once and returns nil rather than baking a
    nil into the table at load time.
]]

SHAW = SHAW or {}

local ids = {
    EPILEPTIC = "epileptic",
    NARCOLEPTIC = "narcoleptic",
    DIABETIC = "diabetic",
    DEPRESSIVE = "depressive",
    IMMUNOCOMPROMISED = "immunocompromised",
    ASTHMATIC = "asthmatic",
    EHLERSDANLOS = "ehlersdanlos",
    NEURALGIA = "neuralgia",
    TOURETTE = "tourette",
    ALLERGY = "allergy",
    ARTHRITIS = "arthritis",
    ADHD = "adhd",
    COLORBLIND = "colorblind",
}

local warned = {}

SHAW.Trait = setmetatable({}, {
    __index = function(self, name)
        local id = ids[name]
        if id == nil then
            print("[SHAW] unknown trait: " .. tostring(name))
            return nil
        end

        local handle = CharacterTrait[name]
        if handle == nil then
            if not warned[name] then
                warned[name] = true
                print("[SHAW] trait not registered: SHAW:" .. id)
            end
            return nil
        end

        rawset(self, name, handle)
        return handle
    end,
})

--- True when `player` carries one of this mod's traits.
function SHAW.has(player, trait)
    if not player or not trait then return false end
    return player:hasTrait(trait)
end

--- The ids this mod defines, keyed by handle name. For iteration.
function SHAW.traitIds()
    return ids
end
