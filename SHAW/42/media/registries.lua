--[[
    Build 42 requires every custom trait and profession to be registered
    here, at media/registries.lua, before the script files that reference
    them are parsed. The `CharacterTrait = SHAW:<id>,` line in
    media/scripts/SHAW_traits.txt resolves against these registrations,
    and player:hasTrait() takes the returned object, never a string.

    Ids are case-sensitive and must match the script file exactly.
]]

local traits = {
    "epileptic",
    "narcoleptic",
    "diabetic",
    "depressive",
    "immunocompromised",
    "asthmatic",
    "ehlersdanlos",
    "neuralgia",
    "tourette",
    "allergy",
    "arthritis",
    "adhd",
    "colorblind",
}

for i = 1, #traits do
    CharacterTrait[string.upper(traits[i])] = CharacterTrait.register("SHAW:" .. traits[i])
end
