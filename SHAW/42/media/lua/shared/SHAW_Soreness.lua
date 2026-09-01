--[[
    Humans: Are Weak - muscle soreness, shared.

    Two traits want the same thing in different places and on different
    schedules, so it lives here once:

      Ehlers-Danlos   a severe cramp in one leg, episodic, on a failed sprint
      Osteoarthritis  a chronic ache in the hands, always present, worse cold

    The mechanic is Build 42's stiffness value (BodyPart:setStiffness) plus
    additional pain. Stiffness is the engine's own muscle-strain system - it is
    what makes an overworked limb slow and unpleasant to use - so this is
    borrowing a real mechanic rather than approximating one.

    Why stiffness and not a sprain: sprains do not exist in 42.20. There is no
    setSprained, no isSprained and no Sprain buff anywhere in BodyPart's method
    table. Severe soreness is the closest thing the engine actually models, and
    it behaves the way the design wants - it hurts, it slows you, and it fades
    over time rather than needing a splint.

    STIFFNESS BELOW 5 DOES NOTHING. ISHealthPanel gates the display at 5 and
    labels anything under it "Invisible Muscle Strain - HAS NO EFFECT ON THE
    PLAYER!". From 5 it reads "Minor Muscle Strain", from 20 "Muscle Strain".
    So any ramp should start at 5 rather than at zero, or its opening stretch is
    real in the data and inert in the game - which is exactly how the
    Ehlers-Danlos sitting rule first shipped.

    Stiffness is mirrored in two places. BodyPart:setStiffness() is the value the
    health panel reads; Fitness also tracks it per part with a decay timer
    (Fitness.setStiffness / incFutureStiffness / removeStiffnessValue), and
    vanilla's "treat" path clears BOTH. This mod writes only the BodyPart side,
    which is what drives the display and the >= 5 effect. If stiffness ever
    needs to decay on the engine's own schedule rather than ours, the Fitness
    side is where to look.

    Pain in the hands has a second effect worth knowing about:
    ISBaseTimedAction:adjustMaxTime() multiplies every action's duration by
    (1 + handPain/300), summed across Hand_L through ForeArm_R. So sore hands
    already slow reloading, first aid and crafting without this file doing
    anything else.
]]

SHAW = SHAW or {}
SHAW.Soreness = SHAW.Soreness or {}

SHAW.Soreness.ARMS = {
    BodyPartType.Hand_L, BodyPartType.Hand_R,
    BodyPartType.ForeArm_L, BodyPartType.ForeArm_R,
}

SHAW.Soreness.LEGS = {
    { BodyPartType.LowerLeg_L, BodyPartType.Foot_L, BodyPartType.UpperLeg_L },
    { BodyPartType.LowerLeg_R, BodyPartType.Foot_R, BodyPartType.UpperLeg_R },
}

--- Raise stiffness and pain on `parts` toward the given floors.
---
--- Only ever raises. Writing a lower value every tick would fight the engine's
--- own recovery, and would also wipe out soreness the character earned
--- legitimately from overexertion.
function SHAW.Soreness.raise(player, parts, stiffness, pain)
    local damage = player and player:getBodyDamage()
    if not damage then return end

    for _, partType in ipairs(parts) do
        local part = damage:getBodyPart(partType)
        if part then
            if stiffness and part:getStiffness() < stiffness then
                part:setStiffness(stiffness)
            end
            if pain and part:getAdditionalPain() < pain then
                part:setAdditionalPain(pain)
            end
        end
    end
end

--- Slow the recovery of soreness on `parts`.
---
--- `memory` is a table the caller owns (usually a modData key). Each tick this
--- compares the current stiffness to what it was last time and hands back
--- `drag` of whatever the engine just healed, so soreness lingers. A part that
--- was never sore is left alone - this drags recovery, it does not create it.
function SHAW.Soreness.dragRecovery(player, parts, memory, drag)
    local damage = player and player:getBodyDamage()
    if not damage or not memory then return end

    for _, partType in ipairs(parts) do
        local part = damage:getBodyPart(partType)
        if part then
            local key = BodyPartType.ToIndex(partType)
            local now = part:getStiffness()
            local before = memory[key]

            if before ~= nil and now < before then
                part:setStiffness(now + (before - now) * drag)
            end

            memory[key] = part:getStiffness()
        end
    end
end

--- Total additional pain currently sitting on `parts`. Useful for deciding
--- whether an ache has already peaked.
function SHAW.Soreness.totalPain(player, parts)
    local damage = player and player:getBodyDamage()
    if not damage then return 0 end

    local total = 0
    for _, partType in ipairs(parts) do
        local part = damage:getBodyPart(partType)
        if part then
            total = total + part:getAdditionalPain()
        end
    end
    return total
end
