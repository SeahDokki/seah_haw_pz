--[[
    Humans: Are Weak - Ehlers-Danlos Syndrome (SHAW:ehlersdanlos, +5 pts)

    Design: joint hypermobility. Something gives out mid-sprint, and recovery
    from it is slower than normal.

    The bible asked for sprains. Sprains do not exist in Build 42.20 - no
    setSprained, no isSprained, no Sprain buff anywhere in BodyPart. So the
    mechanic is a **severe cramp** instead: a hard spike of stiffness and pain
    in one leg, which is what the engine does model (see SHAW_Soreness.lua).
    Same felt outcome - the leg stops cooperating and stays sore - reached
    through a real system rather than a missing one.

    The cramp also drops the character, because a leg seizing at a sprint means
    going down. That part uses the shared knockdown.

    Rolled once per continuous sprint, not per frame. At 60fps an 8% per-frame
    chance fires within the first stride, every time - it has to be per sprint
    or the trait is simply "you cannot sprint".

    Still not implemented: the bible also wants raised light-fracture chance on
    impacts generally. That needs a damage hook and is tracked in the README.
]]

SHAW = SHAW or {}

local CRAMP_SECONDS = 4

-- A severe cramp. Deliberately high: this is the trait's headline event and
-- should be felt for a while afterwards, not shrugged off in ten seconds.
local CRAMP_STIFFNESS = 70
local CRAMP_PAIN = 40

-- How much of the engine's stiffness recovery is handed back each tick.
local RECOVERY_DRAG = 0.5

local function cramp(player, data)
    local leg = SHAW.pick(SHAW.Soreness.LEGS)
    if not leg then return end

    if not SHAW.Incapacitate.begin(player, CRAMP_SECONDS, "cramp", "IGUI_SHAW_LegCramp") then
        return
    end

    SHAW.Soreness.raise(player, leg, CRAMP_STIFFNESS, CRAMP_PAIN)
    SHAW.log("eds: severe cramp in a leg")
end

local function apply(player, data)
    if SHAW.Incapacitate.reason(player) == "cramp" then
        SHAW.Incapacitate.tick(player)
        return
    end

    if SHAW.isIncapable(player) then return end

    if player:isSprinting() then
        -- One roll per continuous sprint. The latch clears when they stop.
        if not data.SHAW_edsSprintRolled then
            data.SHAW_edsSprintRolled = true

            -- SHAW_edsForce is set by the debug menu to make the next roll a
            -- certainty; an 8% chance is not a test loop. Consumed on use.
            local forced = data.SHAW_edsForce
            data.SHAW_edsForce = nil

            if forced or SHAW.chance(SHAW.Config.probability("EDSTripChance")) then
                cramp(player, data)
                return
            end
        end
    else
        data.SHAW_edsSprintRolled = false
    end

    -- Slower recovery, across both legs.
    data.SHAW_edsStiffness = data.SHAW_edsStiffness or {}
    for _, leg in ipairs(SHAW.Soreness.LEGS) do
        SHAW.Soreness.dragRecovery(player, leg, data.SHAW_edsStiffness, RECOVERY_DRAG)
    end
end

SHAW.Tick.register{
    id = "ehlersdanlos",
    trait = "EHLERSDANLOS",
    option = "EnableEhlersDanlos",
    everyMs = 500,
    fn = apply,
}
