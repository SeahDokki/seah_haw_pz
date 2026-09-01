--[[
    Humans: Are Weak - trait handles.

    media/registries.lua registers each trait and stores the handle on
    the CharacterTrait table under its upper-cased id. Build 42 wants
    that handle, not a string: `player:hasTrait(SHAW.Trait.EPILEPTIC)`.

    Look traits up through this table rather than touching
    CharacterTrait directly - it is the list the rest of the mod
    iterates, and it fails loudly here if a registration was missed.
]]

SHAW = SHAW or {}
SHAW.Trait = {}

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

for name, id in pairs(ids) do
    local handle = CharacterTrait[name]
    if handle == nil then
        print("[SHAW] trait not registered: SHAW:" .. id)
    end
    SHAW.Trait[name] = handle
end

--- True when `player` carries one of this mod's traits.
function SHAW.has(player, trait)
    if not player or not trait then return false end
    return player:hasTrait(trait)
end

--- The ids this mod defines, for iteration and debug output.
function SHAW.traitIds()
    return ids
end
