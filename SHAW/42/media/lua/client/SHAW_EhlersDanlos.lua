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

    The cramp drops the character once - a leg seizing at a sprint means going
    down - and pins Pain at maximum while it lasts. Both come from the shared
    knockdown primitive; see SHAW_Incapacitate.lua for why one fall plus pain
    beats re-shoving.

    Rolled on a cadence while sprinting - every ROLL_EVERY_MS - rather than once
    per frame or once per burst. Per frame at any sane chance fires within the
    first stride every time. Once per burst was the first attempt and was just
    as wrong in the other direction: a long sprint carried no more risk than a
    single stride, and a playtest sprinted to exhaustion without one roll ever
    landing. On a cadence, risk scales with how long you hold sprint, a short
    dash stays mostly safe, and jogging is never affected (isSprinting only).

    Still not implemented: the bible also wants raised light-fracture chance on
    impacts generally. That needs a damage hook and is tracked in the README.
]]

SHAW = SHAW or {}

local CRAMP_SECONDS = 4

-- A severe cramp. Deliberately high: this is the trait's headline event and
-- should be felt for a while afterwards, not shrugged off in ten seconds.
local CRAMP_STIFFNESS = 70
local CRAMP_PAIN = 40

-- How often the cramp is rolled while sprinting, in real milliseconds.
local ROLL_EVERY_MS = 1500

-- How much of the engine's stiffness recovery is handed back each tick.
local RECOVERY_DRAG = 0.5

local function cramp(player, data)
    local leg = SHAW.pick(SHAW.Soreness.LEGS)
    if not leg then return end

    if not SHAW.Incapacitate.begin{
        player = player,
        seconds = CRAMP_SECONDS,
        reason = "cramp",
        announce = "IGUI_SHAW_LegCramp",
        shove = true,
        pinPain = true,
    } then
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

    -- The debug menu arms a guaranteed cramp for the next sprint.
    local forced = data.SHAW_edsForce

    if player:isSprinting() then
        -- Roll repeatedly while the sprint continues, not once per burst.
        --
        -- One roll per burst was wrong twice over: a long sprint was no riskier
        -- than a single stride, and at the old 8% a playtest could sprint to
        -- exhaustion without one roll ever landing. Rolling on a cadence makes
        -- the risk scale with how long you hold sprint, which is what "every
        -- sprint is a gamble" should mean - while a short dash stays mostly
        -- safe, and jogging is never affected at all (isSprinting only).
        local now = getTimestampMs()
        local due = (data.SHAW_edsNextRoll or 0)

        if forced or now >= due then
            data.SHAW_edsNextRoll = now + ROLL_EVERY_MS
            data.SHAW_edsForce = nil

            if forced or SHAW.chance(SHAW.Config.probability("EDSTripChance")) then
                cramp(player, data)
                return
            end
        end
    else
        -- Reset the cadence so the first roll of the next sprint is immediate.
        data.SHAW_edsNextRoll = 0
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
